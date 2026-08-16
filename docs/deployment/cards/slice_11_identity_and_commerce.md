# Slice 11 — Identity and Commerce

**Status**: not started — deferred (Phase 3)  
**Phase 1 go-live**: no  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md), plus **at least two Phase 1 services with real users**

---

## 🎯 1. Overview & Why This Increment

Phase 3 only. Stand up the **Keycloak OIDC IdP** (official `keycloak` image + its database) at `auth.stagea-stuff.com`, then migrate the forum, wiki, and Shell Edge to OIDC **one service at a time**. Separately, stand up Saleor (Saleor Cloud or self-hosted saleor-platform) and point the storefront at `shop.stagea-stuff.com`. The **Directus Parts API** is the same phase on the service map (`parts.stagea-stuff.com`) — add it only when the parts catalogue is actually needed; do not bundle it as a prerequisite for SSO.

Identity migration on an empty platform is pure cost. Saleor roughly doubles the host memory footprint. **Do not begin this slice until at least two Phase 1 services have real users.**

Canonical identity intent: [site-plan.md §3](../../site-plan.md#3-identity-layer). Service map: [production_plan.md §3](../production_plan.md#3-service-map).

---

## 🛠 2. Technical Blueprint (deferred)

| Path | Action (when this slice starts) |
| :--- | :--- |
| `infra/compose.yaml` | **Change** — add `auth` (official `keycloak`, pinned) + `auth-db`; later `shop` storefront. No host `ports:` except Caddy. Volume `auth_db_data`. |
| `infra/Caddyfile` | **Change** — `auth.stagea-stuff.com`, `shop.stagea-stuff.com`. |
| `infra/.env.example` | **Change** — replace Phase 1 Keycloak placeholders with real realm/client secrets; Saleor API URL. |
| `infra/deploy.sh` | **Change** — required keys, health-wait, summary URLs. |
| `shell/` | **Change** — point Astro Shell OIDC at the live Keycloak OIDC IdP (`AUTH_*` already named). |
| `forum/`, `wiki/`, `shop/` | **Do not build Submodules** for production images. Configure official/runtime images for OIDC. |
| `services/auth/`, `services/parts-api/` | Realm export / Directus schema when those dirs are scaffolded — still inside this repo. |

Migrate in order: Keycloak up → Shell Edge → forum → wiki (each step independently reversible). Saleor is a separate track, not a blocker for SSO.

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: one login at `auth.stagea-stuff.com` carries across the apex and the forum.
2. **Test**: each service's migration to OIDC is independently reversible (feature flag, IdP toggle, or documented rollback to local accounts).
3. Official Keycloak image; no `:latest`; no host ports on Keycloak or its DB.
4. Shop (when landed) uses the storefront image + external Saleor GraphQL — not a from-source `shop/` production build.
5. Directus Parts API, if started, uses the official `directus` image and stays on the internal network behind Caddy.

---

## 🚦 4. 6-Step Feature Loop Checklist

- [ ] **1. Scaffold**: `auth` + `auth-db` drafts; DNS for `auth` (and `shop`/`parts` when those tracks start).
- [ ] **2. Document**: Link [site-plan.md §3](../../site-plan.md#3-identity-layer) and [shell auth plan](../../shell/auth_plan.md). Do not duplicate the realm/client table.
- [ ] **3. MVP Spec**: The five criteria above, plus a written rollback per service.
- [ ] **4. Test**: SSO on Shell + forum; disable OIDC on forum and confirm local login still works.
- [ ] **5. Implement**: One service at a time. Saleor on its own PR if possible.
- [ ] **6. Review**: Memory footprint on the 8 GB host; do not start Saleor and Keycloak in the same weekend as a surprise.

---

## 🚫 5. Explicit Non-Goals

* Starting this slice during Phase 1 or on an empty site.
* Building Keycloak, Saleor, or Directus from **Submodules** / source on the VPS.
* Replacing Caddy or the one-command contract.
* Path-based routing (subdomain-per-service stays).

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md) and **real users on at least two of: Astro Shell, forum, wiki**. Slices 7–10 should already make the host operable (backups especially) before identity data exists.
