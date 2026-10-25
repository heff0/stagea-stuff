# Stagea dual-track rollout plan

Numbered steps to bring the **full community website** online securely, on either a **local Proxmox KVM VM** or a **commercial VPS** (provider-agnostic). Complements [GO_LIVE.md](./GO_LIVE.md) (Phase 1 paste-runbook), [BOOT_PLAN.md](./BOOT_PLAN.md) (pre-traffic phases), and [scaling_plan.md](./scaling_plan.md) (after traffic).

| Term | Meaning in this file |
| :--- | :--- |
| **100% online (pre-traffic)** | Apex + forum + wiki + blog over HTTPS; backups restore; then invite users. Shop / Keycloak / Directus are **out** (Phase 3). |
| **Track P** | Fully local Proxmox **KVM** guest (staging / lab). Nested Docker-in-LXC is **forbidden** (stronger than “out of scope” in [scaling_plan.md](./scaling_plan.md)). |
| **Track V** | Any public Linux VPS (provider undecided). Same Compose artifact. |
| **Staging CA** | Let’s Encrypt *staging* ACME endpoint — not the Proxmox staging guest. |
| **Scratch dirs** | `backup.sh` → `/var/tmp/stagea-backup`; `restore.sh` → `/var/tmp/stagea-restore`. Both honour `STAGEA_BACKUP_STAGING` (same override name — set carefully). |

**SSOT pointers (do not duplicate):** service map → [production_plan.md §3](./production_plan.md#3-service-map); capture table → [production_plan.md §8](./production_plan.md#8-backup-and-restore-minimum); operator-blocked slices → [BOOT_PLAN.md §1](./BOOT_PLAN.md#1-remaining-slices--operator-blocked-vs-not).

**Fact-check status:** Reviewed against live `infra/` + deploy docs (2026-08-16). P0/P1 corrections from that review are inlined below.

---

## 1. Security posture this rollout enforces

### 1.1 Host

| Control | Repo | Operator |
| :--- | :--- | :--- |
| Ubuntu 24.04, non-root sudo deploy user, key-only SSH | — | Both tracks |
| Firewall: only intended `22`/`80`/`443` (Track V public; Track P LAN/VPN) | — | Both tracks |
| Docker Engine 24+ + Compose **v2** (official Docker apt, not distro `docker.io`) | `deploy.sh` refuses Compose v1 | Both tracks |
| Deploy user in `docker` group (root-equivalent — keep membership tight) | — | Both tracks |
| 2 GB swap; Docker `daemon.json` log rotation 10m×3 | Compose also sets per-service `x-logging` | Both tracks |
| Clone `/opt/stagea`; **no** `git submodule update --init` | Policy | Both tracks |

### 1.2 Edge / TLS

| Control | Repo | Operator |
| :--- | :--- | :--- |
| Caddy **only** host ports `80`/`443`; no second proxy | `infra/compose.yaml`, `Caddyfile` | — |
| HSTS on apex / forum / wiki | `Caddyfile` | — |
| ACME contact `ACME_EMAIL`; DNS before first Caddy start | Required key in `deploy.sh` | Resolve DNS / private CA (Track P) |
| Optional Let’s Encrypt staging CA first | Commented line in `Caddyfile` | Track V recommended |
| Preserve `caddy_data` (account key + certs) | Backed up by `backup.sh` | Never delete volume |
| Caddy health ≠ certificates issued | Healthcheck hits admin `:2019` | Assert issuer with `curl -vI` |

### 1.3 Secrets

| Control | Repo | Operator |
| :--- | :--- | :--- |
| `infra/.env` gitignored; deploy fails if world-readable or looser than `0640` | `deploy.sh` preflight | `chmod 600`; `git check-ignore -v infra/.env` |
| Password manager copy of `.env` (not only on host) | `.env` excluded from restic | Both tracks |
| `RESTIC_PASSWORD` ≠ object-storage keys; bucket provider ≠ compute provider | Documented | Both tracks |
| Separate Track P vs Track V app secrets | — | **Required** (see P5 / drill exceptions) |

### 1.4 Containers

| Control | Repo | Operator |
| :--- | :--- | :--- |
| No host ports for forum/wiki/redis/mariadb | Compose `expose:` only | — |
| Upstream images pinned to minors (never `:latest`) | Compose pins | — |
| Shell image defaults to mutable `:main` | `SHELL_IMAGE` default | Pin a verified SHA in prod `.env` after V15 |
| Shell runs as `USER node` | `shell/Dockerfile` | — |
| Healthchecks + `deploy.sh` health-wait | Compose + script | `DEPLOY_HEALTH_TIMEOUT=300` on first run |
| Official images only — never build Submodules | Policy | — |

### 1.5 Backups / CI

| Control | Repo | Operator |
| :--- | :--- | :--- |
| restic dumps + volume tars; host systemd timer (no `docker.sock`) | `backup.sh`, `restore.sh`, `infra/systemd/` | Install restic, fill `RESTIC_*`, enable timer, **restore drill** |
| PR CI does not publish/SSH; GHCR publish on `main` | `shell-ci.yml`, `deploy.yml` | Confirm `publish-shell` has run; make package public or `docker login` |
| Deploys from host or CI — not a laptop with dirty tree | Policy | — |

---

## 2. Shared rules (both tracks)

1. Do **not** `git submodule update --init` on either guest.
2. Do **not** `docker compose down -v`.
3. Do **not** start Saleor, Keycloak, or Directus before the pre-traffic bar and real users (slice 11 policy).
4. Do **not** put Track P and Track V on the **same** restic repository with write access — Track P `backup.sh` would `forget --prune` production snapshots.
5. Do **not** run an unmodified production `Caddyfile` on Track P against public ACME for `*.stagea-stuff.com` — it burns Let’s Encrypt rate limits and never validates.
6. First `./infra/deploy.sh`: export `DEPLOY_HEALTH_TIMEOUT=300` (NodeBB first boot often exceeds the 120s default).
7. Resolve **GHCR before** the first full `compose pull` (see V7 / P8). Local-only tags are an **escape hatch**, not a `deploy.sh` path.

---

## 3. Numbered rollout — Track V (VPS, provider-agnostic)

**Goal:** public `*.stagea-stuff.com` at 100% pre-traffic, then open invites.

| Step | Action | Exit check |
| ---: | :--- | :--- |
| **V1** | Provision Ubuntu 24.04 (2 vCPU / 8 GB / 80 GB). Create deploy user; key-only SSH; disable password/root SSH. | SSH as deploy works; root password login fails |
| **V2** | UFW: default deny in; allow `22`/`80`/`443`; enable. Unattended upgrades on. | `ufw status`; external scan agrees |
| **V3** | Install Docker Engine 24+ + Compose v2 from Docker’s apt repo; add deploy to `docker` group; 2 GB swap; `/etc/docker/daemon.json` log rotation; restart Docker. | `docker compose version` → v2; `hello-world` |
| **V4** | `git clone` → `/opt/stagea`. **Skip** submodule init. | Submodule trees not populated |
| **V5** | `cp infra/.env.example infra/.env`; `chmod 600`; fill required keys with unique secrets; password-manager copy. | `git check-ignore -v infra/.env` matches; `./infra/deploy.sh --check` → `preflight ok` |
| **V6** | DNS A/AAAA (TTL 300) for every name Caddy serves: apex, `www`, `forum`, `wiki`, and **`app`** (required while the `app.` block exists in `Caddyfile` — or comment that block out before first Caddy start). Confirm with `dig +short` **before** Caddy. | Dig returns this VPS IP for apex, `www`, `forum`, `wiki`, and `app` (unless block removed) |
| **V7** | GHCR before first pull. Confirm Actions has a green **publish-shell** (or dispatch `module=shell`). Then either (a) make `stagea-shell` public, or (b) `docker login ghcr.io` on the VPS. **Escape hatch only:** (c) `SHELL_IMAGE=stagea-shell:local` and `docker compose -f infra/compose.yaml --env-file infra/.env up -d --build shell` — **`deploy.sh` always pulls and does not build**, so it fails on a local-only tag. | `docker pull ghcr.io/heff0/stagea-shell:main` (or chosen SHA) succeeds, **or** escape-hatch build completed |
| **V8** | Optional: uncomment Let’s Encrypt **staging CA** in `Caddyfile`; `DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh`. Apply Caddyfile edits with `./infra/deploy.sh --skip-git-pull --module caddy` (plain `up -d` will **not** reload a bind-mounted Caddyfile). | `curl -vI https://forum.stagea-stuff.com` shows staging issuer (e.g. (STAGING) Let’s Encrypt). Note: Caddy “healthy” only means admin API is up — not that ACME succeeded |
| **V9** | Comment staging CA; run `./infra/deploy.sh --skip-git-pull --module caddy`. | `curl -vI https://stagea-stuff.com` shows a **public** Let’s Encrypt (or equivalent) chain |
| **V10** | NodeBB wizard: Redis `forum-redis`, password from `.env`, URL `https://forum.stagea-stuff.com`. | Admin login; known test post |
| **V11** | MediaWiki installer: DB `wiki-db`. Download `LocalSettings.php` in the browser → **scp to the VPS** → `compose cp` into `wiki:/persist/LocalSettings.php` → `restart wiki`. Never `cp` onto `/var/www/html/LocalSettings.php` (lost on restart). See [GO_LIVE.md §5.2](./GO_LIVE.md#52-mediawiki) and [infra/README.md](../../infra/README.md). | Known wiki edit persists across restart |
| **V12** | Verify Phase 1: `/healthz`, forum, wiki; `compose config` shows no host ports except Caddy; reboot host once. | All green; **no** public invites yet |
| **V13** | After **G1** is merged: `git pull` on the VPS. `--module blog` exists; V14 is still the first blog boot (DNS + full deploy). | Compose lists blog services; `backup.sh` knows blog volumes |
| **V14** | DNS `blog` → VPS; `DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh`; Ghost owner at `/ghost/`; set `GHOST_CONTENT_API_KEY`; email works **or** explicitly disabled. | `https://blog.stagea-stuff.com` + Shell summaries |
| **V15** | Prove GHCR pull + SHA rollback via `--module shell`. Leave `SHELL_IMAGE` pinned to the verified SHA in `infra/.env` (not floating `:main`). | Forum/wiki not recreated; SHA pin recorded |
| **V16** | Install `restic`. Fill `RESTIC_*` / `AWS_*` (bucket provider **≠** VPS). `./infra/backup.sh --init` then `./infra/backup.sh`. | `./infra/backup.sh --list` shows a snapshot |
| **V17** | `sudo cp infra/systemd/stagea-backup.service infra/systemd/stagea-backup.timer /etc/systemd/system/`; edit if User/`WorkingDirectory`/`EnvironmentFile` are not `deploy` / `/opt/stagea` / `/opt/stagea/infra/.env`; `daemon-reload`; `enable --now stagea-backup.timer`. | `systemctl list-timers` shows next run |
| **V18** | **Restore drill** on Track P (preferred) or a throwaway host — **not** on the live VPS while production Caddy holds 80/443. Requires Track P at P9+ **and** a production snapshot from V16. Follow **P14–P16**. Record wall-clock RTO. **This supersedes** same-host drill wording in [BOOT_PLAN.md](./BOOT_PLAN.md) Phase E, [production_plan.md §8](./production_plan.md#8-backup-and-restore-minimum), and [scaling_plan.md §9](./scaling_plan.md) until **G3** lands. | Known forum post + wiki edit (+ blog post) restored; RTO noted |
| **V19** | Optional: Cloudflare proxy; raise DNS TTL. | — |
| **V20** | Open traffic / invites. Do **not** start Keycloak or Saleor. | Pre-traffic bar met |

---

## 4. Numbered rollout — Track P (Proxmox KVM, fully local)

**Goal:** same Compose stack for staging, restore drills, and warm-standby **rehearsal**. Not a second production. **Promotion** (DNS cutover) is blocked on **G2** plus a documented hostname cutover — do not treat “warm standby” as “run production ACME on the lab box.”

### 4.1 Guest shape

| Item | Value |
| :--- | :--- |
| Hypervisor | Proxmox **KVM** only (Docker-in-LXC forbidden) |
| Guest OS / Docker | Same as Track V |
| Resources | Prefer **4 vCPU / 16 GB / 120 GB** if resident stack **and** drills; **2 / 8 / 80** only if restore-only |
| Disk | Virtio-SCSI; headroom for restic cache + `/var/tmp/stagea-restore` |
| Network | Bridge + outbound internet; inbound `22`/`80`/`443` from LAN/VPN only |
| Agent | `qemu-guest-agent` enabled |

### 4.2 Steps

| Step | Action | Exit check |
| ---: | :--- | :--- |
| **P1** | Create KVM guest per §4.1; Ubuntu; deploy user; key-only SSH. | SSH works |
| **P2** | Guest firewall: `22`/`80`/`443` from trusted LAN/VPN only. | Untrusted sources blocked |
| **P3** | Docker + Compose v2 + swap + log rotation (same as V3). | `hello-world` ok |
| **P4** | Clone `/opt/stagea`; no submodule init. | Same as V4 |
| **P5** | Separate Track P `infra/.env`. New Redis password. Public URLs use **non-preloaded** lab names (prefer `*.stagea.lan`, `*.stagea.internal`, or a real `lab.stagea-stuff.com` subdomain you control — **avoid `*.stagea-stuff.dev`**: `.dev` is HSTS-preloaded and breaks `tls internal` without a trusted lab CA). Leave `RESTIC_*` **commented out** until P13 (so drill env can be swapped). For a **resident** Track P stack, generate new `WIKI_DB_*`. For a **production restore drill**, see P14 (DB creds must match production `LocalSettings.php`). | `--check` ok |
| **P6** | **Hostname / TLS (pick one):** (a) private DNS or `/etc/hosts` + Caddy `tls internal` with lab CA in browser/OS trust stores; or (b) real DNS you control + HTTP-01 if publicly reachable. Never ACME production `*.stagea-stuff.com` from the lab. | HTTPS works for chosen names |
| **P7** | Until **G2**: either `git update-index --skip-worktree infra/Caddyfile` and edit hostnames locally, **or** a Track-P-only compose file that bind-mounts a different Caddyfile. Sibling `compose.override.yaml` is **not** merged when scripts pass `-f infra/compose.yaml`. | Caddy serves Track P names only |
| **P8** | Same as V7 (prefer GHCR pull). | Image present |
| **P9** | `DEPLOY_HEALTH_TIMEOUT=300 ./infra/deploy.sh --skip-git-pull` (avoids `git pull --ff-only` fighting a skip-worktree Caddyfile). | Healthy; ignore `.com` URLs in summary until G2 |
| **P10** | NodeBB + MediaWiki wizards using **Track P URLs**. | Known post + edit on Track P names |
| **P11** | After **G1**: blog on Track P with a separate Ghost key. | Blog green on Track P |
| **P12** | Optional Proxmox guest snapshot before risky upgrades (does **not** replace restic). | Snapshot listed |
| **P13** | Optional Track P–only restic (separate bucket/prefix; credentials must **not** write to production). Fill `RESTIC_*` in Track P `.env` **only** for this path. **Before a production restore drill, comment `RESTIC_*` back out** (or swap in `infra/.env.drill`) — `restore.sh` does `set -a; source infra/.env`, which **overwrites** exported env and would silently restore from the wrong repo. | Staging snapshots only, if used |
| **P14** | **Production restore drill (preferred host for V18).** Use a **copied** snapshot set in a separate restic repo, **or** temporary `infra/.env.drill` with production `RESTIC_*` / `AWS_*` (and production `WIKI_DB_NAME` / `WIKI_DB_USER` / `WIKI_DB_PASSWORD` — MediaWiki has no env override for DB creds; restored `wiki_config` carries them). Do **not** claim “read-only” object storage: `restic restore` takes a repo lock unless you add `--no-lock` (not wired in `restore.sh` today). Do **not** run production `backup.sh` here. | Credentials point at the intended prod snapshot set |
| **P15** | `STAGEA_RESTORE_PROJECT=stagea-restore ./infra/restore.sh <prod-snapshot-id>`. The script **ends by starting the whole stack**, including Caddy with restored **production** ACME material on 80/443. Immediately: `docker compose -p stagea-restore -f infra/compose.yaml --env-file infra/.env stop caddy` then `docker volume rm stagea-restore_caddy_data`. Verify via `compose exec` / port-forward. NodeBB usually follows Compose `url`/`redis__*` env; MediaWiki needs matching DB creds (P14). Rehost `$wgServer` / NodeBB URL before browsing under lab names. **G3** (skip-up / port override) is the real fix. | Known production forum post + wiki edit visible; wall-clock recorded |
| **P16** | `rm -rf /var/tmp/stagea-restore` (and any drill `.env` copies). Confirm no production `caddy_data` left for ACME. | Scratch gone |
| **P17** | Warm-standby **rehearsal** only until **G2**: practice restore within RPO 24h. Promotion = DNS cutover after hostnames/TLS are parameterized — **not** “Proxmox HA instead of restic.” | RTO from last drill known |

---

## 5. Repo gates before “100%”

| Gate | What to land | Why |
| :--- | :--- | :--- |
| **G1 — Slice 9 Blog** | Ghost + MySQL in Compose; Caddy `blog.`; `.env.example` MySQL keys; `deploy.sh` `SERVICES` / health-wait / summary URL; **backup.sh** mysqldump + volumes in the **same** PR | Without this, bar cannot include blog |
| **G2 — Hostname parameterization** | Env-substituted Caddy hosts + deploy summary URLs | Clean Track P / promotion without skip-worktree |
| **G3 — Restore-drill override** | `--skip-up` and/or drop Caddy ports for `stagea-restore` | Safe same-host drills; no prod ACME on lab |
| **G4 — Cookie `Secure` in production** | Fix mock/session cookie (`secure: false` today) | [security.md](../shell/security.md) |
| **G5 — Sanitize `set:html` search** | Server-side sanitizer | [security.md](../shell/security.md) §4 |

G4–G5: **pre-traffic preferred**.

---

## 6. Parallelism cheat sheet

```
Repo:     G1 (+ ideally G2–G5) before V13 / invites
Track V:  V1–V7 → V8–V12 → V13–V15 → V16–V17 → V18 (on Track P) → V19 → V20
Track P:  P1–P12 → (optional P13, then unset RESTIC_*) → P14–P16 as V18 drill → P17 rehearsal
```

---

## 7. Known gaps this plan absorbs

| Issue | Handling |
| :--- | :--- |
| First deploy vs private GHCR | **V7 / P8 before** first `deploy.sh`; local tag = escape hatch only |
| 120s health timeout | `DEPLOY_HEALTH_TIMEOUT=300` on first boot |
| Restore vs live 80/443 | Drill on Track P; **G3** for same-host later; supersedes older same-host wording until G3 |
| `LocalSettings.php` on laptop | **V11** scp |
| Shared restic = pruned prod | Separate repos; never write-prune prod from Track P |
| `restore.sh` sources `.env` over exports | P13/P14 credential swap / `.env.drill` |
| Restored wiki DB auth | P14: reuse production `WIKI_DB_*` for the drill |
| Restored prod TLS keys on lab | P15 stop Caddy + `volume rm` caddy_data |
| Slice 9 not in Compose | **G1** before V13 |
| Caddy “healthy” ≠ certs | V8/V9 `curl -vI` issuer checks |
| `shell_deployment.md` nginx | Later hardening only; day-1 edge is Caddy |
| Observability (slice 10) | After V20 |
| Saleor / Keycloak | Out until real users |

---

## 8. Definition of done

- [ ] Track V: **V1–V18** complete, with **V18** executed on Track P or a throwaway host.
- [ ] **G1** merged; blog live on Track V.
- [ ] Restore drill wall-clock recorded (target &lt; 2 h); RPO 24 h accepted.
- [ ] Firewall/port scan: only intended ports open.
- [ ] No Submodule builds; no `down -v`; production restic passphrase ≠ storage keys.
- [ ] Invites / marketing only after the above.

---

## 🔗 Related

* [GO_LIVE.md](./GO_LIVE.md) — Phase 1 operator paste  
* [BOOT_PLAN.md](./BOOT_PLAN.md) — lettered pre-traffic phases  
* [production_plan.md](./production_plan.md) — platform SSOT  
* [scaling_plan.md](./scaling_plan.md) — Proxmox KVM staging, post-traffic math  
* [ci-cd.md](./ci-cd.md) — GHCR + optional SSH deploy  
* [cards/README.md](./cards/README.md) — slice status / operator-blocked  
* [shell/security.md](../shell/security.md) — app-layer security requirements  
