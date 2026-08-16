# Stagea: From Zero

This is the **from-zero hub**. If you have not cloned the repo yet, start here. Pick a path,
then open the linked runbook — do not mix production and local steps.

Canonical product map (subdomains, licensing, identity): [site-plan.md](./site-plan.md).
Visibility map (request path, what we build vs official images): [architecture.md](./architecture.md).
Honest remaining gaps (backups, empty IdP, blog/shop not in production Compose)
live at the top of [architecture.md](./architecture.md#remaining-gaps).
Per-module auto-deploy on `main`: [deployment/ci-cd.md](./deployment/ci-cd.md).

---

## Documentation map

| You want | Open |
| :--- | :--- |
| Production **how** (DNS, harden, secrets, `./infra/deploy.sh`, wizards) | [deployment/GO_LIVE.md](./deployment/GO_LIVE.md) |
| Production **why / what** (phases, volumes, backup *plan*) | [deployment/production_plan.md](./deployment/production_plan.md) |
| Local stack (ports, launch order, collisions) | [deployment/README.md](./deployment/README.md) |
| Per-app local boot (NodeBB, MediaWiki, Ghost, shop) | [deployment/services_setup.md](./deployment/services_setup.md) |
| Picture of the running system | [architecture.md](./architecture.md) |
| Auto-deploy on `main` (per module) | [deployment/ci-cd.md](./deployment/ci-cd.md) |
| Product SSOT (hosts, planned vs implemented) | [site-plan.md](./site-plan.md) |
| Glossary and SSOT rule | [DOCUMENTATION_GUIDE.md](./DOCUMENTATION_GUIDE.md) |

---

## Path A — Production go-live

Bring `stagea-stuff.com` online on one Linux VPS.

**Do not paste or follow a second runbook here.** The operator checklist is
**[deployment/GO_LIVE.md](./deployment/GO_LIVE.md)**.

After that file's one-time host setup (DNS, harden, clone **without Submodules**,
`infra/.env`), routine spin-up is:

```bash
./infra/deploy.sh
```

Production does **not** clone **Submodules**. The host runs official images for
NodeBB and MediaWiki. Only the **Astro Shell** is built from this repository.
See [architecture.md](./architecture.md) and [production_plan.md](./deployment/production_plan.md).

---

## Path B — Local development

You will clone source, including **Submodules**, and start apps per directory.

```bash
git clone --recurse-submodules https://github.com/heff0/stagea-stuff.git stagea-stuff
cd stagea-stuff
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

Until that init finishes, `forum/`, `wiki/`, `blog/`, and `shop/` are gitlinks.
In-tree README links below may 404 in a local working tree; GitHub still renders
the pointer to the pinned upstream commit.

Then follow the **local install guide** column in the module table (one app at a
time). Stack-wide ports and launch order:
[deployment/README.md](./deployment/README.md).

---

## Production vs local (do not mix)

| | Production (Path A) | Local (Path B) |
| :--- | :--- | :--- |
| Clone | `git clone` only — **no** `git submodule update --init` | `git clone --recurse-submodules` |
| **Submodules** | Not populated; not built | Required working trees |
| Images | Official NodeBB / MediaWiki / Caddy / Redis / MariaDB; **Astro Shell** built from `shell/` | Built or run from Submodule source and local compose |
| Edge | Caddy on `80`/`443` | None — `localhost:<port>` per app |
| Startup | `./infra/deploy.sh` after GO_LIVE initial setup | Per-app; see local guides |
| Compose | One file: `infra/compose.yaml` | Per-app compose / `pnpm dev`; not the production file |

---

## Module index

Subdomain ownership and implemented-vs-planned state:
[site-plan.md §2](./site-plan.md#2-subdomain-map). Do not treat this table as a
second host map — it is the install index (path, local guide, upstream).

In-tree Submodule READMEs are present only after `git submodule update --init`
(or a recurse clone). They are still linked so GitHub can resolve the gitlink.

| Module | Repo path | Production host | Local install guide | Upstream / in-tree README |
| :--- | :--- | :--- | :--- | :--- |
| **Astro Shell** / **Shell Edge** (not a Submodule) | `shell/` | `stagea-stuff.com` (apex). `www` and `app` redirect to apex. | [../shell/README.md](../shell/README.md) | In-house. [shell/README.md](../shell/README.md) |
| Forum (NodeBB) | `forum/` | `forum.stagea-stuff.com` | [deployment/services_setup.md](./deployment/services_setup.md) §1 | [forum/README.md](../forum/README.md) · [github.com/NodeBB/NodeBB](https://github.com/NodeBB/NodeBB) |
| Wiki (MediaWiki) | `wiki/` | `wiki.stagea-stuff.com` | [deployment/services_setup.md](./deployment/services_setup.md) §2 | [wiki/README.md](../wiki/README.md) · [github.com/wikimedia/mediawiki](https://github.com/wikimedia/mediawiki) |
| Blog (Ghost) | `blog/` | `blog.stagea-stuff.com` (Phase 2 — **not** in production Compose yet) | [deployment/services_setup.md](./deployment/services_setup.md) §3 | [blog/README.md](../blog/README.md) · [github.com/TryGhost/Ghost](https://github.com/TryGhost/Ghost) |
| Shop (Saleor Storefront) | `shop/` | `shop.stagea-stuff.com` (Phase 3 — **not** in production Compose yet) | [shop-setup.md](./shop-setup.md) | [shop/README.md](../shop/README.md) · [github.com/saleor/storefront](https://github.com/saleor/storefront) |
| **Keycloak OIDC IdP** | `auth/` | `auth.stagea-stuff.com` | **Not populated** | Planned. Empty directory. See [site-plan.md §3](./site-plan.md#3-identity-layer) |
| **Directus Parts API** | `parts/` | `parts.stagea-stuff.com` | **Not populated** | Planned. Empty directory. See [site-plan.md §2](./site-plan.md#2-subdomain-map) |
| Production edge + Compose | `infra/` | Caddy terminates TLS for the public hosts above | Local wrappers: [infra/README.md](../infra/README.md) | Not a Submodule. Production: `infra/compose.yaml`, `infra/deploy.sh` |

---

## Stagea-specific local notes

These are **this repo's** overlays. Upstream READMEs do not know about them.

| Topic | Doc |
| :--- | :--- |
| Per-service local boot and troubleshooting | [deployment/services_setup.md](./deployment/services_setup.md) |
| Saleor storefront env + external GraphQL API | [shop-setup.md](./shop-setup.md) |
| MediaWiki extension set for Stagea | [wiki_options.md](./wiki_options.md) |
| Ghost port-conflict wrapper (`./infra/blog-dev.sh`) and production Compose notes | [infra/README.md](../infra/README.md) |
| Local host port matrix and launch sequence | [deployment/README.md](./deployment/README.md) |

There is no Saleor backend in this monorepo. Local shop needs an external
Saleor GraphQL endpoint (typically `saleor-platform` on another clone). That is
documented in [shop-setup.md](./shop-setup.md), not here.

---

## Related

* [Architecture](./architecture.md) — request path, monorepo map, remaining gaps
* [Production Spin-Up Runbook](./deployment/GO_LIVE.md) — Path A
* [Development Stack Deployment Guide](./deployment/README.md) — Path B stack
* [Platform Master Site-Plan](./site-plan.md) — product SSOT
* [Documentation Guide](./DOCUMENTATION_GUIDE.md) — glossary and SSOT rule
