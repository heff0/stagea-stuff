# `infra/`

Stagea-monorepo infrastructure glue. Lives in the parent repo so it can be edited and committed without touching any submodule.

## Production Compose (Phase 1)

Production is **one** Compose file, **one** Caddy container on host ports `80`/`443`, and every other process on the internal `stagea-net` network. Only the **Astro Shell** is built from this repository. **Submodules** (`forum/`, `wiki/`, `blog/`, `shop/`) are not cloned, built, or bind-mounted in production — those services run official upstream images.

Service map, named volumes, and phases: [production_plan.md §3](../docs/deployment/production_plan.md#3-service-map). After go-live (RAM/disk inequalities, 1,000+ users): [scaling_plan.md](../docs/deployment/scaling_plan.md).

Apex is the Shell now (`https://stagea-stuff.com` → `shell:4321`). `infra/caddy/placeholder.html` is leftover from the edge-skeleton slice and is unused by Caddy.

### Image pins (confirmed 2026-08-16)

| Service | Image | Notes |
| :--- | :--- | :--- |
| `caddy` | `caddy:2.10-alpine` | Docker Hub. Admin API health on `:2019` is not published to the host. |
| `shell` | `${SHELL_IMAGE}` default `ghcr.io/heff0/stagea-shell:main` | Published by [deploy.yml](../.github/workflows/deploy.yml) on `main`. `build: ../shell` remains a host fallback (`SHELL_IMAGE=stagea-shell:local` and `up --build`). See [ci-cd.md](../docs/deployment/ci-cd.md). |
| `forum` | `ghcr.io/nodebb/nodebb:4.15` | **`nodebb/docker:4.4` does not exist** on Docker Hub (no 4.x tags). Official images moved to GitHub Container Registry. Pin is the current 4.x minor (`v4.15.0`, 2026-08-12). |
| `forum-redis` | `redis:7.4-alpine` | AOF + `requirepass`. Redis hostname is the Compose service name `forum-redis`. |
| `wiki` | `mediawiki:1.43` | Official LTS. Serves at `/` (document root), not `/w/`. |
| `wiki-db` | `mariadb:11.4` | Official LTS. No host port. |

Never `:latest`. Never `docker compose down -v` (that deletes named volumes).

### One command

After one-time host setup ([slice 1](../docs/deployment/cards/slice_01_host_baseline.md)) and filling in `infra/.env`:

```bash
./infra/deploy.sh
```

From any cwd. The script resolves the repo root from its own path. It:

1. Fails fast if `infra/.env` is missing, world-readable, more permissive than `0640`, or missing a required key (changes nothing).
2. Fails fast if Docker is down or Compose v2 is missing.
3. `git pull --ff-only` on the current branch.
4. `docker compose -f infra/compose.yaml --env-file infra/.env pull`
5. `docker compose -f infra/compose.yaml --env-file infra/.env up -d --remove-orphans`
6. Waits until `caddy`, `shell`, `forum`, `forum-redis`, `wiki`, and `wiki-db` are `healthy` (default 120s; override with `DEPLOY_HEALTH_TIMEOUT`).
7. Prints a summary table (service, health, image, public URL).
8. Exits non-zero if anything is unhealthy — and does **not** `down` the stack.

```bash
./infra/deploy.sh --check          # preflight only; no git, pull, or up
./infra/deploy.sh --skip-git-pull  # skip step 3 (pinned rollbacks)
./infra/deploy.sh --module shell   # pull + up --no-deps shell only
./infra/deploy.sh --module forum   # forum-redis, then forum (not wiki/caddy)
./infra/deploy.sh --module wiki    # wiki; wiki-db only if missing/unhealthy
./infra/deploy.sh --module wiki --with-db
./infra/deploy.sh --module caddy   # reload Caddyfile, or recreate caddy only
DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh   # first-run NodeBB can exceed 120s
```

`--module` still preflights `.env` and Docker, pulls **only** the target services, `up -d --no-deps --remove-orphans` those services, and health-waits those services. It never `down`s the stack. CI path-filters and SSH are documented in [ci-cd.md](../docs/deployment/ci-cd.md).

Rollback the Astro Shell without touching forum or wiki:

```bash
SHELL_IMAGE=ghcr.io/heff0/stagea-shell:<previous-sha> \
  ./infra/deploy.sh --skip-git-pull --module shell
```

The one command does **not** provision hosts, edit DNS, generate secrets, run the NodeBB or MediaWiki installers, or migrate data.

### Escape hatch

If `deploy.sh` is missing, production still deploys:

```bash
docker compose -f infra/compose.yaml --env-file infra/.env up -d
```

Always from the **repository root**, with `-f infra/compose.yaml --env-file infra/.env`.

Supporting commands (not part of the deploy path):

```bash
docker compose -f infra/compose.yaml --env-file infra/.env logs -f <service>
docker compose -f infra/compose.yaml --env-file infra/.env ps
```

`./infra/backup.sh` / `./infra/restore.sh` are slice 7 — not here.

### Secrets

```bash
cp infra/.env.example infra/.env
# fill real values; openssl rand -base64 32 for passwords
chmod 600 infra/.env
```

`infra/.env` is gitignored. `infra/.env.example` is the inventory and is tracked. Placeholders for `AUTH_*` and `GHOST_CONTENT_API_KEY` are required keys with dummy values — do **not** start Ghost, Saleor, the Keycloak OIDC IdP, or the Directus Parts API in Phase 1.

`SHELL_IMAGE` selects the Astro Shell tag (default `ghcr.io/heff0/stagea-shell:main`). CI sets it to the git SHA tag. Make the GHCR package public so the VPS can pull without a token; see [ci-cd.md](../docs/deployment/ci-cd.md). `OBJECT_STORAGE_*` is the disk-scale contract; uploads still live in named volumes until the [scaling plan](../docs/deployment/scaling_plan.md) disk inequality fires.

### First-run: NodeBB wizard

One-time, human. Open `https://forum.stagea-stuff.com` and complete the setup wizard.

* Database type: **Redis**
* Redis host: `forum-redis` (Compose service name, not `localhost`)
* Redis port: `6379`
* Redis password: `FORUM_REDIS_PASSWORD` from `infra/.env`
* Public URL: `https://forum.stagea-stuff.com`

Generated config is persisted in the `forum_data` volume (`/opt/config`). Uploads go to `forum_uploads`. Later `up` skips the wizard. See [production_plan.md §5.5](../docs/deployment/production_plan.md#55-per-application-bootstrap-one-time-interactive).

### First-run: MediaWiki LocalSettings persist

One-time, human. Open `https://wiki.stagea-stuff.com`, run the web installer.

* Database host: `wiki-db`
* Database name / user / password: `WIKI_DB_*` from `infra/.env`

The official `mediawiki` image serves at **`/`**, not `/w/`. Production `WIKI_URL` is `https://wiki.stagea-stuff.com/`.

`LocalSettings.php` is **not** in git. Named volume `wiki_config` is mounted at `/persist` (not over the docroot). A tiny entrypoint (`infra/wiki/docker-entrypoint.sh`) copies `/persist/LocalSettings.php` into `/var/www/html/LocalSettings.php` on start.

After the installer download:

```bash
# from the repo root, with the downloaded file in the current directory
docker compose -f infra/compose.yaml --env-file infra/.env cp ./LocalSettings.php wiki:/persist/LocalSettings.php
docker compose -f infra/compose.yaml --env-file infra/.env restart wiki
```

Subsequent restarts pick the file up from `wiki_config`. Images persist in `wiki_images`.

### Health

`GET`/`HEAD` `https://stagea-stuff.com/healthz` returns `200` and `ok` (no auth). Every Phase 1 service has a Compose `healthcheck` so `deploy.sh` can wait.

---

## Local development (unchanged)

### `homepage/`

A tiny static landing page that links to every service running on the host. Lets you treat `http://localhost:8090/` as the local-dev hub and click through to the forum, wiki, blog, shop, admins, and ops UIs without remembering individual ports.

Bring it up:

```/dev/null/homepage.sh#L1-2
cd infra/homepage && docker compose up -d
# open http://localhost:8090/
```

The container is `stagea-homepage` (`nginx:alpine`), bound to `8090:80`, and `restart: unless-stopped` so it comes back after a Docker Desktop restart. `index.html` is bind-mounted read-only, so edits are visible on browser refresh — no rebuild needed.

### `blog.override.yaml`

A Docker Compose override that resolves the host-port conflicts between Ghost's dev stack (`blog/compose.dev.yaml`) and the saleor-platform stack:

| Service | Upstream host port | After override |
| --- | --- | --- |
| Ghost Redis | `6379:6379` | unexposed (use `docker exec -it ghost-dev-redis redis-cli`) |
| Ghost mailpit SMTP | `1025:1025` | `11025:1025` |
| Ghost mailpit web UI | `8025:8025` | `18025:8025` |
| Ghost mailpit web UI (e2e) | `8026:8025` | `18026:8025` |

The override file uses Compose's `!override` tag to replace the inherited `ports:` lists rather than append to them, which is what allows the SMTP/web ports to move and the Redis port to disappear entirely.

### `blog-dev.sh`

Thin wrapper around `pnpm nx run ghost-monorepo:docker:dev` that:

1. `cd`s into `blog/`.
2. Sets `DEV_COMPOSE_FILES` to include both Ghost's chosen variant (`compose.dev.sqlite.yaml` by default) and `../infra/blog.override.yaml`.
3. Hands off to Nx, which orchestrates the full dev build.

Use it instead of `cd blog && pnpm dev:sqlite` whenever you want Ghost to run alongside the saleor-platform stack.

```/dev/null/usage.sh#L1-3
./infra/blog-dev.sh                # dev:sqlite (default)
./infra/blog-dev.sh dev            # MySQL variant
./infra/blog-dev.sh dev:mailgun    # Mailgun variant
```
