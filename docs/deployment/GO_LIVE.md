# Stagea Production Spin-Up

Copy-paste runbook for bringing `stagea-stuff.com` online. **How**, not why.

- **From zero** (have you cloned yet?): [install-guides.md](../install-guides.md) — this runbook is Path A
- **Why / what** (platform, service map, phases, backups): [Production Deployment Plan](./production_plan.md)
- **After go-live** (when to resize, split, or cluster): [Scaling Plan](./scaling_plan.md)
- **Implementation slices**: [Production Go-Live Sprint Cards](./cards/README.md)

Local development is a different target — see [Development Stack Deployment Guide](./README.md#0-local-development-vs-production--read-this-first).

---

## 1. Purpose

After one-time host setup, production is one command. This file is the operator checklist for that path. Do not start Ghost, Saleor, the **Keycloak OIDC IdP**, or the **Directus Parts API** here — those are later phases in the [plan](./production_plan.md).

Assumed artifacts (landed by the implementation pass; do not invent a second layout):

| Path | Role |
| :--- | :--- |
| `infra/compose.yaml` | Whole production stack |
| `infra/Caddyfile` | Edge + TLS |
| `infra/.env.example` | Config inventory (copy to `.env`) |
| `infra/deploy.sh` | Routine deploy (full stack or `--module`) |
| [ci-cd.md](./ci-cd.md) | Path-filtered GHCR publish + per-module SSH |

---

## 2. Prerequisites

- [ ] Domain `stagea-stuff.com` at a registrar / DNS provider you can edit
- [ ] Ubuntu 24.04 LTS VPS: **2 vCPU / 8 GB RAM / 80 GB disk** (any provider)
- [ ] Docker Engine **24+** and Compose **v2** (official apt repo, not distro `docker.io` / `docker-compose` v1)
- [ ] This git repository (clone in §3; no **Submodules** on the host)

---

## 3. Initial setup (ONE TIME)

Tick every box before the first deploy. Details and rationale: [production_plan.md §5](./production_plan.md#5-initial-setup-checklist) and [slice 01 — Host Baseline](./cards/slice_01_host_baseline.md).

### 3.1 DNS

Point at the VPS public IPv4. TTL **300** while iterating. Add matching `AAAA` records if the host has IPv6.

| Record | Name | Required for Phase 1 |
| :--- | :--- | :--- |
| `A` | `stagea-stuff.com` (apex) | Yes |
| `A` | `www` | Yes |
| `A` | `forum` | Yes |
| `A` | `wiki` | Yes |
| `A` | `app` | Optional (permanent redirect to apex when present) |

Do **not** require `blog`, `shop`, `auth`, or `parts` for go-live.

```bash
# Replace with the VPS IPv4. All four must match before first Caddy start.
dig +short stagea-stuff.com
dig +short www.stagea-stuff.com
dig +short forum.stagea-stuff.com
dig +short wiki.stagea-stuff.com
```

### 3.2 Host harden

SSH in as a non-root sudo user (the deploy user).

- [ ] Key-only SSH; disable password login and root SSH
- [ ] UFW: allow `22`, `80`, `443` inbound; default deny incoming; enable
- [ ] Unattended security upgrades on
- [ ] Docker Engine 24+ and Compose v2 from [Docker's official apt repository](https://docs.docker.com/engine/install/ubuntu/); deploy user in the `docker` group
- [ ] `docker compose version` reports **v2**
- [ ] 2 GB swap file (MediaWiki / MariaDB spike margin)
- [ ] Docker log rotation: `/etc/docker/daemon.json` → `json-file`, `max-size: 10m`, `max-file: 3`; restart Docker
- [ ] Demo: `docker run --rm hello-world` exits 0

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

### 3.3 Clone (no Submodules)

```bash
sudo mkdir -p /opt/stagea
sudo chown "$USER:$USER" /opt/stagea
git clone <this-repo-url> /opt/stagea
cd /opt/stagea
```

**Do not** run `git submodule update --init`. Production does not build **Submodules**.

Confirm: `forum/`, `wiki/`, `blog/`, and `shop/` are not populated working trees.

### 3.4 Secrets

```bash
cd /opt/stagea
cp infra/.env.example infra/.env
chmod 600 infra/.env
```

Fill every key in `infra/.env` (inventory is `.env.example` — do not invent a second list). Generate unique values; never reuse across services:

```bash
openssl rand -base64 32
```

Set `ACME_EMAIL` to a real mailbox. Confirm `infra/.env` is gitignored (`git check-ignore -v infra/.env`) before the first deploy. Never commit it.

### 3.5 First TLS

DNS (§3.1) must resolve to this host **before** the first Caddy start. A failed ACME attempt can trip Let's Encrypt rate limits.

Optional: first issuance against the Let's Encrypt **staging** CA (comment in `infra/Caddyfile`), confirm a cert for each hostname, then switch to production and restart Caddy. After a successful issuance, the `caddy_data` volume holds the account key and certificates — do not delete it.

---

## 4. One-command deploy (EVERY TIME)

From the clone:

```bash
cd /opt/stagea && ./infra/deploy.sh
```

Idempotent. A second run against a healthy stack is a no-op.

| Flag | Effect |
| :--- | :--- |
| `--check` | Preflight only (`.env` present / permissions / required keys; Docker + Compose v2). Changes nothing. |
| `--skip-git-pull` | Skip `git pull --ff-only` (pinned rollback, or CI already synced the checkout). Still pulls images and reconciles the target. |
| `--module shell\|forum\|wiki\|caddy` | Deploy that module only (`--no-deps`). A Shell change does not recreate forum or wiki. |
| `--with-db` | With `--module wiki`, bounce `wiki-db` even if it is already healthy. |

Merges to `main` auto-deploy **only** the modules whose dedicated paths changed. That path, the GHCR image, and the GitHub secrets/vars are in **[ci-cd.md](./ci-cd.md)**. `infra/compose.yaml` edits do **not** auto-bounce the full stack.

**Escape hatch** (always sufficient; the wrapper is not load-bearing):

```bash
docker compose -f infra/compose.yaml --env-file infra/.env up -d
```

Expected public URLs after a healthy Phase 1 up:

| URL | What you should see |
| :--- | :--- |
| `https://stagea-stuff.com` | **Astro Shell** / **Shell Edge** |
| `https://forum.stagea-stuff.com` | NodeBB (wizard on first visit, then the forum) |
| `https://wiki.stagea-stuff.com` | MediaWiki (installer on first visit, then the wiki) |
| `https://www.stagea-stuff.com` | Redirect → apex |
| `https://app.stagea-stuff.com` | Redirect → apex (if the `app` record exists) |

---

## 5. First-run wizards (ONE TIME)

After the first successful `up`. Humans only — not part of `deploy.sh`.

### 5.1 NodeBB

1. Open `https://forum.stagea-stuff.com`.
2. Complete the admin setup wizard.
3. Redis host **`forum-redis`** (Compose service name, not `localhost`), port `6379`, password from `FORUM_REDIS_PASSWORD` in `infra/.env`.
4. Public URL: `https://forum.stagea-stuff.com`.
5. Finish so config lands in the `forum_data` volume. Later `up` must skip the wizard.

### 5.2 MediaWiki

1. Open `https://wiki.stagea-stuff.com`.
2. Run the web installer. Database host **`wiki-db`**; name / user / password from `infra/.env`.
3. Download the generated `LocalSettings.php` to the host (e.g. `/tmp/LocalSettings.php`).
4. Persist it into the `wiki_config` volume at `/persist` (the wiki entrypoint copies that file into the docroot on start — do not `cp` onto `/var/www/html/LocalSettings.php` or a restart will lose it):

```bash
cd /opt/stagea
docker compose -f infra/compose.yaml --env-file infra/.env cp /tmp/LocalSettings.php wiki:/persist/LocalSettings.php
docker compose -f infra/compose.yaml --env-file infra/.env restart wiki
```

5. Reload `https://wiki.stagea-stuff.com` — you should get the wiki, not the installer. Do **not** commit `LocalSettings.php`.

---

## 6. Verify

```bash
curl -I https://stagea-stuff.com/healthz
curl -I https://forum.stagea-stuff.com
curl -I https://wiki.stagea-stuff.com
curl -I https://www.stagea-stuff.com
curl -I https://app.stagea-stuff.com   # skip if no app record
```

- [ ] Apex `/healthz` is HTTPS and succeeds (the **Astro Shell** health probe)
- [ ] Forum and wiki return HTTPS (valid cert; not the Caddy or ACME error page)
- [ ] `www` (and `app` if present) redirect to the apex
- [ ] `http://` on those hosts redirects to `https://`

---

## 7. Day-2 notes

**Backups** are [slice 7](./cards/slice_07_backup_loop.md), not this runbook. Nightly encrypted offsite dumps and the restore drill live in [production_plan.md §8](./production_plan.md#8-backup-and-restore-minimum). Do not treat a running stack as backed up until that slice is live.

**Never** `docker compose down -v`. The `-v` flag deletes named volumes (forum posts, wiki revisions, `LocalSettings.php`, TLS material). Use `down` alone, or `stop`.

**Never** build **Submodules** on the host and never `git submodule update --init`. Production runs official images for NodeBB and MediaWiki. Only the **Astro Shell** is built from this repository.

**Ghost, shop, and SSO later.** Do not add Ghost, Saleor, the **Keycloak OIDC IdP**, or the **Directus Parts API** to this host as part of go-live. Phase 2/3 order is in the [plan](./production_plan.md#7-vertical-slices).

**CI/CD.** After go-live, set the deploy secrets/vars in [ci-cd.md](./ci-cd.md) so a Shell merge pulls `ghcr.io/heff0/stagea-shell:<sha>` and restarts only `shell`.

---

## 8. Troubleshooting

| Symptom | Likely cause | What to do |
| :--- | :--- | :--- |
| ACME / certificate failure | DNS not propagated, or Caddy started before the `A` records pointed here | `dig +short` every hostname; wait; then `./infra/deploy.sh` again. Optional: staging CA first (§3.5). |
| Bind error on `80` / `443` | Something else on the host claimed those ports | Only Caddy binds host ports. `sudo ss -lntp \| grep -E ':80\|:443'` and stop the other process. |
| `deploy.sh` refuses to start | `infra/.env` missing, world-readable, or a required key empty | `ls -l infra/.env` must be `600`. Compare keys to `infra/.env.example`. `--check` validates without changing anything. |
| Unhealthy service | App or dependency failed after `up` | `docker compose -f infra/compose.yaml --env-file infra/.env ps` then `docker compose -f infra/compose.yaml logs -f <service>` (`caddy`, `shell`, `forum`, `forum-redis`, `wiki`, `wiki-db`). |

---

## Related

* [From-Zero Install Guides](../install-guides.md) — index if you have not cloned yet (this runbook is Path A)
* [Architecture Map](../architecture.md) — request path and remaining gaps
* [Per-module CI/CD](./ci-cd.md) — path filters, GHCR, SSH secrets, rollback
* [Production Deployment Plan](./production_plan.md) — plan of record
* [Production Go-Live Sprint Cards](./cards/README.md) — slice PRDs
* [Development Stack Deployment Guide](./README.md) — local dev only
* [Platform Master Site-Plan](../site-plan.md) — subdomain map SSOT
* [Documentation Guide](../DOCUMENTATION_GUIDE.md) — glossary and SSOT rule
