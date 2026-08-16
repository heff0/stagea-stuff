#!/bin/sh
# Persist LocalSettings.php via named volume wiki_config mounted at /persist.
# Do not mount wiki_config over /var/www/html (that would hide the image docroot
# after the first populate) and do not bind-mount a missing file onto
# /var/www/html/LocalSettings.php (Docker creates a directory on first boot).
set -eu

PERSIST="/persist/LocalSettings.php"
LIVE="/var/www/html/LocalSettings.php"

if [ -f "$LIVE" ] && [ ! -f "$PERSIST" ]; then
  cp "$LIVE" "$PERSIST"
fi

if [ -f "$PERSIST" ]; then
  cp "$PERSIST" "$LIVE"
  chown www-data:www-data "$LIVE" 2>/dev/null || true
  chmod 640 "$LIVE" 2>/dev/null || true
fi

exec docker-php-entrypoint "$@"
