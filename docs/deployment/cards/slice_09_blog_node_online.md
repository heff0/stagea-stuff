# Slice 9 — Blog Node Online

**Status**: not started — deferred (Phase 2)  
**Phase 1 go-live**: no  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md)

---

## 🎯 1. Overview & Why This Increment

Phase 2 content: official Ghost plus MySQL, `blog.stagea-stuff.com`, owner account, and the Ghost Content API key wired into the Astro Shell so the home page can render blog summaries. **Submodules** (`blog/`) are not built.

Do not start this until Phase 1 (slices 01–06) is green. Saleor, the Keycloak OIDC IdP, and the Directus Parts API stay off.

---

## 🛠 2. Technical Blueprint (deferred)

| Path | Action (when this slice starts) |
| :--- | :--- |
| `infra/compose.yaml` | **Change** — add `blog` (official `ghost`, pinned minor) and `blog-db` (official `mysql`, pinned). Volumes `blog_content`, `blog_db_data`. No host `ports:`. |
| `infra/Caddyfile` | **Change** — `blog.stagea-stuff.com` → `blog:2368`. |
| `infra/.env.example` | **Change** — MySQL passwords; replace placeholder `GHOST_CONTENT_API_KEY`. `BLOG_URL` already exists. |
| `infra/deploy.sh` | **Change** — required keys + health-wait + summary URL for `blog`. |
| DNS | `A`/`AAAA` `blog` → VPS ([§5.1](../production_plan.md#51-dns)). |
| `blog/` | **Do not build**. |

First-run: visit `/ghost/`, create the owner, put the Content API key in `infra/.env`. Email: working **or** explicitly disabled — do not leave a silent broken mailer.

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: `https://blog.stagea-stuff.com` serves Ghost, and the Shell Edge home page renders blog summaries.
2. **Test**: content survives a redeploy; Ghost admin is reachable; email is working or explicitly disabled.
3. MySQL has no host port. Official images only. No `:latest`.
4. `./infra/deploy.sh` brings blog to `healthy` with the rest of the stack.

---

## 🚦 4. 6-Step Feature Loop Checklist

- [ ] **1. Scaffold**: `blog` + `blog-db` service drafts; Caddy site.
- [ ] **2. Document**: `infra/README.md` owner bootstrap ([§5.5](../production_plan.md#55-per-application-bootstrap-one-time-interactive)).
- [ ] **3. MVP Spec**: The four criteria above.
- [ ] **4. Test**: Publish a post → `down` (no `-v`) → `deploy.sh` → post + Shell summary remain.
- [ ] **5. Implement**: Pins, volumes, key in Shell env, email decision.
- [ ] **6. Review**: No Submodule build; Phase 2 content complete.

---

## 🚫 5. Explicit Non-Goals

* Saleor / shop, Keycloak OIDC IdP, Directus Parts API.
* Building Ghost from `blog/`.
* Host-publishing `2368` or MySQL.

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md). Prefer [slice 7](./slice_07_backup_loop.md) already capturing new volumes before the blog has real members — if slice 7 is not done, extend backups in the same PR that adds `blog_content` / `blog_db_data`.
