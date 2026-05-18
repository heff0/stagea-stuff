# Stagea — Nissan Stagea Community Monorepo

A single-repository bundle of the web services that power the Stagea community platform: a forum, a wiki, a blog, a storefront, an identity provider, and a parts catalogue. Each service is an upstream project pinned here as a Git submodule, wired together by shared infra and packages and kept consistent by the `.cursor/skills/` toolkit.

Public domains this repo targets:

| Subdomain | Service | Upstream | Status in repo |
| --- | --- | --- | --- |
| `stagea-stuff.com` / `app.stagea-stuff.com` | Astro shell (landing page, planned search + OIDC login) | local (`shell/`) | Scaffolded in `shell/` |
| `forum.stagea-stuff.com` | NodeBB (Node.js + Redis/Mongo/Postgres) | `github.com/NodeBB/NodeBB` | Submodule at `forum/` (tracks `master`, pinned to `ac8bad8`) |
| `wiki.stagea-stuff.com` | MediaWiki (PHP) | `github.com/wikimedia/mediawiki` | Submodule at `wiki/` (tracks `master`, pinned to `a0a8c14`) |
| `blog.stagea-stuff.com` | Ghost (Node.js, pnpm + Nx monorepo) | `github.com/TryGhost/Ghost` | Submodule at `blog/` (tracks `main`, pinned to `06b62ae2`) |
| `shop.stagea-stuff.com` | Saleor Storefront "Paper" (Next.js 16 + GraphQL) | `github.com/saleor/storefront` | Submodule at `shop/` (tracks `main`, pinned to `be64a69`) |
| `auth.stagea-stuff.com` | Keycloak (OIDC identity provider) | `github.com/keycloak/keycloak` | Directory reserved (`auth/`), not yet populated |
| `parts.stagea-stuff.com` | Directus-backed parts catalogue | `github.com/directus/directus` | Directory reserved (`parts/`), not yet populated |

## Table of Contents

- [Repository Layout](#repository-layout)
- [What Actually Exists Today](#what-actually-exists-today)
- [Cursor Skills](#cursor-skills)
- [Prerequisites](#prerequisites)
- [Clone & Initialise](#clone--initialise)
- [Running Each App Locally](#running-each-app-locally)
- [Updating a Submodule](#updating-a-submodule)
- [Planned Services](#planned-services)
- [Docs](#docs)
- [Contributing](#contributing)
- [Licensing](#licensing)

## Repository Layout

```/dev/null/layout.txt#L1-19
stagea-stuff/
├── .cursor/skills/         # Enabled Cursor/Zed skills (caveman, compress, stagea-monorepo, …)
├── .gitmodules             # Declares forum, wiki, blog, and shop submodules
├── README.md
├── CONTRIBUTING.md
├── skills-lock.json        # Pinned content hashes for the caveman skill set
├── auth/                   # (empty) reserved for Keycloak
├── blog/                   # Submodule → TryGhost/Ghost (main, pinned to 06b62ae2)
├── docs/                   # Project planning, ADRs, per-app setup notes
├── forum/                  # Submodule → NodeBB/NodeBB (master, pinned to ac8bad8)
├── infra/                  # Compose overrides and wrappers (see infra/README.md)
├── packages/               # (empty) reserved for shared TS packages (ui, auth-client, …)
├── parts/                  # (empty) reserved for Directus parts catalogue
├── services/               # (empty) reserved for backend service configs
├── shell/                  # Astro 6 + Tailwind 4 SSR app: end-user landing, planned search + login
├── shop/                   # Submodule → saleor/storefront (main, pinned to be64a69)
└── wiki/                   # Submodule → wikimedia/mediawiki (master, pinned to a0a8c14)
```

## What Actually Exists Today

- **Forum (`forum/`)** — NodeBB submodule at `master`/`ac8bad8b`. Ships `Dockerfile`, `dev.Dockerfile`, and three compose files (`docker-compose.yml`, `docker-compose-pgsql.yml`, `docker-compose-redis.yml`). Entry point is `./nodebb` (CLI wrapper around `app.js`).
- **Wiki (`wiki/`)** — MediaWiki submodule at `master`/`a0a8c145`. Includes `docker-compose.yml`, `composer.json`, and the `mw-config/` web installer. `LocalSettings.php` is intentionally absent until you run the installer.
- **Blog (`blog/`)** — Ghost monorepo submodule at `main`/`06b62ae2`, managed with `pnpm@10.33.0` and Nx 22. Dev stack is driven by `compose.dev.yaml` plus opt-in overlays (`compose.dev.sqlite.yaml`, `compose.dev.mailgun.yaml`, `compose.dev.analytics.yaml`, `compose.dev.storage.yaml`). Ghost itself has inner submodules, which `pnpm setup` initialises.
- **Shop (`shop/`)** — Saleor storefront submodule at `main`/`be64a69`. Next.js 16 + React 19 + urql + Tailwind. Contents are only present after `git submodule update --init --recursive`.
- **Docs (`docs/`)** — `site-plan.md`, `shop-setup.md`, `app_test_plan.md`, `wiki_options.md`, and a wiki-specific `CONTRIBUTING.md`.
- **Skills (`.cursor/skills/`)** — Six skills, all activated via `ENABLED` marker files (see below).

Everything else (`auth/`, `parts/`, `services/`, `infra/`, `packages/`) is an empty reserved directory. The `site-plan.md` describes the target state; the repo itself has not scaffolded those yet.

## Cursor Skills

The `.cursor/skills/` directory ships six skills. Each is activated by the presence of an empty `ENABLED` file alongside its `SKILL.md`, as required by the `zed-caveman` skill. Hashes for the caveman-family skills are pinned in `skills-lock.json`.

| Skill | Trigger | What it does |
| --- | --- | --- |
| `caveman` | `/caveman`, "caveman mode", "be brief" | Ultra-compressed responses (~75% fewer tokens) at `lite`/`full`/`ultra`/`wenyan-*` intensities. |
| `caveman-commit` | `/commit`, "write a commit" | Conventional Commits subject ≤50 chars, body only when "why" is non-obvious, no AI attribution. |
| `caveman-review` | `/review`, "review this PR" | One-line PR comments in `L<line>: <problem>. <fix>.` form with `🔴 bug`/`🟡 risk`/`🔵 nit`/`❓ q` severity prefixes. |
| `compress` | `/caveman:compress <file>` | Rewrites `CLAUDE.md`/docs in caveman form, keeps code/URLs/paths verbatim, writes backup to `FILE.original.md`. Requires Python 3.10+. |
| `stagea-monorepo` | Any monorepo/layout question | Enforces that all Stagea work stays under `/Users/Shared/dev/stagea-stuff/`; new apps → `apps/<name>/`, shared code → `packages/<name>/`, planning → `docs/`. |
| `zed-caveman` | `/zed-caveman` | Same compression rules as `caveman`, scoped to Zed Agent. Requires an `ENABLED` flag file next to its `SKILL.md`. |

All six skills are currently enabled:

```/dev/null/enabled.txt#L1-6
.cursor/skills/caveman/ENABLED
.cursor/skills/caveman-commit/ENABLED
.cursor/skills/caveman-review/ENABLED
.cursor/skills/compress/ENABLED
.cursor/skills/stagea-monorepo/ENABLED
.cursor/skills/zed-caveman/ENABLED
```

## Prerequisites

Each submodule app brings its own toolchain. Install what you need for the services you intend to run:

- **Git** ≥ 2.30 (required; submodule flow assumes `--recurse-submodules`).
- **Docker Engine** ≥ 24 with Compose v2 (used by `forum/`, `wiki/`, `blog/`, and the planned `infra/` stack).
- **Node.js** ≥ 20 LTS — NodeBB requires Node 20+; Ghost and the Saleor storefront are built against Node 20/22.
- **pnpm** 10.33.0 — enforced by `blog/`; also used by `shop/`. `corepack enable` is the easiest install.
- **PHP** 8.1+ and **Composer** — only if running the wiki without Docker.
- **MongoDB 5+ or Redis 7.2+** — required by NodeBB (pick one as primary store); PostgreSQL is also supported.
- **MySQL 8 / MariaDB 10.6** — required by Ghost in non-sqlite mode, and by MediaWiki.
- **Python 3.10+** — only needed to run the `compress` skill locally.

## Clone & Initialise

```/dev/null/clone.sh#L1-5
git clone --recurse-submodules <this-repo-url> stagea-stuff
cd stagea-stuff

# If you forgot --recurse-submodules:
git submodule update --init --recursive
```

After init, verify all four submodules are populated and at the pinned commits:

```/dev/null/verify.sh#L1-6
git submodule status
# 06b62ae2f3654328ca623271916096818fd0ef23 blog  (v6.25.0-406-g06b62ae2f3)
# ac8bad8bc95394e27445b696515e3d115373bca8 forum (v4.10.2-6-gac8bad8bc9)
# be64a695e57e9cca0fccb2a53ff774c25b0bd109 shop  (heads/main)
# a0a8c1451e44de22451de7421d128bef114765cc wiki  (1.6.0-127028-ga0a8c1451e4)
```

A leading `-` on any line means that submodule hasn't been initialised; a leading `+` means its working tree has moved ahead of the pinned commit.

## Local Hub

Once some or all of the services below are running, `infra/homepage/` provides a single landing page at <http://localhost:8090/> with a navbar linking to every UI (forum, wiki, blog, shop, admin panels, mailpit, Jaeger). It's a static `nginx:alpine` container with one bind-mounted HTML file — no build step.

```/dev/null/hub.sh#L1-2
cd infra/homepage && docker compose up -d
# open http://localhost:8090/
```

## Running Each App Locally

### Forum — NodeBB (`forum/`)

```/dev/null/forum.sh#L1-4
cd forum
docker compose up      # brings up NodeBB + default datastore
# or, native setup:
./nodebb setup && ./nodebb start   # default port 4567
```

Pick one of `docker-compose.yml`, `docker-compose-redis.yml`, or `docker-compose-pgsql.yml` depending on your chosen datastore. Full NodeBB docs: <https://docs.nodebb.org>.

### Wiki — MediaWiki (`wiki/`)

```/dev/null/wiki.sh#L1-9
cd wiki
# Required: tell the compose stack which host UID/GID owns the bind-mounted source.
# Match these to `id -u` / `id -g` on your machine.
printf 'MW_DOCKER_UID=%s\nMW_DOCKER_GID=%s\n' "$(id -u)" "$(id -g)" > .env
docker compose up -d
# First boot returns HTTP 500 "Installing some dependencies is required."
# Fix once by installing PHP deps inside the container:
docker exec -w /var/www/html/w wiki-mediawiki-1 composer install --no-dev --no-interaction
# Then open http://localhost:8080/w/mw-config/index.php to run the installer.
```

Complete the browser installer to generate `LocalSettings.php`, then restart the container. See `docs/wiki_options.md` for the recommended extension set (`VisualEditor`, `Cite`, `ParserFunctions`, `Page Forms`, `SyntaxHighlight_GeSHi`). Full per-app procedure in `docs/app_test_plan.md` §2.2.

### Blog — Ghost (`blog/`)

```/dev/null/blog.sh#L1-4
cd blog && git submodule update --init --recursive   # pulls Casper + Source themes (first time only)
pnpm install --frozen-lockfile                       # installs host workspace (Nx, etc.)
./infra/blog-dev.sh                                  # foreground; brings up the full dev stack
# site: http://localhost:2368/   admin: http://localhost:2368/ghost/   mailpit: http://localhost:18025/
```

`infra/blog-dev.sh` is a thin wrapper around `pnpm nx run ghost-monorepo:docker:dev` that applies `infra/blog.override.yaml`. The override unexposes Ghost's Redis (still reachable inside the Docker network) and shifts Ghost's mailpit to host ports `11025` (SMTP), `18025`/`18026` (web UI) so Ghost can run alongside the saleor-platform stack without conflicts. Pass a variant as the first arg for the non-default stacks: `./infra/blog-dev.sh dev` (MySQL), `dev:mailgun`, `dev:analytics`, `dev:storage`.

If you run `pnpm dev:sqlite` directly (bypassing the wrapper) you'll need to stop `saleor-platform-cache-1` and `saleor-platform-mailpit-1` first, because Ghost upstream's compose binds 6379/1025/8025 on the host.

### Shell — Stagea landing (`shell/`)

```/dev/null/shell.sh#L1-3
cd shell
pnpm install --frozen-lockfile
pnpm dev               # http://localhost:4321/
```

In-house Astro 6 + Tailwind 4 SSR app. Routes today: `/` (landing + service cards), `/search` (placeholder), `/account` (placeholder). The global navbar in `src/components/Header.astro` links forum / wiki / blog / shop at their `localhost:<port>` URLs and is rendered by every page. Full setup notes in `shell/README.md`.

### Shop — Saleor Storefront (`shop/`)

```/dev/null/shop.sh#L1-9
cd shop
cat > .env <<EOF
NEXT_PUBLIC_SALEOR_API_URL=http://localhost:8000/graphql/
NEXT_PUBLIC_STOREFRONT_URL=http://localhost:3000
NEXT_PUBLIC_DEFAULT_CHANNEL=default-channel
EOF
pnpm install --frozen-lockfile
pnpm dev               # http://localhost:3000 (falls back to 3001 if taken)
```

`shop/` runs against an external Saleor GraphQL endpoint; there is no Saleor backend in this monorepo. The easy path is `git clone https://github.com/saleor/saleor-platform && cd saleor-platform && docker compose up -d`, which exposes the GraphQL API at `http://localhost:8000/graphql/` with a seeded `default-channel`. Full setup notes in `docs/shop-setup.md` and `docs/app_test_plan.md` §2.4.

## Updating a Submodule

To bump a service to a newer upstream revision, do it in its own commit so the monorepo's history makes the version change easy to read:

```/dev/null/bump.sh#L1-7
cd <forum|wiki|blog|shop>
git fetch origin
git checkout <branch-or-tag>          # e.g. main, master, v4.11.0
git pull --ff-only
cd ..
git add <forum|wiki|blog|shop>
git commit -m "chore(<name>): bump submodule to <upstream>@<short-sha>"
```

The same pattern documented in `docs/shop-setup.md` §2.3 applies to all four submodules. Include the upstream commit range in the PR body.

## Planned Services

These directories exist as placeholders only. No code has been committed to them yet. The intended contents, per `docs/site-plan.md`, are:

- `auth/` — Keycloak configuration (OIDC IdP, Apache 2.0 licensed) for SSO across all subdomains.
- `parts/` — Directus instance backing a Nissan Stagea parts catalogue API.
- `services/` — Per-service backend configs (e.g. `services/auth/`, `services/parts-api/`).
- `packages/` — Shared TypeScript packages (`ui`, `auth-client`, `api-client`, `config`) consumed by the Astro shell and adapters.

`infra/` already exists (see [`infra/README.md`](infra/README.md)) and currently holds the Compose override and wrapper that let Ghost run alongside the saleor-platform stack. The eventual root `compose.yaml`, `nginx/`, and TLS automation will land in the same directory.

Opening a PR that scaffolds any of these should also update `docs/site-plan.md` to reflect reality.

## Docs

- [`docs/site-plan.md`](docs/site-plan.md) — Target architecture: subdomains, identity layer, monorepo structure, shell.
- [`docs/app_test_plan.md`](docs/app_test_plan.md) — Per-app smoke-test procedures (directory verification, install, build).
- [`docs/shop-setup.md`](docs/shop-setup.md) — Saleor storefront submodule workflow and env vars.
- [`docs/wiki_options.md`](docs/wiki_options.md) — MediaWiki extension picks and custom-plugin proposals.
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — Contribution rules specific to the MediaWiki instance.
- [`infra/README.md`](infra/README.md) — Compose overrides and wrapper scripts that wire submodule stacks together.
- [`shell/README.md`](shell/README.md) — Astro shell scaffold: stack choices, routes, future-extraction plan.

## Contributing

Repo-wide contribution rules are in [`CONTRIBUTING.md`](CONTRIBUTING.md). Wiki-content rules are in [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md). All new work must stay inside this repo (see the `stagea-monorepo` skill).

## Licensing

Each submoduled upstream keeps its own license:

- NodeBB — GPL-3.0 (`forum/LICENSE`)
- MediaWiki — GPL-2.0-or-later (`wiki/COPYING`)
- Ghost — MIT (`blog/LICENSE`)
- Saleor Storefront — see `shop/LICENSE`

The Stagea-specific glue (docs, skills, infra to be added) has no repo-level license file yet. Add one before any public release.
