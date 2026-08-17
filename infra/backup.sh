#!/usr/bin/env bash
# Phase 1 backup: logical dumps, then restic push of dumps + named-volume tars.
# Separate from deploy.sh. Canonical capture list: docs/deployment/production_plan.md §8
#
# Prerequisites on the host: restic, docker compose v2, infra/.env filled.
# Never commit RESTIC_PASSWORD or AWS_* keys. Never run compose down -v here.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./infra/backup.sh [--init] [--list] [--help]

  (default)  Dump MariaDB + Redis BGSAVE, tar named volumes, restic backup, forget
  --init     restic init (once per repository)
  --list     restic snapshots

Env (infra/.env): RESTIC_REPOSITORY, RESTIC_PASSWORD, AWS_ACCESS_KEY_ID,
AWS_SECRET_ACCESS_KEY, optional AWS_DEFAULT_REGION / RESTIC_PACK_SIZE.

Retention: 7 daily, 4 weekly, 6 monthly (override with RESTIC_KEEP_*).
Staging: /var/tmp/stagea-backup (overridden by STAGEA_BACKUP_STAGING).
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="infra/.env"
COMPOSE_FILE="infra/compose.yaml"
COMPOSE=(docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE")
PROJECT_NAME="stagea"
STAGING="${STAGEA_BACKUP_STAGING:-/var/tmp/stagea-backup}"

DO_INIT=0
DO_LIST=0

for arg in "$@"; do
  case "$arg" in
    --init) DO_INIT=1 ;;
    --list) DO_LIST=1 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "error: unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

fail() {
  echo "error: $*" >&2
  exit 1
}

load_env() {
  [[ -f "$ENV_FILE" ]] || fail "$ENV_FILE missing. Copy infra/.env.example, fill RESTIC_* and AWS_*, chmod 600."
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
}

require_restic_env() {
  [[ -n "${RESTIC_REPOSITORY:-}" ]] || fail "RESTIC_REPOSITORY is empty in $ENV_FILE"
  [[ -n "${RESTIC_PASSWORD:-}" ]] || fail "RESTIC_PASSWORD is empty in $ENV_FILE"
  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || fail "AWS_ACCESS_KEY_ID is empty (S3-compatible access key)"
  [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || fail "AWS_SECRET_ACCESS_KEY is empty"
  command -v restic >/dev/null 2>&1 || fail "restic not found on PATH. Install restic on the host (not in Compose)."
  if ! docker info >/dev/null 2>&1; then
    fail "Docker is not running"
  fi
}

env_get() {
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
  printf '%s' "$val"
}

volume_name() {
  # Compose project name: stagea → stagea_<volume>
  echo "${PROJECT_NAME}_$1"
}

tar_volume() {
  local short="$1"
  local out="$2"
  local vol
  vol="$(volume_name "$short")"
  if ! docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "warn: volume $vol missing; skipping" >&2
    return 0
  fi
  echo "→ tar $vol"
  docker run --rm \
    -v "${vol}:/from:ro" \
    -v "$(dirname "$out"):/to" \
    alpine:3.21 \
    tar czf "/to/$(basename "$out")" -C /from .
}

dump_logical() {
  local dump_dir="$1"
  mkdir -p "$dump_dir"

  local wiki_db wiki_user wiki_pass redis_pass
  wiki_db="$(env_get WIKI_DB_NAME)"
  wiki_user="$(env_get WIKI_DB_USER)"
  wiki_pass="$(env_get WIKI_DB_PASSWORD)"
  redis_pass="$(env_get FORUM_REDIS_PASSWORD)"

  echo "→ MariaDB dump (wiki-db)"
  "${COMPOSE[@]}" exec -T wiki-db \
    mariadb-dump --single-transaction --routines --triggers \
    -u"$wiki_user" -p"$wiki_pass" "$wiki_db" \
    >"$dump_dir/wiki-mariadb.sql"

  echo "→ Redis BGSAVE (forum-redis)"
  "${COMPOSE[@]}" exec -T forum-redis \
    redis-cli -a "$redis_pass" --no-auth-warning BGSAVE >/dev/null
  # Brief wait for AOF/RDB flush; dump is also covered by volume tar.
  sleep 2
}

run_backup() {
  local stamp dumps vols
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  dumps="${STAGING}/dumps"
  vols="${STAGING}/volumes"

  rm -rf "$STAGING"
  mkdir -p "$dumps" "$vols"
  chmod 700 "$STAGING"

  dump_logical "$dumps"

  tar_volume forum_data "${vols}/forum_data.tar.gz"
  tar_volume forum_uploads "${vols}/forum_uploads.tar.gz"
  tar_volume forum_redis_data "${vols}/forum_redis_data.tar.gz"
  tar_volume wiki_images "${vols}/wiki_images.tar.gz"
  tar_volume wiki_config "${vols}/wiki_config.tar.gz"
  # Logical dump is the restore source for MariaDB; still snapshot data dir for forensics.
  tar_volume wiki_db_data "${vols}/wiki_db_data.tar.gz"
  tar_volume caddy_data "${vols}/caddy_data.tar.gz"
  tar_volume caddy_config "${vols}/caddy_config.tar.gz"

  # Do not include infra/.env — password manager only (production_plan §8).
  echo "→ restic backup"
  restic backup \
    --tag "stagea" \
    --tag "stamp=${stamp}" \
    "$STAGING"

  local keep_daily keep_weekly keep_monthly
  keep_daily="${RESTIC_KEEP_DAILY:-7}"
  keep_weekly="${RESTIC_KEEP_WEEKLY:-4}"
  keep_monthly="${RESTIC_KEEP_MONTHLY:-6}"

  echo "→ restic forget (keep ${keep_daily}d / ${keep_weekly}w / ${keep_monthly}m)"
  restic forget \
    --tag stagea \
    --keep-daily "$keep_daily" \
    --keep-weekly "$keep_weekly" \
    --keep-monthly "$keep_monthly" \
    --prune

  echo "→ restic check"
  restic check

  rm -rf "$STAGING"
  echo "backup ok (${stamp})"
  restic snapshots --tag stagea --latest 3
}

load_env
require_restic_env

export RESTIC_REPOSITORY RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${OBJECT_STORAGE_REGION:-auto}}"

if (( DO_INIT == 1 )); then
  restic init
  echo "restic repository initialized: $RESTIC_REPOSITORY"
  exit 0
fi

if (( DO_LIST == 1 )); then
  restic snapshots --tag stagea
  exit 0
fi

run_backup
exit 0
