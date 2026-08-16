# Slice 8 — Image Supply Chain

**Status**: implemented in repo  
**Phase 1 go-live**: no (operability; first host deploy can still `build:` the Shell)  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md)

Canonical CI write-up: [ci-cd.md](../ci-cd.md). This card is the slice checklist; do not duplicate the path→module table.

---

## 🎯 1. Overview & Why This Increment

Phase 1 can build the Astro Shell on the VPS. This slice publishes that image to GHCR on `main` and makes Compose pull `SHELL_IMAGE`. Deploys stop depending on host CPU and become reversible. Required by the [Scaling Plan](../scaling_plan.md) day-1 contract (S3 consumes images, not Compose YAML).

---

## 🛠 2. What landed

| Path | Action |
| :--- | :--- |
| `.github/workflows/deploy.yml` | On `shell/**` (or dispatch `module=all`): push `ghcr.io/heff0/stagea-shell:<git sha>` and `:main`. Then optional SSH `--module shell`. |
| `.github/workflows/shell-ci.yml` | PRs: `pnpm check` / `pnpm build` / `docker build` dry-run. No publish. |
| `infra/compose.yaml` | `image: ${SHELL_IMAGE:-ghcr.io/heff0/stagea-shell:main}`. `build:` remains host fallback. |
| `infra/.env.example` | `SHELL_IMAGE`. |
| `infra/deploy.sh` | `--module shell` pulls/up only `shell`. |
| `shell/Dockerfile` | OCI source label. |

No `:latest`. No Submodule images in GHCR. Ghost / Saleor / Keycloak / Directus still absent.

Rollback (forum/wiki stay up):

```bash
SHELL_IMAGE=ghcr.io/heff0/stagea-shell:<previous-sha> \
  ./infra/deploy.sh --skip-git-pull --module shell
```

First GHCR package is often private. Make `stagea-shell` **public** (GitHub → Packages) or `docker login ghcr.io` on the VPS — host config, not a git file. See [ci-cd.md §4](../ci-cd.md#4-secrets-and-variables-the-operator-must-set).

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: a merge to `main` that touches `shell/**` produces a new GHCR tag; `--module shell` pulls it with no compilation on the host.
2. **Test**: rolling back `SHELL_IMAGE` to the previous SHA restores the previous Astro Shell; forum and wiki containers are not recreated.
3. Escape hatch still works (`up -d` uses `SHELL_IMAGE`).
4. PRs do not publish; `deploy.yml` publish is merge (or dispatch) only.

---

## 🚦 4. 6-Step Feature Loop Checklist

- [x] **1. Scaffold**: GHCR package + `deploy.yml` `packages: write`.
- [x] **2. Document**: [ci-cd.md](../ci-cd.md), `infra/README.md` rollback.
- [x] **3. MVP Spec**: The four criteria above.
- [ ] **4. Test**: Confirm a real merge publishes and a SHA rollback on the VPS. (Needs `main` + a pullable package.)
- [x] **5. Implement**: Compose `image:` + `--module shell`.
- [x] **6. Review**: Moving tag is `:main` plus immutable git SHA. No Submodule images in GHCR.

---

## 🚫 5. Explicit Non-Goals

* Building NodeBB / MediaWiki / Ghost from source.
* A full Kubernetes registry dance.
* Replacing Caddy.

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md) so `deploy.sh pull` is the path that must keep working.
