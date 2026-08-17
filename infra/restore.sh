#!/usr/bin/env bash
# Guided restore from a restic snapshot into a throwaway Compose project.
# Requires typing the snapshot ID to confirm. Never touches production volumes
# unless you deliberately set STAGEA_RESTORE_PROJECT=stagea (discouraged).
#
# Canonical drill: docs/deployment/production_plan.md §8 / scaling_plan.md §9
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./infra/restore.sh [--list] [--help] <snapshot-id>

  --list          restic snapshots (tag stagea)
  <snapshot-id>   Restore that snapshot into project STAGEA_RESTORE_PROJECT
                  (default: stagea-restore). You must type the snapshot ID again
                  to confirm.

Steps this script performs:
  1. restic restore into a staging directory
  2. Load volume tars into {project}_* named volumes
  3. Import wiki MariaDB dump into wiki-db (project must be up)
  4. Print verify checklist (forum post + wiki edit) and wall-clock hint

Does NOT:
  - Run compose down -v
  - Overwrite the live stagea project by default
  - Restore infra/.env (password manager)

After restore, bring the throwaway stack up:
  docker compose -p stagea-restore -f infra/compose.yaml --env-file infra/.env up -d
Then point a throwaway host / hosts file at it, or inspect via compose exec.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

ENV_FILE="infra/.env"
COMPOSE_FILE="infra/compose.yaml"
STAGING="${STAGEA_BACKUP_STAGING:-/var/tmp/stagea-restore}"
PROJECT="${STAGEA_RESTORE_PROJECT:-stagea-restore}"
START_TS="$(date +%s)"

DO_LIST=0
SNAPSHOT=""

for arg in "$@"; do
  case "$arg" in
    --list) DO_LIST=1 ;;
    --help|-h) usage; exit 0 ;;
    -*)
      echo "error: unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
    *)
      SNAPSHOT="$arg"
      ;;
  esac
done

fail() {
  echo "error: $*" >&2
  exit 1
}

load_env() {
  [[ -f "$ENV_FILE" ]] || fail "$ENV_FILE missing"
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
}

require_restic_env() {
  [[ -n "${RESTIC_REPOSITORY:-}" ]] || fail "RESTIC_REPOSITORY empty"
  [[ -n "${RESTIC_PASSWORD:-}" ]] || fail "RESTIC_PASSWORD empty"
  [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] || fail "AWS_ACCESS_KEY_ID empty"
  [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] || fail "AWS_SECRET_ACCESS_KEY empty"
  command -v restic >/dev/null 2>&1 || fail "restic not on PATH"
}

volume_name() {
  echo "${PROJECT}_$1"
}

untar_volume() {
  local short="$1"
  local archive="$2"
  local vol
  vol="$(volume_name "$short")"
  [[ -f "$archive" ]] || {
    echo "warn: missing $archive; skip $short" >&2
    return 0
  }
  echo "→ restore volume $vol from $(basename "$archive")"
  docker volume create "$vol" >/dev/null
  docker run --rm \
    -v "${vol}:/to" \
    -v "$(dirname "$archive"):/from:ro" \
    alpine:3.21 \
    sh -c "rm -rf /to/* /to/.[!.]* 2>/dev/null; tar xzf /from/$(basename "$archive") -C /to"
}

load_env
require_restic_env
export RESTIC_REPOSITORY RESTIC_PASSWORD
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${OBJECT_STORAGE_REGION:-auto}}"

if (( DO_LIST == 1 )); then
  restic snapshots --tag stagea
  exit 0
fi

[[ -n "$SNAPSHOT" ]] || fail "snapshot id required (or --list). See --help."

if [[ "$PROJECT" == "stagea" ]]; then
  echo "WARNING: STAGEA_RESTORE_PROJECT=stagea will overwrite production volume names." >&2
  echo "Type OVERWRITE-PRODUCTION to continue:" >&2
  read -r prod_confirm
  [[ "$prod_confirm" == "OVERWRITE-PRODUCTION" ]] || fail "aborted"
fi

echo "About to restore snapshot ${SNAPSHOT} into Compose project '${PROJECT}'."
echo "Type the snapshot ID to confirm:"
read -r confirm
[[ "$confirm" == "$SNAPSHOT" ]] || fail "confirmation mismatch; aborted"

rm -rf "$STAGING"
mkdir -p "$STAGING"
chmod 700 "$STAGING"

echo "→ restic restore $SNAPSHOT"
restic restore "$SNAPSHOT" --target "$STAGING"

# restic backup of a directory may nest the staging path; find dumps/volumes.
DUMPS="$(find "$STAGING" -type d -name dumps | head -n 1 || true)"
VOLS="$(find "$STAGING" -type d -name volumes | head -n 1 || true)"
[[ -n "$DUMPS" && -n "$VOLS" ]] || fail "restored tree missing dumps/ or volumes/ under $STAGING"

untar_volume forum_data "${VOLS}/forum_data.tar.gz"
untar_volume forum_uploads "${VOLS}/forum_uploads.tar.gz"
untar_volume forum_redis_data "${VOLS}/forum_redis_data.tar.gz"
untar_volume wiki_images "${VOLS}/wiki_images.tar.gz"
untar_volume wiki_config "${VOLS}/wiki_config.tar.gz"
untar_volume caddy_data "${VOLS}/caddy_data.tar.gz"
untar_volume caddy_config "${VOLS}/caddy_config.tar.gz"
# Prefer logical dump for MariaDB; optional data-dir tar is forensic only.
# Do not untar wiki_db_data over a live InnoDB dir — import SQL instead.

COMPOSE=(docker compose -p "$PROJECT" -f "$COMPOSE_FILE" --env-file "$ENV_FILE")

echo "→ start wiki-db (+ redis) in project $PROJECT for SQL import"
"${COMPOSE[@]}" up -d wiki-db forum-redis

echo "→ wait for wiki-db healthy"
for _ in $(seq 1 60); do
  cid="$("${COMPOSE[@]}" ps -q wiki-db 2>/dev/null || true)"
  if [[ -n "$cid" ]]; then
    st="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$cid" 2>/dev/null || true)"
    [[ "$st" == "healthy" || "$st" == "running" ]] && break
  fi
  sleep 2
done

wiki_db="$(grep -E '^WIKI_DB_NAME=' "$ENV_FILE" | tail -n 1 | cut -d= -f2-)"
wiki_user="$(grep -E '^WIKI_DB_USER=' "$ENV_FILE" | tail -n 1 | cut -d= -f2-)"
wiki_pass="$(grep -E '^WIKI_DB_PASSWORD=' "$ENV_FILE" | tail -n 1 | cut -d= -f2-)"
wiki_db="${wiki_db%\"}"
wiki_db="${wiki_db#\"}"
wiki_user="${wiki_user%\"}"
wiki_user="${wiki_user#\"}"
wiki_pass="${wiki_pass%\"}"
wiki_pass="${wiki_pass#\"}"

if [[ -f "${DUMPS}/wiki-mariadb.sql" ]]; then
  echo "→ import MariaDB dump"
  "${COMPOSE[@]}" exec -T wiki-db \
    mariadb -u"$wiki_user" -p"$wiki_pass" "$wiki_db" \
    <"${DUMPS}/wiki-mariadb.sql"
else
  echo "warn: no wiki-mariadb.sql in snapshot" >&2
fi

echo "→ bring full throwaway stack up"
"${COMPOSE[@]}" up -d --remove-orphans

END_TS="$(date +%s)"
ELAPSED=$((END_TS - START_TS))

cat <<EOF

restore ok
  project:   $PROJECT
  snapshot:  $SNAPSHOT
  elapsed:   ${ELAPSED}s (record this — it is your measured RTO sample)

Verify (production_plan §8):
  1. A known forum post is present on forum in this project
  2. A known wiki edit is present
  3. Compare elapsed seconds to the 2-hour RTO target

Tear down throwaway (does NOT use -v unless you add it — avoid -v on production):
  docker compose -p $PROJECT -f infra/compose.yaml --env-file infra/.env down

Staging left at: $STAGING (rm -rf when done)
EOF
exit 0
