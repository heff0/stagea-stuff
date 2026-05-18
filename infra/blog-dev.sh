#!/bin/sh
# Run Ghost's dev:sqlite stack with the Stagea Compose override that
# clears the host-port conflicts with the saleor-platform stack.
#
# Usage:
#   ./infra/blog-dev.sh                   # default: SQLite stack
#   ./infra/blog-dev.sh dev:mailgun       # any other Ghost dev variant
#
# After it boots, Ghost is at:
#   http://localhost:2368/              site
#   http://localhost:2368/ghost/        admin
#   http://localhost:18025/             mailpit web UI (shifted from 8025)

set -e
here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"

# Default variant; override by passing one arg
variant="${1:-dev:sqlite}"

case "$variant" in
  dev:sqlite)   files="-f compose.dev.sqlite.yaml" ;;
  dev:mailgun)  files="-f compose.dev.mailgun.yaml" ;;
  dev:analytics)files="-f compose.dev.analytics.yaml" ;;
  dev:storage)  files="-f compose.dev.storage.yaml" ;;
  dev)          files="" ;;
  *) echo "unknown variant: $variant (expected one of: dev, dev:sqlite, dev:mailgun, dev:analytics, dev:storage)" >&2
     exit 2 ;;
esac

cd "$repo_root/blog"

# Always append the Stagea override last so its !override port lists win.
DEV_COMPOSE_FILES="$files -f ../infra/blog.override.yaml" \
  exec pnpm nx run ghost-monorepo:docker:dev
