# Pre-traffic boot plan

Ordered path from an empty VPS to a **full public community site** with backups proven, **before** inviting users. Complements [GO_LIVE.md](./GO_LIVE.md) (Phase 1 copy-paste) and the [slice cards](./cards/README.md). For numbered dual-track steps (Proxmox KVM + provider-agnostic VPS) and the security control matrix, use **[ROLLOUT_PLAN.md](./ROLLOUT_PLAN.md)** (it supersedes same-host restore-drill wording here until gate G3 lands).

**Goal:** apex + forum + wiki + blog are live over HTTPS, backups restore, then open traffic. Shop / Keycloak / Directus are **not** required for that bar (Phase 3; see §6).

---

## 0. Submodules on the VPS — read this first

Production does **not** build or run `forum/`, `wiki/`, `blog/`, or `shop/` from Submodule trees.

| On the VPS | Do |
| :--- | :--- |
| Git clone of this monorepo | Yes — `/opt/stagea` |
| `git submodule update --init` | **No** — wastes disk and invites building upstream from source |
| Official images in `infra/compose.yaml` | Yes — NodeBB, MediaWiki, Ghost (when slice 9 lands), etc. |
| Submodule working trees populated | Optional for debugging only; never bind-mount them into production Compose |

If someone said “submodules are on the VPS,” treat that as: **the monorepo is cloned and Phase 1 Compose can pull images.** Skip submodule init.

---

## 1. Remaining slices — operator-blocked vs not

| Slice | Name | Operator-blocked? | Why |
| ---: | :--- | :--- | :--- |
| 1 | Host Baseline | **Yes** | SSH harden, UFW, Docker install, swap, log rotation — human on the VPS |
| 2–6 | Edge → one-command | No (repo done) | Operator still runs DNS + first `./infra/deploy.sh` + NodeBB/MediaWiki wizards |
| 7 | Backup Loop | **Yes** (scripts done) | Fill `RESTIC_*` / `AWS_*`, `restic` on host, `--init`, enable timer, **restore drill** |
| 8 | Image Supply Chain | **Yes** (partial) | Make GHCR package public (or `docker login`); prove pull + SHA rollback. Repo/CI already publish |
| 9 | Blog Node Online | **No — repo blocked first** | Compose/Caddy/env/deploy.sh not implemented yet. Then operator: DNS `blog`, Ghost owner wizard, Content API key |
| 10 | Observability | **Mixed** | Repo: healthchecks exist; missing uptime probe + disk alert wiring. Operator: pick monitor + alert destination |
| 11 | Identity + Commerce | **Blocked by policy + repo** | Do not start until ≥2 Phase 1 services have real users. Saleor roughly doubles RAM — not part of pre-traffic community bar |

**Operator-blocked** = cannot finish without a human on DNS, VPS, GHCR, object storage, or an interactive installer.  
**Repo-blocked** = code/docs in this monorepo must land before the operator can finish.

---

## 2. Definition: “100% of the website” (pre-traffic)

| Surface | Host | Pre-traffic? |
| :--- | :--- | :--- |
| Shell Edge | `stagea-stuff.com` | Required |
| Forum | `forum.stagea-stuff.com` | Required |
| Wiki | `wiki.stagea-stuff.com` | Required |
| Blog | `blog.stagea-stuff.com` | Required for “full community site” |
| Shop | `shop.stagea-stuff.com` | **Out** of this boot (Phase 3 / Saleor) |
| Auth | `auth.stagea-stuff.com` | **Out** (Keycloak after real users) |
| Parts | `parts.stagea-stuff.com` | **Out** |

Pre-traffic bar = Phase 1 + Phase 2 (blog) + backup restore drill green. Then invite users.

---

## 3. Boot sequence (once the repo is on the VPS)

Do not open public marketing or forum invites until **Phase E** is checked.

### Phase A — Initial host setup (operator)

Checklist: [GO_LIVE.md §3](./GO_LIVE.md#3-initial-setup-one-time) / [slice 01](./cards/slice_01_host_baseline.md).

1. Provision Ubuntu 24.04 (2 vCPU / 8 GB / 80 GB). Harden SSH; UFW `22`/`80`/`443` only.
2. Install Docker Engine 24+ and Compose v2; deploy user in `docker` group; 2 GB swap; Docker log rotation.
3. `git clone` → `/opt/stagea`. **Do not** `git submodule update --init`.
4. Copy `infra/.env.example` → `infra/.env`; `chmod 600`; fill secrets (`openssl rand -base64 32`).
5. DNS A/AAAA (TTL 300): apex, `www`, `forum`, `wiki`, `app` (optional redirect). Hold `blog` until Phase C.

**Exit:** `docker run --rm hello-world` ok; dig shows VPS IPs for Phase 1 hosts.

### Phase B — Phase 1 stack + interactive bootstrap (operator)

1. Optional first Caddy run against Let’s Encrypt **staging** CA, then switch to production ([GO_LIVE.md](./GO_LIVE.md)).
2. `./infra/deploy.sh` (or escape hatch `docker compose -f infra/compose.yaml --env-file infra/.env up -d`).
3. NodeBB wizard: Redis host `forum-redis`, password from `.env`, URL `https://forum.stagea-stuff.com`.
4. MediaWiki installer: DB host `wiki-db`; persist `LocalSettings.php` into `wiki_config` ([infra/README.md](../../infra/README.md)).
5. Verify: apex `/healthz`, forum post, wiki edit; `deploy.sh` healthy summary.

**Exit:** Phase 1 content-complete. Still **no** public traffic push.

### Phase C — Blog (repo then operator)

**Repo (before or on the VPS clone that includes the PR):** land [slice 09](./cards/slice_09_blog_node_online.md) — Ghost + MySQL in Compose, Caddy route, deploy.sh health keys, pin tags. Extend [backup.sh](../../infra/backup.sh) for `blog_content` / `blog_db_data` + `mysqldump` in the same change.

**Operator:**

1. DNS `blog` → VPS; wait for propagation.
2. `./infra/deploy.sh` (or `--module` once blog is modularized).
3. Visit `https://blog.stagea-stuff.com/ghost/`; create owner; put Content API key in `infra/.env` as `GHOST_CONTENT_API_KEY`.
4. Confirm Shell home shows blog summaries; email working **or** explicitly disabled.

**Exit:** apex + forum + wiki + blog all green.

### Phase D — Image pull hygiene (operator, can parallelize with C)

1. GitHub → Packages: make `stagea-shell` **public** (or `docker login ghcr.io` on the VPS).
2. Deploy once with `SHELL_IMAGE=ghcr.io/heff0/stagea-shell:<sha>` (CI or manual).
3. Rollback test: previous SHA via `./infra/deploy.sh --skip-git-pull --module shell`.

**Exit:** host does not need to compile the Shell for routine deploys.

### Phase E — Backups before traffic (operator)

Scripts are in-repo ([slice 07](./cards/slice_07_backup_loop.md)). Order matters: **backup after** blog volumes exist so the first “real” snapshot includes Ghost.

1. Install `restic` on the host.
2. Fill `RESTIC_REPOSITORY`, `RESTIC_PASSWORD`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` in `infra/.env`. Bucket provider **≠** VPS provider. Passphrase **≠** storage keys.
3. `./infra/backup.sh --init` then `./infra/backup.sh`. Confirm `./infra/backup.sh --list`.
4. Enable timer: copy `infra/systemd/stagea-backup.*` → `/etc/systemd/system/`; `daemon-reload`; `enable --now stagea-backup.timer`.
5. **Restore drill:** `./infra/restore.sh <snapshot-id>` into `stagea-restore`. Confirm a known forum post, wiki edit, and (after Phase C) a blog post. Record wall-clock — that is measured RTO (target &lt; 2 h). Tear down with `compose -p stagea-restore down` (**never** `-v` on production).

**Exit:** last restore drill green. Only then open traffic.

### Phase F — Open traffic

1. Raise DNS TTL if desired; Cloudflare proxy optional ([scaling_plan.md](./scaling_plan.md)).
2. Invite users / announce. Do **not** start Keycloak or Saleor on this box yet ([slice 11](./cards/slice_11_identity_and_commerce.md)).
3. Keep nightly timer on; quarterly restore drill.

---

## 4. What to do if blog is not in Compose yet

You can still run Phases A–B and E on Phase 1 volumes, then re-run backup after slice 9 lands. Prefer: **implement slice 9 → deploy blog → backup → traffic**, so the first public snapshot includes the blog.

Do not invite traffic on Phase 1 alone if the product promise includes a blog — finish Phase C first.

---

## 5. Explicit non-goals for this boot

* `git submodule update --init` on production.
* Building NodeBB / MediaWiki / Ghost from Submodule source.
* Saleor, Keycloak, or Directus on the community VPS before real users.
* `docker compose down -v`.
* Skipping the restore drill (“we have restic” is not a backup).

---

## 🔗 Related

* [GO_LIVE.md](./GO_LIVE.md) — Phase 1 operator checklist  
* [production_plan.md](./production_plan.md) — service map, slices, backup floor  
* [scaling_plan.md](./scaling_plan.md) — when to resize after traffic  
* [cards/README.md](./cards/README.md) — slice status + operator-blocked column  
* [infra/README.md](../../infra/README.md) — backup/restore commands  
