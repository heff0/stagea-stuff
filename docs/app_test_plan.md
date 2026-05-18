# Per-App Smoke Test Plan

This plan verifies that each submoduled application in this monorepo is present, installable, and reaches a known-good first-run state. Run it after every upstream bump and after a fresh `git clone --recurse-submodules`.

## 1. Scope and Ordering

Run the tests in this order — later apps may depend on shared datastores or on Keycloak once `auth/` is implemented:

1. `forum/` (NodeBB)
2. `wiki/` (MediaWiki)
3. `blog/` (Ghost)
4. `shop/` (Saleor storefront)
5. `auth/` — **skip**, directory is currently empty
6. `parts/` — **skip**, directory is currently empty

Each test below lists the exact commands to run and the observable result that counts as a pass.

## 2. Per-App Tests

### 2.1 Forum — NodeBB (`forum/`)

- **Upstream:** `github.com/NodeBB/NodeBB`, branch `master`, pinned to commit `ac8bad8`.
- **Presence check:** `test -f forum/app.js && test -f forum/package.json && test -x forum/nodebb`
- **Install:** `cd forum && npm ci`
- **Datastore:** start one of `docker compose -f docker-compose-redis.yml up -d` or `docker compose -f docker-compose-pgsql.yml up -d`.
- **Setup:** `./nodebb setup` — accept defaults for URL (`http://localhost:4567`), point at the datastore you started, create an admin.
- **Start:** `./nodebb start`
- **Pass criteria:** `curl -fsS http://localhost:4567/api/config | jq -r .version` returns a non-empty semver string.
- **Teardown:** `./nodebb stop && docker compose -f <file> down -v`.

### 2.2 Wiki — MediaWiki (`wiki/`)

- **Upstream:** `github.com/wikimedia/mediawiki`, branch `master`, pinned to commit `a0a8c14`.
- **Presence check:** `test -f wiki/index.php && test -d wiki/mw-config && test -d wiki/includes`.
- **Tool check:** Docker only (Apache + PHP-FPM run in containers). The images are `linux/amd64` so on Apple Silicon they run under Rosetta — Docker Desktop must have Rosetta emulation enabled.
- **Create `wiki/.env` first.** The compose file requires `MW_DOCKER_UID` and `MW_DOCKER_GID` so the bind-mounted source files have the right ownership. Run `id -u` and `id -g` to get yours, then write a two-line `.env`:
  ```
  MW_DOCKER_UID=<id -u>
  MW_DOCKER_GID=<id -g>
  ```
  This file is per-machine — it is matched by the root `.gitignore` `.env` rule and must not be committed.
- **Start:** `cd wiki && docker compose up -d`. Three containers come up: `wiki-mediawiki-1` (php-fpm), `wiki-mediawiki-web-1` (apache on 8080), and `wiki-mediawiki-jobrunner-1`.
- **Install dependencies inside the container.** The submodule ships source without a vendored `vendor/` directory, so the first request returns HTTP 500 with the message "Installing some dependencies is required." Fix once with:
  ```
  docker exec -w /var/www/html/w wiki-mediawiki-1 composer install --no-dev --no-interaction
  ```
  On Apple Silicon under Rosetta this takes ~2–4 minutes.
- **Setup:** open `http://localhost:8080/w/mw-config/index.php` (note the `/w` script path — the bare `/mw-config/` route returns 404). Run the installer, download the generated `LocalSettings.php`, drop it into `wiki/`, restart the container.
- **Pass criteria:**
  - Before installer: `curl -fsS http://localhost:8080/w/` returns HTTP 200 with `<title>MediaWiki 1.46.0-alpha</title>` and a body that links to `/w/mw-config/index.php`.
  - After installer: `curl -fsS http://localhost:8080/w/api.php?action=query&meta=siteinfo&format=json | jq -r .query.general.generator` starts with `MediaWiki 1.46`.
- **Notes:** `LocalSettings.php` is intentionally not committed. Treat `wiki_options.md` as the canonical list of extensions to enable before promoting to staging. The submodule tracks `master`, which currently advertises itself as `1.46.0-alpha`; pin to `REL1_46` if you want stable `1.46.0`.

### 2.3 Blog — Ghost (`blog/`)

- **Upstream:** `github.com/TryGhost/Ghost`, branch `main`, pinned to commit `06b62ae2`.
- **Presence check:** `test -f blog/package.json && test -f blog/compose.dev.yaml && test -f blog/pnpm-workspace.yaml`.
- **Tool check:** `corepack enable` (Ghost's enforcement script accepts any pnpm — the in-tree `packageManager` field is `pnpm@10.33.0`).
- **Init Ghost's inner submodules.** Ghost itself has two theme submodules (`ghost/core/content/themes/casper`, `ghost/core/content/themes/source`). The Stagea monorepo will only initialise its own top-level submodules, so inside `blog/` run:
  ```
  git submodule update --init --recursive
  ```
- **Install host workspace:** `cd blog && pnpm install --frozen-lockfile`. This installs Nx and the workspace tooling needed for `pnpm dev`. Allow ~1 min on a warm cache, ~5 min cold.
- **Port preflight.** Upstream Ghost binds `2368`, `6379`, `1025`, `8025`, `8026` on the host (and `3306` in non-sqlite mode). The Stagea-side `infra/blog.override.yaml` resolves the conflict with `saleor-platform-cache-1` (6379) and `saleor-platform-mailpit-1` (1025/8025) by:
  - Removing Ghost's Redis host port (still reachable inside the Docker network as `ghost-dev-redis:6379`).
  - Shifting Ghost's mailpit ports to `11025` (SMTP), `18025`, and `18026` (web UI).
  
  With the override, only `2368` and `11025`/`18025`/`18026` need to be free on the host. Everything else stays inside the `ghost_dev` Docker network.
- **Start:** `./infra/blog-dev.sh` from the repo root (default: SQLite). Pass `dev` for MySQL, `dev:mailgun`/`dev:analytics`/`dev:storage` for the other Ghost variants. This is a long-running foreground task — it does `docker compose up -d --build`, then `nx run-many dev` for the admin SPA and four other workspace apps. First build is ~10–20 min on Apple Silicon. Subsequent boots reuse the build cache and finish in ~30s.
  
  Running `cd blog && pnpm dev:sqlite` directly works too, but only when Saleor's cache and mailpit containers are stopped — it bypasses the override.
- **Pass criteria:**
  - `curl -fsS http://localhost:2368/` returns HTTP 200 with `<title>Ghost</title>` (the Casper theme).
  - `curl -fsS http://localhost:2368/ghost/api/admin/site/ | jq -r .site.version` returns a semver (verified: `6.33`).
  - `http://localhost:2368/ghost/` loads the Ember admin shell. **Note:** if you `Ctrl-C` the wrapper before the admin SPA finishes booting, this URL returns 502 — that is the Caddy gateway failing to find the admin dev server, not a Ghost backend failure.
  - `curl -fsS http://localhost:18025/` returns HTTP 200 with `<title>Mailpit</title>` (the Stagea-shifted mailpit UI).
  - With the override active, `docker port ghost-dev-redis` lists only `6379/tcp` (container port, no host binding) and `docker port ghost-dev-mailpit` lists `11025/18025/18026` on the host.
- **Teardown:** `pnpm docker:down` (or `pnpm docker:clean` to also remove volumes/images).

### 2.4 Shop — Saleor Storefront (`shop/`)

- **Upstream:** `github.com/saleor/storefront` at commit `be64a695` (tracked by this repo's `.gitmodules`).
- **Presence check:** `git submodule status shop` prints a commit SHA with no leading `-`. If it has a `-`, run `git submodule update --init --recursive`.
- **Saleor backend prerequisite.** `shop/` is a storefront only — it needs a live Saleor GraphQL endpoint to talk to. Two options:
  1. **Local Saleor platform** via the upstream `saleor/saleor-platform` compose stack. Endpoint: `http://localhost:8000/graphql/`. Spin one up with `git clone https://github.com/saleor/saleor-platform.git && cd saleor-platform && docker compose up -d`. Confirm with `curl -X POST http://localhost:8000/graphql/ -H 'Content-Type: application/json' -d '{"query":"{ shop { name } }"}'`.
  2. **A cloud Saleor instance** at `https://<name>.saleor.cloud/graphql/`.
- **Env:** create `shop/.env` (this is matched by the root `.gitignore` and must not be committed):
  ```
  NEXT_PUBLIC_SALEOR_API_URL=http://localhost:8000/graphql/
  NEXT_PUBLIC_STOREFRONT_URL=http://localhost:3000
  NEXT_PUBLIC_DEFAULT_CHANNEL=default-channel
  ```
  `NEXT_PUBLIC_DEFAULT_CHANNEL` must match an active channel in the backing Saleor instance (the upstream `saleor-platform` ships with `default-channel`).
- **Install:** `cd shop && pnpm install --frozen-lockfile`. The `predev`/`prebuild` hooks then run `pnpm run generate:all`, which fetches the Saleor GraphQL schema from `NEXT_PUBLIC_SALEOR_API_URL` and generates TypeScript types under `src/gql/` and `src/checkout/graphql/generated/`. Codegen failures here mean the Saleor URL is wrong or the backend is unreachable.
- **Start:** `pnpm dev`. Next.js binds `http://localhost:3000` (or falls back to 3001 if 3000 is in use). The root path 307-redirects to `/<NEXT_PUBLIC_DEFAULT_CHANNEL>`.
- **Pass criteria:**
  - `curl -fsSL http://localhost:3000/` returns HTTP 200 with `<title>ACME Storefront, powered by Saleor &amp; Next.js | Saleor Store</title>`.
  - `curl -fsS http://localhost:3000/default-channel/products` returns HTTP 200 and the product listing.
  - The dev-server log shows `POST http://localhost:8000/graphql/ 200` requests on each page load — confirms the storefront is actually pulling from the configured Saleor backend, not a stale cache.
- **Teardown:** stop the dev server (`pkill -f 'next dev'` or `Ctrl-C`).

### 2.5 Auth — Keycloak (`auth/`)

Currently skipped: `auth/` is an empty directory. When scaffolded, the expected test will be:

- `docker compose -f services/auth/compose.yaml up -d`
- `curl -fsS http://localhost:8081/realms/stagea/.well-known/openid-configuration` returns a valid JSON document advertising the `stagea` realm.

### 2.6 Parts — Directus (`parts/`)

Currently skipped: `parts/` is an empty directory. When scaffolded, the expected test will be:

- `docker compose -f services/parts-api/compose.yaml up -d`
- `curl -fsS http://localhost:8055/server/health | jq -r .status` returns `"ok"`.

## 3. Running Everything in Parallel

All four submodule services plus the upstream `saleor-platform` stack can run concurrently on a single host once `infra/blog.override.yaml` is in effect. Verified port allocation when every stack is up:

| Host port | Owner | Service |
| --- | --- | --- |
| `2368` | `ghost-dev-gateway` | Ghost site + admin |
| `3000` | host node | Saleor storefront (`shop/`, `pnpm dev`) |
| `4567` | `forum-nodebb-1` | NodeBB web UI |
| `5432` | `saleor-platform-db-1` | Saleor Postgres |
| `6379` | `saleor-platform-cache-1` | Saleor Valkey (Ghost Redis stays internal-only) |
| `8000` | `saleor-platform-api-1` | Saleor GraphQL API |
| `8025` | `saleor-platform-mailpit-1` | Saleor mailpit UI |
| `8080` | `wiki-mediawiki-web-1` | MediaWiki Apache |
| `9000` | `saleor-platform-dashboard-1` | Saleor admin dashboard |
| `11025` | `ghost-dev-mailpit` | Ghost mailpit SMTP (shifted from `1025` by override) |
| `16686` | `saleor-platform-jaeger-1` | Saleor Jaeger tracing UI |
| `18025` | `ghost-dev-mailpit` | Ghost mailpit web UI (shifted from `8025` by override) |
| `18026` | `ghost-dev-mailpit` | Ghost mailpit web UI alt (shifted from `8026` by override) |
| `27017` | `forum-mongo-1` | NodeBB Mongo |

Startup order that works from a cold box:

```/dev/null/up-all.sh#L1-7
cd saleor-platform && docker compose up -d
cd ../stagea-stuff/forum && docker compose up -d
cd ../wiki && docker compose up -d
cd ..
./infra/blog-dev.sh &                              # foreground task; & to background it
cd shop && pnpm dev &                              # also foreground; & to background it
```

Peak host resources with all five stacks healthy and idle: ~6 GiB RAM, ~14 listening TCP ports.

## 4. Environment Requirements

To run the full matrix you need: Docker Engine ≥ 24, Docker Compose v2, Node.js 20 LTS, pnpm 10.33.0 (via Corepack), PHP 8.1+ with Composer, and at least 8 GiB of free RAM (Ghost + MediaWiki + NodeBB + Saleor storefront running concurrently peaks around 5–6 GiB).

## 5. Reporting

Record each test as `pass`, `fail`, or `skipped` in the PR description that bumps an upstream. For failures, attach:

- Exact command run.
- Last 50 lines of container logs (`docker compose logs --tail=50 <service>`).
- Output of `git submodule status` and `node -v && pnpm -v && php -v && docker version --format '{{.Server.Version}}'`.
