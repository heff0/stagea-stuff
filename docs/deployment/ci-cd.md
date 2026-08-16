# Per-module CI/CD

How merges to `main` publish the Astro Shell image and deploy **only** the modules that changed. A Shell change must not restart forum or wiki.

Operator spin-up (DNS, first `./infra/deploy.sh`, wizards) stays in [GO_LIVE.md](./GO_LIVE.md). This file is the CI path.

---

## 1. Workflows

| File | When | What it does |
| :--- | :--- | :--- |
| [`.github/workflows/shell-ci.yml`](../../.github/workflows/shell-ci.yml) | PRs (and path-filtered pushes) that touch `shell/**` | `pnpm check`, `pnpm build`, Docker dry-run. No publish, no SSH. |
| [`.github/workflows/deploy.yml`](../../.github/workflows/deploy.yml) | Push to `main`, or **Actions → Per-module deploy** | Path filter → optional GHCR publish → optional per-module SSH. |

Docs-only commits on `main` run the `changes` job, match no module, and deploy nothing.

---

## 2. Path → module map

Automatic deploy on push to `main` uses **dedicated paths only**. `infra/compose.yaml` is never an automatic full-stack bounce.

| Paths that changed | Module job | Remote command |
| :--- | :--- | :--- |
| `shell/**` (includes `shell/Dockerfile`) | `publish-shell` then `deploy-shell` | `SHELL_IMAGE=ghcr.io/heff0/stagea-shell:<sha> ./infra/deploy.sh --skip-git-pull --module shell` |
| `infra/Caddyfile`, `infra/caddy/**` | `deploy-caddy` | `./infra/deploy.sh --skip-git-pull --module caddy` |
| `infra/wiki/**` | `deploy-wiki` | `./infra/deploy.sh --skip-git-pull --module wiki` |
| *(no dedicated forum path)* | — | Forum is **workflow_dispatch** `module=forum` only |
| `infra/compose.yaml` | `compose-changed` (notice) | Not deployed. Run `./infra/deploy.sh --skip-git-pull` on the host, or dispatch `module=all` / a single module |
| `infra/deploy.sh` only | notice | Script is not a service; next module deploy picks it up after `git merge` |
| `docs/**` and everything else | — | No deploy |

`workflow_dispatch` inputs: `shell` | `forum` | `wiki` | `caddy` | `all`.

`module=all` publishes `stagea-shell` (SHA + `main` tags) and runs a full `./infra/deploy.sh --skip-git-pull` on the VPS. That is the only CI path that reconciles the whole stack.

### compose.yaml strategy

Compose cannot be split into per-service files without a larger refactor. A change to `networks:` or `x-logging` is global and **may** require a full host deploy:

```bash
cd /opt/stagea && git pull --ff-only && ./infra/deploy.sh --skip-git-pull
```

Service-only compose edits (forum image pin, wiki env, …) should be applied with `workflow_dispatch` `module=forum|wiki|shell|caddy` so `--no-deps` keeps the other containers up.

---

## 3. What a Shell deploy does (and does not)

1. Build `shell/Dockerfile` and push:
   - `ghcr.io/heff0/stagea-shell:<git sha>`
   - `ghcr.io/heff0/stagea-shell:main`
2. If deploy is enabled, SSH to the VPS, fast-forward the checkout to `origin/main`, then:
   - `compose pull` **shell only**
   - `compose up -d --no-deps --remove-orphans shell`
   - health-wait **shell only**
3. Forum, wiki, wiki-db, forum-redis, and Caddy are not in the `up` service list. They keep their running containers.

`--no-deps` is load-bearing: Caddy `depends_on: shell`, but a Shell image roll must not recreate Caddy.

---

## 4. Secrets and variables the operator must set

GitHub repo **Settings → Secrets and variables → Actions**.

### Secrets (required for SSH)

| Name | Purpose |
| :--- | :--- |
| `DEPLOY_SSH_KEY` | Private key for the VPS deploy user (never commit this) |
| `DEPLOY_HOST` | VPS hostname or IPv4 |
| `DEPLOY_USER` | SSH user (must be in the `docker` group; see [slice 01](./cards/slice_01_host_baseline.md)) |

`GITHUB_TOKEN` is enough to push `ghcr.io/heff0/stagea-shell` from this repository. Do not add a PAT for publish.

### Variables

| Name | Required | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `DEPLOY_ENABLED` | **Yes, to SSH** | *(unset)* | Must be the string `true` or CI will not SSH |
| `DEPLOY_PATH` | No | `/opt/stagea` | Clone path on the VPS |

### If deploy is not enabled

CI **succeeds**. `publish-shell` still runs when Shell changed. Each `deploy-*` job prints that SSH was skipped and exits 0.

Typical first week: leave `DEPLOY_ENABLED` unset, confirm GHCR images appear, then set the three secrets + `DEPLOY_ENABLED=true`.

### GHCR pull on the VPS

Make the `stagea-shell` package **public** (GitHub → Packages) so the host can `docker pull` without a token. If the package stays private, `docker login ghcr.io` on the VPS with a read token — that token is host config, not a git file.

---

## 5. Rollback

Images are immutable by SHA. Restore the previous Astro Shell without touching forum or wiki:

```bash
cd /opt/stagea
# list recent tags in GHCR, or use the SHA from the last good Actions run
SHELL_IMAGE=ghcr.io/heff0/stagea-shell:<previous-sha> \
  ./infra/deploy.sh --skip-git-pull --module shell
```

Caddyfile rollback: `git checkout` the previous Caddyfile (or `git merge --ff-only` after revert) then `./infra/deploy.sh --skip-git-pull --module caddy`.

---

## 6. Host flags (same script CI calls)

```bash
./infra/deploy.sh                     # full stack (existing)
./infra/deploy.sh --check             # preflight only
./infra/deploy.sh --skip-git-pull     # CI already synced the checkout
./infra/deploy.sh --module shell
./infra/deploy.sh --module forum      # forum-redis, then forum
./infra/deploy.sh --module wiki       # wiki; wiki-db only if not healthy
./infra/deploy.sh --module wiki --with-db
./infra/deploy.sh --module caddy      # reload, or recreate caddy only
```

`--module` still preflights `infra/.env` and Docker. Interactive use still `git pull --ff-only` unless `--skip-git-pull`. CI always passes `--skip-git-pull` after `git merge --ff-only origin/main`.

The script never runs `docker compose down` or `down -v`.

---

## 7. What is not in this pipeline

* Building **Submodules** (`forum/`, `wiki/`, `blog/`, `shop/`).
* Starting Ghost, Saleor, the **Keycloak OIDC IdP**, or the **Directus Parts API**.
* Auto full-stack `./infra/deploy.sh` on every push to `main`.

---

## Related

* [Scaling Plan](./scaling_plan.md) — RAM/disk inequalities, 1,000+ users, when k3s is actually the next spend
* [`infra/README.md`](../../infra/README.md) — Compose pins, one-command contract, `--module` flags
* [Production Spin-Up Runbook](./GO_LIVE.md) — first host setup
* [Slice 8 — Image Supply Chain](./cards/slice_08_image_supply_chain.md) — GHCR subset implemented here
