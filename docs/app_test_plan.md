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
- **Install:** `cd wiki && composer install --no-dev`.
- **Start:** `docker compose up -d` (uses the shipped `wiki/docker-compose.yml`).
- **Setup:** open `http://localhost:8080/mw-config/`, run the installer, download the generated `LocalSettings.php`, drop it into `wiki/`, restart the container.
- **Pass criteria:** `curl -fsS http://localhost:8080/api.php?action=query&meta=siteinfo&format=json | jq -r .query.general.generator` starts with `MediaWiki 1.46` (or whichever minor version the pinned commit ships).
- **Notes:** `LocalSettings.php` is intentionally not committed. Treat `wiki_options.md` as the canonical list of extensions to enable before promoting to staging.

### 2.3 Blog — Ghost (`blog/`)

- **Upstream:** `github.com/TryGhost/Ghost`, branch `main`, pinned to commit `fe4ef54`.
- **Presence check:** `test -f blog/package.json && test -f blog/compose.dev.yaml && test -f blog/pnpm-workspace.yaml`.
- **Tool check:** `corepack enable && pnpm -v` must print `10.33.0` (enforced by `blog/.github/scripts/enforce-package-manager.js`).
- **Install:** `cd blog && pnpm setup` (installs deps and pulls Ghost's own inner submodules).
- **Start:** `pnpm dev` for the default MySQL stack, or `pnpm dev:sqlite` for a zero-config sqlite stack.
- **Pass criteria:** `curl -fsS http://localhost:2368/ghost/api/admin/site/ | jq -r .site.version` returns a semver; `http://localhost:2368/ghost/` loads the admin shell.
- **Teardown:** `pnpm docker:down` (or `pnpm docker:clean` to also remove volumes/images).

### 2.4 Shop — Saleor Storefront (`shop/`)

- **Upstream:** `github.com/saleor/storefront` at commit `be64a69…` (tracked by this repo's `.gitmodules`).
- **Presence check:** `git submodule status shop` prints a commit SHA with no leading `-`. If it has a `-`, run `git submodule update --init --recursive`.
- **Env:** `cp shop/.env.example shop/.env`, then set `NEXT_PUBLIC_SALEOR_API_URL`, `NEXT_PUBLIC_DEFAULT_CHANNEL`, `NEXT_PUBLIC_STOREFRONT_URL`.
- **Install:** `cd shop && pnpm install` (runs `pnpm run generate:all` via the `predev` hook).
- **Start:** `pnpm dev`.
- **Pass criteria:** `curl -fsS http://localhost:3000/ | grep -q "<title>"` succeeds and the product listing renders against the configured Saleor API.
- **Teardown:** stop the dev server.

### 2.5 Auth — Keycloak (`auth/`)

Currently skipped: `auth/` is an empty directory. When scaffolded, the expected test will be:

- `docker compose -f services/auth/compose.yaml up -d`
- `curl -fsS http://localhost:8081/realms/stagea/.well-known/openid-configuration` returns a valid JSON document advertising the `stagea` realm.

### 2.6 Parts — Directus (`parts/`)

Currently skipped: `parts/` is an empty directory. When scaffolded, the expected test will be:

- `docker compose -f services/parts-api/compose.yaml up -d`
- `curl -fsS http://localhost:8055/server/health | jq -r .status` returns `"ok"`.

## 3. Environment Requirements

To run the full matrix you need: Docker Engine ≥ 24, Docker Compose v2, Node.js 20 LTS, pnpm 10.33.0 (via Corepack), PHP 8.1+ with Composer, and at least 8 GiB of free RAM (Ghost + MediaWiki + NodeBB + Saleor storefront running concurrently peaks around 5–6 GiB).

## 4. Reporting

Record each test as `pass`, `fail`, or `skipped` in the PR description that bumps an upstream. For failures, attach:

- Exact command run.
- Last 50 lines of container logs (`docker compose logs --tail=50 <service>`).
- Output of `git submodule status` and `node -v && pnpm -v && php -v && docker version --format '{{.Server.Version}}'`.
