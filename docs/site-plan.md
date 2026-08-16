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
| `stagea-stuff.com` (apex) | Astro Shell / Shell Edge (global nav, auth-aware chrome) | Astro 6 + Tailwind 4 (in-house) | `shell/` | Active (SSR core, Federated Search engine, Scoped Auth Dashboard & Simulator). Production serves the Shell Edge on the apex. |
| `www.stagea-stuff.com` | Permanent redirect → `https://stagea-stuff.com` | Caddy | n/a | Production redirect |
| `app.stagea-stuff.com` | Permanent redirect → `https://stagea-stuff.com` | Caddy | n/a | Production redirect (legacy hostname; do not serve the Shell here) |
| `forum.stagea-stuff.com` | NodeBB | `github.com/NodeBB/NodeBB` | `forum/` | Implemented (submodule, `master`, pinned to `ac8bad8`) |
| `wiki.stagea-stuff.com` | MediaWiki | `github.com/wikimedia/mediawiki` | `wiki/` | Implemented (submodule, `master`, pinned to `a0a8c14`) |
| `blog.stagea-stuff.com` | Ghost | `github.com/TryGhost/Ghost` | `blog/` | Implemented (submodule, `main`, pinned to `06b62ae2`) |
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

- **Implemented today**: `shell/` (SSR engine, Federated Search, and SSO dashboard active), `forum/`, `wiki/`, `blog/`, `shop/`, `infra/` (production `compose.yaml`, Caddyfile, `deploy.sh`), `docs/` (including our dedicated [Shell Design Reference](./shell/)), `.cursor/skills/`, `skills-lock.json`, `.gitmodules`.
- **Not yet scaffolded**: `apps/`, `packages/`, `turbo.json`, `pnpm-workspace.yaml`, root `package.json`. The placeholder directories `auth/`, `parts/`, and `services/` are currently empty.

## 5. Shell (Global Wrapper)

**Primary choice: Astro** with server islands and the `@astrojs/node` adapter behind Caddy (day-1 edge). The nginx spec in [shell_deployment.md](./deployment/shell_deployment.md) is later hardening, not the go-live proxy.

Responsibilities:

- Render the global header/footer, nav, search bar, and login state.
- Serve the apex `stagea-stuff.com` (and keep `app.` / `www.` as redirects). Link out to forum / wiki / blog / shop on their own subdomains.
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

## 7. Production Deployment

The target architecture above describes *what* runs. How it reaches `stagea-stuff.com` is specified separately in the **[Production Deployment Plan](./deployment/production_plan.md)**. The operator copy-paste runbook is **[GO_LIVE.md](./deployment/GO_LIVE.md)**.

In brief: one Linux VPS, one `infra/compose.yaml`, and Caddy terminating TLS on ports `80`/`443` with every other container private to an internal Compose network. Only the Astro Shell is built from this repository — the **Submodules** run official upstream images in production. Go-live is phased (apex + forum + wiki, then blog, then shop and the Keycloak OIDC IdP), and after one-time host setup, production spin-up is a single command.

Do not duplicate the deployment specification here; the plan is the source of truth for phases, host setup, the one-command contract, and backup/restore. Follow [GO_LIVE.md](./deployment/GO_LIVE.md) on the host.

---

## 8. Architecture & Compliance Documentation

The Stagea platform enforces rigorous system quality controls and 12-factor operations. Refer to these live-updated design assets for our shell engineering standards:

* 🗺️ **[Architecture Map](./architecture.md)** — Request path, what we build vs official images, live vs planned, remaining gaps.
* 📥 **[From-Zero Install Guides](./install-guides.md)** — Start here if you have not cloned yet (production go-live vs local development).
* 📄 **[Production Spin-Up Runbook](./deployment/GO_LIVE.md)** — Operator copy-paste checklist to bring `stagea-stuff.com` online.
* 📄 **[Production Deployment Plan](./deployment/production_plan.md)** — VPS + Docker Compose + Caddy go-live plan, phased service map, one-command deploy contract, and backup/restore minimum.
* 📄 **[Scaling Plan](./deployment/scaling_plan.md)** — Decision matrix in RAM/disk/concurrency, plan through 1,000+ users, running cost as features land.
* 📄 **[Executive Architecture & Quality Report](./EXECUTIVE_AUDIT_REPORT.md)** — Our centralized executive findings, software readiness grades, and prioritized improvement roadmap.
* 📄 **[Documentation & Archiving Guide](./DOCUMENTATION_GUIDE.md)** — Standards for preventing documentation rot, technical terminology drift, and the operations blueprint for the Archiving program.
* 📄 **[System-Wide 12-Factor Compliance](./12_factor_compliance.md)** — Audit of how Stagea maps all twelve factors from 12factor.net to our monorepo architecture.
* 📄 **[Shell 12-Factor Implementation Plan](./shell/12_FACTOR_PLAN.md)** — Independent 12-factor scorecard and action plan specifically for the Astro Shell gateway.
* 📄 **[Shell Code Readiness Ratings](./shell/READINESS_RATING.md)** — Per-file quality audit, strict type-safety scorecards, and engineering pathways for all shell code.
* 📄 **[Shell Scoped Auth Plan](./shell/auth_plan.md)** — Centralized authentication, Keycloak clients, and role hierarchy mappings.
* 📄 **[Shell Sprint Backlog & TODO](./shell/TODO.md)** — Active list of vertical development slices, MVP goals, and the 6-Step Feature Loop.
