# Slice 8 — Image Supply Chain

**Status**: not started — deferred (Phase 2 operability)  
**Phase 1 go-live**: no  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md) (can proceed in parallel with slice 7)

---

## 🎯 1. Overview & Why This Increment

Phase 1 builds the Astro Shell on the VPS. This slice publishes that image to GHCR on default-branch merges and switches Compose from `build:` to a pinned `image:`. Upstream images stay official and pinned. Deploys stop depending on host CPU and become reversible.

---

## 🛠 2. Technical Blueprint (deferred)

| Path | Action (when this slice starts) |
| :--- | :--- |
| `.github/workflows/shell-ci.yml` | **Change** — keep the existing Docker dry-run; add a publish job to GHCR on merge to the default branch, tagged with git SHA and a moving minor tag. |
| `infra/compose.yaml` | **Change** — `shell` uses `image: ghcr.io/<org>/stagea-shell:<pin>` and drops host `build:` (or keeps `build` only as a documented override, default off). |
| `infra/.env.example` | **Change** — `SHELL_IMAGE` (or equivalent) if the tag is env-driven. |
| `infra/deploy.sh` | **Change** — `pull` must fetch the Shell image; no implicit `build` required for a routine deploy. |
| `shell/Dockerfile` | Only if the publish job needs labels/`org.opencontainers.image.source`. |

Pin every remaining `:latest` (there should be none). Confirm NodeBB, MediaWiki, Redis, MariaDB, Caddy tags are explicit minors or digests.

Do not build **Submodules**. Do not start Ghost / Saleor / Keycloak OIDC IdP / Directus Parts API unless a later slice already did.

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: a merge to the default branch produces a new tagged GHCR image; `./infra/deploy.sh` pulls it with no compilation on the host.
2. **Test**: deploy time drops and host CPU stays flat during deploy; rolling back to the previous tag restores the previous Astro Shell release.
3. Escape hatch still works (`up -d` pulls the pinned image).
4. CI still runs `pnpm check` / `pnpm build` / Docker dry-run on PRs; publish is merge-only.

---

## 🚦 4. 6-Step Feature Loop Checklist

- [ ] **1. Scaffold**: GHCR package + workflow job stub (permissions `packages: write`).
- [ ] **2. Document**: `infra/README.md` image name and rollback (`SHELL_IMAGE=…@sha256:…`).
- [ ] **3. MVP Spec**: The four criteria above.
- [ ] **4. Test**: PR does not publish; merge does. Rollback tag test on the VPS.
- [ ] **5. Implement**: Pin Compose `image:`, drop routine host `build:`.
- [ ] **6. Review**: No `:latest`. No Submodule images in GHCR.

---

## 🚫 5. Explicit Non-Goals

* Building NodeBB / MediaWiki / Ghost from source.
* A full Kubernetes registry dance.
* Replacing Caddy.

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md) so `deploy.sh pull` is the path that must keep working. Slice 3's `build:` is the thing this slice removes.
