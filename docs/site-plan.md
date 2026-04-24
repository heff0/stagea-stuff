# Stagea Platform Site Plan

This document describes the target architecture for the Stagea community platform and flags which parts already exist in this repository versus which are still planned. Keep this file in sync with the repo: when you scaffold a planned piece, move it from "Planned" to "Implemented" here in the same PR.

## 1. Goals (non-negotiable)

- **Permissive or copyleft-compatible licensing only** — MIT, Apache 2.0, BSD, GPL-2/3 are acceptable; AGPL and SSPL are not.
- **Docker-first deployment** — every service must run from a top-level `docker compose up` in `infra/`. Native runs stay a per-app convenience.
- **SSR where it matters** — storefront (`shop/`) and shell (`apps/shell/`) render server-side; admin UIs can be CSR.
- **Single sign-on via OIDC** — Keycloak is the identity provider; every other service delegates auth to it.
- **Subdomain-per-service** — no path-based routing. Each service owns its subdomain (see table below).

## 2. Subdomain Map

| Subdomain | Service | Upstream | Repo path | State |
| --- | --- | --- | --- | --- |
| `app.stagea-stuff.com` | Astro shell (global nav, auth-aware chrome) | to be chosen from: Astro, Next.js, Nuxt | `apps/shell/` | Planned |
| `forum.stagea-stuff.com` | NodeBB | `github.com/NodeBB/NodeBB` | `forum/` | Implemented (submodule, `master`, pinned to `ac8bad8`) |
| `wiki.stagea-stuff.com` | MediaWiki | `github.com/wikimedia/mediawiki` | `wiki/` | Implemented (submodule, `master`, pinned to `a0a8c14`) |
| `blog.stagea-stuff.com` | Ghost | `github.com/TryGhost/Ghost` | `blog/` | Implemented (submodule, `main`, pinned to `fe4ef54`) |
| `shop.stagea-stuff.com` | Saleor Storefront "Paper" | `github.com/saleor/storefront` | `shop/` | Implemented (submodule, `main`, pinned to `be64a69`) |
| `auth.stagea-stuff.com` | Keycloak | `github.com/keycloak/keycloak` | `auth/`, `services/auth/` | Planned (directory empty) |
| `parts.stagea-stuff.com` | Directus parts catalogue | `github.com/directus/directus` | `parts/`, `services/parts-api/` | Planned (directory empty) |

## 3. Identity Layer

**Primary choice: Keycloak** (`github.com/keycloak/keycloak`, Apache 2.0).

Responsibilities:

- OpenID Connect provider for all six services above.
- Single realm `stagea` with one client per service (`forum-client`, `wiki-client`, `blog-client`, `shop-client`, `shell-client`, `parts-client`).
- Account federation: email/password plus GitHub and Google IdPs.
- Role mapping → forum groups, wiki user rights, Ghost member tiers, Saleor permissions.

Considered and rejected:

- **Authelia** (Apache 2.0) — reverse-proxy focused, thin on account self-service UI. Rejected for Stagea because users need profile/email management in one place.
- **Authentik** (MIT) — modern UX but historical AGPL provenance and heavier resource footprint than Keycloak at our scale.
- **Ory Hydra** (Apache 2.0) — headless OAuth2/OIDC only, no account UI; would require building login/profile screens ourselves.

## 4. Monorepo Structure (target)

```/dev/null/target-layout.txt#L1-24
stagea-stuff/
├── apps/
│   ├── shell/            # Astro wrapper, global nav, auth-aware UI
│   ├── parts-ui/         # (optional) Nissan Stagea parts browser frontend
│   └── adapters/
│       ├── forum/        # thin Next/Astro adapter that embeds NodeBB
│       ├── wiki/         # adapter for MediaWiki SSO + styling
│       ├── shop/         # adapter wiring Saleor storefront into the shell
│       └── blog/         # adapter for Ghost Content API
├── services/
│   ├── auth/             # Keycloak realm export + compose
│   └── parts-api/        # Directus schema + compose
├── packages/
│   ├── ui/               # shared React/Tailwind primitives
│   ├── auth-client/      # OIDC client wrapper used by all apps
│   ├── api-client/       # typed clients for NodeBB, Ghost, Saleor, Directus, MediaWiki
│   └── config/           # shared tsconfig, eslint, tailwind presets
├── infra/
│   ├── docker/           # per-service Dockerfiles not owned by upstream
│   ├── nginx/            # edge routing for *.stagea-stuff.com
│   └── compose.yaml      # root compose that brings up the full stack
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

Current vs target:

- **Implemented today**: `forum/`, `wiki/`, `blog/`, `shop/`, `docs/`, `.cursor/skills/`, `skills-lock.json`, `.gitmodules`.
- **Not yet scaffolded**: `apps/`, `services/`, `packages/`, `infra/`, `turbo.json`, `pnpm-workspace.yaml`, root `package.json`. The placeholder directories `auth/`, `parts/`, `services/`, `infra/`, and `packages/` are currently empty.

## 5. Shell (Global Wrapper)

**Primary choice: Astro** with server islands and the `@astrojs/node` adapter behind nginx.

Responsibilities:

- Render the global header/footer, nav, search bar, and login state.
- Proxy `app.stagea-stuff.com/*` to the appropriate backend or embed via iframe/SSR fetch where licensing allows.
- Host the landing page and marketing pages (plain Markdown content collections).
- Exchange the OIDC session cookie from Keycloak for a signed header that downstream services can trust.

Considered and rejected:

- **Next.js 16** — already in use in `shop/`; acceptable alternative but heavier than Astro for a content-mostly shell.
- **SvelteKit** — fine technically but fragments the frontend stack (React in shop, Svelte in shell).
- **Nuxt 3** — requires committing to the Vue ecosystem; rejected to keep one React-family toolchain across `apps/` and `shop/`.

## 6. Out of Scope (for now)

- Native mobile apps. A PWA from the shell is sufficient until forum traffic warrants otherwise.
- Payments infrastructure beyond what Saleor ships. Stripe is configured inside Saleor, not at the shell level.
- Email delivery service selection. Defer until `auth/` and `blog/` are both live; Ghost already supports Mailgun via `compose.dev.mailgun.yaml`.
