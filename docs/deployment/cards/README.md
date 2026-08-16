# Production Go-Live Sprint Cards

Vertical-slice cards for taking `stagea-stuff.com` live. The slice list and order are fixed in the [Production Deployment Plan §7](../production_plan.md#7-vertical-slices). Do not invent a different list or reorder.

**Phase 1 slices 02–06 are implemented in the repo.** Slice 01 is documented; the operator performs it on the VPS. Later slices remain not started.

Cards follow the same shape as [Shell sprint cards](../../shell/cards/card_1_jwks_auth.md) and the [6-step feature loop](../../shell/TODO.md#1-the-6-step-developer-feature-loop). Glossary terms: **Astro Shell** / **Shell Edge**, **Keycloak OIDC IdP**, **Submodules**, **Directus Parts API** — see the [Documentation Guide](../../DOCUMENTATION_GUIDE.md#2-preventing-duplication--technical-term-shift).

The subdomain-to-service map, image provenance, and named volumes live in [production_plan.md §3](../production_plan.md#3-service-map). Do not duplicate that table here.

---

## Phase 1 — go-live (implementation-ready)

Slices 01–06 are the go-live target: hardened host, Caddy TLS, Astro Shell on the apex, forum, wiki, and the one-command contract. After slice 06, `./infra/deploy.sh` brings the Phase 1 stack to healthy.

| Slice | Card | Increment | Status |
| :--- | :--- | :--- | :--- |
| 1 | [Host Baseline](./slice_01_host_baseline.md) | VPS can run containers; only `22`/`80`/`443` open | documented; operator performs on VPS |
| 2 | [Edge Skeleton](./slice_02_edge_skeleton.md) | Caddy on `80`/`443` with a real Let's Encrypt cert | implemented in repo |
| 3 | [Shell Edge Online](./slice_03_shell_edge_online.md) | Apex serves the Astro Shell | implemented in repo |
| 4 | [Forum Node Online](./slice_04_forum_node_online.md) | `forum.` serves official NodeBB + Redis | implemented in repo |
| 5 | [Wiki Node Online](./slice_05_wiki_node_online.md) | `wiki.` serves official MediaWiki + MariaDB; Phase 1 content-complete | implemented in repo |
| 6 | [One-Command Contract](./slice_06_one_command_contract.md) | `./infra/deploy.sh` is the only routine deploy | implemented in repo |

Do not start Ghost, Saleor, the Keycloak OIDC IdP, or the Directus Parts API in slices 01–06.

---

## Later slices — deferred

| Slice | Card | Phase | Status |
| :--- | :--- | :--- | :--- |
| 7 | [Backup Loop](./slice_07_backup_loop.md) | 2 (operability) | not started — deferred |
| 8 | [Image Supply Chain](./slice_08_image_supply_chain.md) | 2 (operability) | not started — deferred |
| 9 | [Blog Node Online](./slice_09_blog_node_online.md) | 2 | not started — deferred |
| 10 | [Observability Baseline](./slice_10_observability_baseline.md) | 2 (operability) | not started — deferred |
| 11 | [Identity and Commerce](./slice_11_identity_and_commerce.md) | 3 | not started — deferred |

Do not begin slice 11 until at least two Phase 1 services have real users.

---

## Hard constraints (every Phase 1 card)

These are already decided in the plan. Cards encode them; they do not reopen them.

* One Linux VPS, one `infra/compose.yaml`, Caddy on host ports `80`/`443` **only**.
* Official images for NodeBB, MediaWiki, Redis, MariaDB, Caddy — never build **Submodules** in production.
* Only the **Astro Shell** is built from this repo (`shell/Dockerfile`).
* Apex `stagea-stuff.com` serves the Astro Shell; `www` and `app` redirect to apex.
* Internal Compose network; no host `ports:` except Caddy.
* One command after initial setup: `./infra/deploy.sh`.
* Escape hatch: `docker compose -f infra/compose.yaml --env-file infra/.env up -d`.
* `infra/.env` is gitignored; `infra/.env.example` is the inventory.
* Pin image tags (no `:latest`).
* Pin policy for Phase 1 starting tags is on each card; confirm the tag still exists on Docker Hub at implement time.

---

## 🔗 Related Documentation

* 🌍 **[Production Deployment Plan](../production_plan.md)** — plan of record (platform, service map, one-command contract, slices).
* 🚀 **[Development Stack Deployment Guide](../README.md)** — local development only.
* 🐳 **[Astro Shell Production & Staging Deployment Guide](../shell_deployment.md)** — Shell image, env contract, forwarded-header requirements.
* 🧭 **[Platform Master Site-Plan](../../site-plan.md)** — subdomain map SSOT.
* 📄 **[Documentation Guide](../../DOCUMENTATION_GUIDE.md)** — taxonomy, glossary, SSOT rule.
