#!/usr/bin/env bash
# Phase 1 one-command deploy. Thin wrapper — the escape hatch remains:
#   docker compose -f infra/compose.yaml --env-file infra/.env up -d
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./infra/deploy.sh [--check] [--skip-git-pull] [--module NAME] [--with-db] [--help]

  (default)   Preflight, git pull --ff-only, compose pull, up, health-wait, summary
  --check     Preflight only (env + Docker). Changes nothing.
  --skip-git-pull
              Skip git pull --ff-only (pinned rollbacks, or when CI already synced the checkout)
  --module NAME
              Deploy only that module. Does not recreate other services.
              NAME is one of: shell | forum | wiki | caddy
  --with-db   With --module wiki, also bounce wiki-db even if it is already healthy

Module targets:
  shell   pull + up --no-deps shell
  forum   forum-redis then forum (forum depends on redis)
  wiki    wiki only; wiki-db only if missing/unhealthy, or --with-db
  caddy   reload Caddyfile in-place, or recreate caddy only

Escape hatch (always sufficient):
  docker compose -f infra/compose.yaml --env-file infra/.env up -d

Health wait default 120s; override with DEPLOY_HEALTH_TIMEOUT.

Never runs compose down (or down -v). Unhealthy targets fail the script and leave the stack running.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="infra/.env"
COMPOSE_FILE="infra/compose.yaml"
COMPOSE=(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE")

SERVICES=(caddy shell forum forum-redis wiki wiki-db)
TARGET_SERVICES=("${SERVICES[@]}")

public_url() {
  case "$1" in
    shell) echo "https://stagea-stuff.com" ;;
    forum) echo "https://forum.stagea-stuff.com" ;;
    wiki) echo "https://wiki.stagea-stuff.com" ;;
    *) echo "—" ;;
  esac
}

REQUIRED_KEYS=(
  ACME_EMAIL
  NODE_ENV
  HOST
  PORT
  PUBLIC_SITE_NAME
  FORUM_URL
  WIKI_URL
  BLOG_URL
  SHOP_URL
  AUTH_ISSUER_URL
  AUTH_CLIENT_ID
  AUTH_CLIENT_SECRET
  GHOST_CONTENT_API_KEY
  FORUM_REDIS_PASSWORD
  WIKI_DB_NAME
  WIKI_DB_USER
  WIKI_DB_PASSWORD
  WIKI_DB_ROOT_PASSWORD
)

CHECK=0
SKIP_GIT_PULL=0
WITH_DB=0
MODULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1; shift ;;
    --skip-git-pull) SKIP_GIT_PULL=1; shift ;;
    --with-db) WITH_DB=1; shift ;;
    --module)
      if [[ $# -lt 2 ]]; then
        echo "error: --module requires a value: shell|forum|wiki|caddy" >&2
        usage >&2
        exit 1
      fi
      MODULE="$2"
      shift 2
      ;;
    --module=*)
      MODULE="${1#--module=}"
      shift
      ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$MODULE" in
  ""|shell|forum|wiki|caddy) ;;
  *)
    echo "error: unknown --module: ${MODULE} (want shell|forum|wiki|caddy)" >&2
    usage >&2
    exit 1
    ;;
esac

if (( WITH_DB == 1 )) && [[ "$MODULE" != "wiki" ]]; then
  echo "error: --with-db is only valid with --module wiki" >&2
  exit 1
fi

fail() {
  echo "error: $*" >&2
  exit 1
}

file_mode() {
  local f="$1"
  if stat --version >/dev/null 2>&1; then
    stat -c '%a' "$f"
  else
    stat -f '%OLp' "$f"
  fi
}

env_value() {
  local key="$1"
  local line=""
  line="$(grep -E "^${key}=" "$ENV_FILE" | tail -n 1 || true)"
  [[ -n "$line" ]] || return 1
  local val="${line#*=}"
  val="${val%$'\r'}"
  if [[ "$val" == \"*\" && "$val" == *\" ]]; then
    val="${val#\"}"
    val="${val%\"}"
  elif [[ "$val" == \'*\' && "$val" == *\' ]]; then
    val="${val#\'}"
    val="${val%\'}"
  fi
  [[ -n "$val" ]] || return 1
}

preflight_env() {
  if [[ ! -f "$ENV_FILE" ]]; then
    fail "$ENV_FILE is missing. Copy infra/.env.example to infra/.env, fill secrets, chmod 600. Changing nothing."
  fi

  local mode perm extra
  mode="$(file_mode "$ENV_FILE")"
  perm=$((8#$mode))
  extra=$(( (perm & ~8#640) & 8#777 ))
  if (( perm & 8#004 )); then
    fail "$ENV_FILE is world-readable (mode $mode). chmod 600 (or 0640 at most). Changing nothing."
  fi
  if (( extra != 0 )); then
    fail "$ENV_FILE mode is $mode (more permissive than 0640). chmod 600 (or 0640 at most). Changing nothing."
  fi

  local missing=()
  local key
  for key in "${REQUIRED_KEYS[@]}"; do
    if ! env_value "$key"; then
      missing+=("$key")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    fail "$ENV_FILE is missing or empty required key(s): ${missing[*]}. Changing nothing."
  fi
}

preflight_docker() {
  if ! docker info >/dev/null 2>&1; then
    fail "Docker is not running (docker info failed). Changing nothing."
  fi
  local ver=""
  if ! ver="$(docker compose version 2>/dev/null)"; then
    fail "Compose v2 is unavailable (docker compose version failed). Install the Compose v2 plugin; do not use docker-compose v1. Changing nothing."
  fi
  if ! grep -Eq 'v?2[.]|[Vv]ersion:?[[:space:]]*2' <<<"$ver"; then
    fail "Compose v2 is required; got: $ver. Changing nothing."
  fi
}

git_pull() {
  git -C "$REPO_ROOT" pull --ff-only
}

health_of() {
  local svc="$1"
  local cid=""
  cid="$("${COMPOSE[@]}" ps -q "$svc" 2>/dev/null || true)"
  if [[ -z "$cid" ]]; then
    echo "missing"
    return
  fi
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || echo "unknown"
}

image_of() {
  local svc="$1"
  local cid=""
  cid="$("${COMPOSE[@]}" ps -q "$svc" 2>/dev/null || true)"
  if [[ -z "$cid" ]]; then
    echo "—"
    return
  fi
  docker inspect -f '{{.Config.Image}}' "$cid" 2>/dev/null || echo "—"
}

wait_healthy() {
  local timeout="${DEPLOY_HEALTH_TIMEOUT:-120}"
  local start now elapsed
  start="$(date +%s)"
  echo "Waiting up to ${timeout}s for health checks (${TARGET_SERVICES[*]})..."
  while true; do
    local all_ok=1
    local svc status
    for svc in "${TARGET_SERVICES[@]}"; do
      status="$(health_of "$svc")"
      if [[ "$status" != "healthy" ]]; then
        all_ok=0
      fi
    done
    if (( all_ok == 1 )); then
      return 0
    fi
    now="$(date +%s)"
    elapsed=$((now - start))
    if (( elapsed >= timeout )); then
      echo "error: health wait timed out after ${timeout}s" >&2
      return 1
    fi
    sleep 3
  done
}

print_summary() {
  local svc health image url
  printf '%-14s %-12s %-36s %s\n' "SERVICE" "HEALTH" "IMAGE" "URL"
  printf '%-14s %-12s %-36s %s\n' "-------" "------" "-----" "---"
  for svc in "${TARGET_SERVICES[@]}"; do
    health="$(health_of "$svc")"
    image="$(image_of "$svc")"
    url="$(public_url "$svc")"
    printf '%-14s %-12s %-36s %s\n' "$svc" "$health" "$image" "$url"
  done
}

all_healthy() {
  local svc
  for svc in "${TARGET_SERVICES[@]}"; do
    if [[ "$(health_of "$svc")" != "healthy" ]]; then
      return 1
    fi
  done
  return 0
}

resolve_targets() {
  case "$MODULE" in
    "")
      TARGET_SERVICES=("${SERVICES[@]}")
      ;;
    shell)
      TARGET_SERVICES=(shell)
      ;;
    caddy)
      TARGET_SERVICES=(caddy)
      ;;
    forum)
      TARGET_SERVICES=(forum-redis forum)
      ;;
    wiki)
      if (( WITH_DB == 1 )); then
        echo "wiki-db included (--with-db)"
        TARGET_SERVICES=(wiki-db wiki)
      else
        local db_health
        db_health="$(health_of wiki-db)"
        if [[ "$db_health" == "healthy" ]]; then
          echo "wiki-db is healthy; leaving it running (pass --with-db to bounce it)"
          TARGET_SERVICES=(wiki)
        else
          echo "wiki-db is ${db_health}; including wiki-db in this deploy"
          TARGET_SERVICES=(wiki-db wiki)
        fi
      fi
      ;;
  esac
}

pull_targets() {
  echo "Pulling images: ${TARGET_SERVICES[*]}"
  "${COMPOSE[@]}" pull "${TARGET_SERVICES[@]}"
}

up_full() {
  "${COMPOSE[@]}" up -d --remove-orphans
}

up_no_deps() {
  local svc
  for svc in "$@"; do
    echo "Starting ${svc} (--no-deps; other services left running)"
    if [[ "$MODULE" == "wiki" && "$svc" == "wiki-db" && "$WITH_DB" -eq 1 ]]; then
      "${COMPOSE[@]}" up -d --no-deps --force-recreate --remove-orphans "$svc"
    else
      "${COMPOSE[@]}" up -d --no-deps --remove-orphans "$svc"
    fi
  done
}

wait_one() {
  local saved=("${TARGET_SERVICES[@]}")
  TARGET_SERVICES=("$1")
  local rc=0
  wait_healthy || rc=$?
  TARGET_SERVICES=("${saved[@]}")
  return "$rc"
}

deploy_caddy() {
  local status
  status="$(health_of caddy)"
  if [[ "$status" == "missing" ]]; then
    echo "caddy is not running; starting caddy only"
    "${COMPOSE[@]}" up -d --no-deps --remove-orphans caddy
    return
  fi
  if "${COMPOSE[@]}" exec -T caddy caddy reload --config /etc/caddy/Caddyfile; then
    echo "Caddy reloaded from bind-mounted Caddyfile (container not recreated)"
    return
  fi
  echo "Caddy reload failed; recreating caddy only"
  "${COMPOSE[@]}" up -d --no-deps --force-recreate --remove-orphans caddy
}

up_module() {
  case "$MODULE" in
    shell)
      up_no_deps shell
      ;;
    caddy)
      deploy_caddy
      ;;
    forum)
      up_no_deps forum-redis
      wait_one forum-redis
      up_no_deps forum
      ;;
    wiki)
      if [[ "${TARGET_SERVICES[0]}" == "wiki-db" ]]; then
        up_no_deps wiki-db
        wait_one wiki-db
      fi
      up_no_deps wiki
      ;;
  esac
}

preflight_env
preflight_docker

if (( CHECK == 1 )); then
  echo "preflight ok"
  exit 0
fi

if (( SKIP_GIT_PULL == 1 )); then
  echo "Skipping git pull (--skip-git-pull)"
else
  git_pull
fi

resolve_targets

if [[ -n "$MODULE" ]]; then
  echo "Module deploy: ${MODULE} → ${TARGET_SERVICES[*]}"
  pull_targets
  up_module
else
  echo "Full-stack deploy: ${TARGET_SERVICES[*]}"
  "${COMPOSE[@]}" pull
  up_full
fi

wait_rc=0
wait_healthy || wait_rc=$?

print_summary

if (( wait_rc != 0 )) || ! all_healthy; then
  echo "error: one or more target services are unhealthy. Stack left running for diagnosis (no down)." >&2
  exit 1
fi

exit 0
