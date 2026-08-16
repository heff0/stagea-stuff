# Stagea Platform: Scaling Plan

How the Phase 1 Compose stack grows after go-live: which inequality fires, what to change, and what 1,000+ users actually cost in RAM and disk.

**Scope**: capacity and reliability after `./infra/deploy.sh` is healthy. Not local development. Not a provider comparison — pick any VPS that meets the RAM/disk inequalities below.

**SSOT**: this file is the scaling decision record. Host setup, service map, and the one-command contract stay in [`production_plan.md`](./production_plan.md). Operator copy-paste stays in [`GO_LIVE.md`](./GO_LIVE.md).

**Runtime**: stay on Docker Compose + Caddy through S2. The cluster destination is **k3s**, not Swarm / Dokploy / Quadlets. See §7.

---

## 1. Two problems, two bills

| Problem | Question | Cheap answer | Expensive wrong answer |
| :--- | :--- | :--- | :--- |
| **Capacity** | Can this hardware serve the load? | CDN, object storage, one vertical resize, then split state | Three-node cluster because “we have users” |
| **Reliability** | Can we recover when the box dies? | Nightly restic + a restore drill onto the Proxmox staging VM | Live replicas of MariaDB |

Do not spend on a cluster to solve restore time. Do not resize the VPS because the registered-user counter went up.

---

## 2. Idle RAM budget (the real cost of features)

Resident set at idle-to-light traffic. These numbers are the **inputs** to every later inequality. They are not a profiler dump from production; they are the planning model. Re-measure with `docker stats` once the stack has real traffic and replace the table if the error is >20%.

| Process | Idle RAM (GB) | Why it exists |
| :--- | ---: | :--- |
| OS + container engine | 1.0 | Host floor |
| Caddy | 0.1 | Edge, TLS |
| Astro Shell | 0.2 | Stateless SSR |
| NodeBB | 0.4 | Forum |
| Redis | 0.1 | Forum datastore |
| MediaWiki | 0.4 | Wiki PHP |
| MariaDB | 0.6 | Wiki datastore |
| **Phase 1 total** | **2.8** | Apex + forum + wiki |
| Ghost + MySQL | +0.9 | Slice 9 |
| **Phase 2 total** | **3.7** | + blog |
| Keycloak | +1.5 | Slice 11, Java |
| Directus | +0.4 | Slice 11 |
| Saleor platform | +5.0 | Slice 11; order of magnitude, not a rounding error |
| **Phase 3 all-on-one-box** | **~10.6** | Do not do this |

Headroom rule: treat **70% of RAM** as the usable ceiling, so a resize fires before the OOM killer.

\[
R_{\text{usable}} = 0.7 \times R_{\text{total}}
\]

A stack fits a box iff \(M_{\text{idle}} < R_{\text{usable}}\).

| Stack | \(M_{\text{idle}}\) (GB) | Fits 8 GB? (\(R_{\text{usable}}=5.6\)) | Fits 16 GB? (\(R_{\text{usable}}=11.2\)) |
| :--- | ---: | :--- | :--- |
| Phase 1 | 2.8 | Yes (headroom 2.8 GB) | Yes |
| Phase 2 (Ghost) | 3.7 | Yes (headroom 1.9 GB) | Yes |
| Phase 2 + Keycloak | 5.2 | Barely (0.4 GB) — **do not add** | Yes |
| + Directus | 5.6 | At the ceiling | Yes |
| + Saleor | 10.6 | No | Barely — **split, do not share** |

**Feature-growth rule:** Ghost can join the community box. Keycloak is the last thing that might. Saleor never shares the community box. That is already slice 11; this table is why.

---

## 3. Users are not RAM

Registered accounts (\(N\)) do not appear in the RAM equation until they become **concurrent requests**. For a niche community forum:

\[
C = N \times \alpha \times \pi
\]

| Symbol | Meaning | Planning value | Busy value |
| :--- | :--- | ---: | ---: |
| \(N\) | Registered accounts | — | — |
| \(\alpha\) | Active-in-30-days / registered | 0.15 | 0.30 |
| \(\pi\) | Peak concurrent / active-in-30-days | 0.05 | 0.10 |
| \(C\) | Peak concurrent sessions | \(0.0075\,N\) | \(0.03\,N\) |

Worked values:

| \(N\) | \(C\) planning | \(C\) busy | What it means for this stack |
| ---: | ---: | ---: | :--- |
| 1,000 | 8 | 30 | Noise vs the 2.8 GB idle floor. Stay on Phase 1 hardware. |
| 10,000 | 75 | 300 | Still one box. Watch MariaDB slow queries and disk, not RAM. |
| 100,000 | 750 | 3,000 | Stateless Shell replicas become useful. Databases stay single-primary. This is S2/S3, not “buy 32 GB.” |

Per-session RAM is small next to idle (a few MB). **Do not trigger a resize from \(N\).** Trigger from the inequalities in §4.

Disk *does* track users, but through uploads, not accounts:

\[
D_{\text{uploads}} \approx N \times u \times s
\]

Example: \(N=1000\), \(u=0.10\) of users ever upload, \(s=5\,\text{MB}\) average → **500 MB**. The 80 GB disk dies from images and backups, not from 1,000 profile rows.

---

## 4. Decision matrix (first match wins)

Evaluate in this order. Stop at the first true row. Symbols are 7-day p95 unless noted.

| # | Inequality | Meaning | Action | Explicitly not |
| ---: | :--- | :--- | :--- | :--- |
| 1 | Feature ∈ {Keycloak, Saleor} landing on the community box | Slice 11 RAM | **S2 split** — own guest (or Saleor Cloud). See §2. | Upsize the community VPS to 32 GB |
| 2 | \(D_{\text{used}} / D_{\text{total}} > 0.7\) | Disk | Point wiki images + forum uploads at `OBJECT_STORAGE_*`. Same provider **must differ** from the VPS (backup rule). | Bigger disk as the first move |
| 3 | \(M_{\text{used}} / R_{\text{total}} > 0.7\) and \(R_{\text{total}} < 16\,\text{GB}\) | RAM | **S1** — resize in place to 16 GB. Same Compose file. | Second VPS, k3s |
| 4 | CPU steal or load/\(n_{\text{cpu}} > 1.5\) for 7 days | CPU | More vCPU on the same guest (or a dedicated-CPU SKU). | Cluster |
| 5 | p95 page time up while (3) and (4) are false | App | Cache GET on wiki/blog at the CDN; fix MariaDB slow queries. | Replica the databases |
| 6 | Required RTO \(<\) last restore-drill wall-clock | Reliability | Warm standby: restore onto the Proxmox staging VM (or a parked second guest). | Confuse HA with capacity |
| 7 | (3) still true at 16 GB **and** object storage is on | RAM after S1+S2 disk | **S2** — MariaDB/MySQL (and later Keycloak DB) on a data guest. App box stays disposable. | Galera / Redis Cluster |
| 8 | Need ≥2 Shell replicas **and** (6) is true | Horizontal + HA | **S3** — k3s. Databases stay off-cluster. | Swarm, Dokploy, Compose `--scale` on one disk |

If nothing matches: do nothing. That is the correct 1,000-user state.

---

## 5. Plan through 1,000 users and past it

Assume Phase 1 is live (apex + forum + wiki). \(N\) is registered accounts.

### \(N \le 1{,}000\) (planning \(C \approx 8\))

Stay on **S0**: one guest, 8 GB, `infra/compose.yaml`, Caddy on 80/443 only. Weekly, record \(M_{\text{used}}\), \(D_{\text{used}}\), load. Do not pre-buy 16 GB. Do create the object-storage bucket now (backups already require a different provider) so row 2 is a config change, not a procurement.

### \(1{,}000 < N \le 10{,}000\) (planning \(C \approx 75\))

Still one Compose file. The likely first trip through the matrix is **row 2 (disk)** if people upload photos, or **row 5 (slow queries)** if the wiki grows, not RAM. Ghost (Phase 2) still fits 8 GB per §2. Apply row 3 only if `docker stats` says so.

### \(N > 10{,}000\) or busy \(C > 300\)

Re-measure idle RAM; the table in §2 may be stale. If the Shell is CPU-bound, it is the only process that `--scale`s on one host without lying about state. NodeBB, Ghost, and MediaWiki stay at one writer. If row 6 is also true (people would feel a 2-hour restore), start the warm-standby drill **before** k3s.

### Past that (busy \(C\) in the thousands)

S2 then S3: object storage already on, databases on a data guest, Shell Deployments on k3s, ingress instead of host-bound Caddy. Convert **images + env**, not the Compose YAML. That is why day 1 publishes the Shell to GHCR and keeps hostnames out of the image.

There is no user-count at which Docker Swarm or Dokploy becomes the right cluster. Swarm is a dead-end relative to k3s; paying its tax on one node does not amortize later.

---

## 6. Stages (runtime, not SKU)

| Stage | Runtime | You are here when | Portable artifact |
| :--- | :--- | :--- | :--- |
| **S0** | Compose + Caddy, one guest | Default. Phase 1 and 1,000 users. | `infra/compose.yaml`, `SHELL_IMAGE`, `infra/.env` |
| **S1** | Same file, more RAM/CPU | Row 3 or 4 | Unchanged YAML |
| **S2** | App guest + data plane / object storage | Rows 1, 2, 7 | Env vars (`WIKI_DB_*` host, `OBJECT_STORAGE_*`) |
| **S3** | k3s for stateless; DBs off-cluster | Row 8 | GHCR images + the same env contract |

Staging stays a **Proxmox KVM VM** running the same Compose file through S2. Nested Docker-in-LXC is out of scope.

---

## 7. Cluster destination

| Method | Cluster? | Use |
| :--- | :--- | :--- |
| k3s | Yes | **S3 only** |
| Docker Swarm / Dokploy / CapRover | Yes, maintenance-mode | No |
| Coolify multi-server | SSH remotes, not a scheduler | No |
| Compose `--scale` | One host | Shell only, still S0/S1 |
| Podman Quadlets | Per-machine systemd | No |
| Proxmox HA | Guest failover | Warm standby (row 6), not S3 |

---

## 8. Day-1 contract (so S3 is not a rewrite)

These are in the repo so later stages change **where** a process runs, not **what** it is.

| Item | Where | Status |
| :--- | :--- | :--- |
| Shell image on GHCR (`:main` + full git SHA) | `.github/workflows/deploy.yml` | Path-filtered publish on `main`; PRs do not. Image: `ghcr.io/heff0/stagea-shell` |
| Compose pulls `SHELL_IMAGE` | `infra/compose.yaml`, `infra/.env.example` | Host `build:` remains as bootstrap/override |
| Per-module deploy (Shell does not bounce forum/wiki) | `infra/deploy.sh --module`, [ci-cd.md](./ci-cd.md) | CI SSH optional until `DEPLOY_ENABLED=true` |
| Healthchecks on every Phase 1 service | `infra/compose.yaml`; `/healthz` on the Shell | `deploy.sh` already waits on them |
| Healthcheck on local Shell compose | `shell/docker-compose.yml` | Local-dev only |
| No baked-in public hostnames | Compose `environment:` from `.env` | Public URLs are `FORUM_URL` / `WIKI_URL` / … |
| Caddy is the only host `ports:` | `infra/compose.yaml` | Unchanged |
| Ghost / Keycloak / Saleor / Directus absent | Phase 1 Compose | Enforced by slice 9 / 11 and §2 |
| Object-storage env inventory | `OBJECT_STORAGE_*` in `.env.example` | Volumes still hold uploads until row 2 fires |
| Restore drill | §9 below; scripts are slice 7 | Procedure exists; `backup.sh` is still deferred |

Wiring MediaWiki and NodeBB to S3 plugins is **not** day 1. Day 1 is the env contract and the inequality that turns it on.

---

## 9. Restore drill (reliability)

Canonical capture list: [`production_plan.md` §8](./production_plan.md#8-backup-and-restore-minimum). Scripts: slice 7 (`infra/backup.sh` / `infra/restore.sh`) — not implemented yet.

Until slice 7 lands, the drill is still defined:

1. Take a snapshot of named volumes + logical DB dumps onto object storage at a **different provider than the VPS**.
2. On the Proxmox staging VM (throwaway Compose project `-p stagea-restore`), restore the latest snapshot.
3. `up` the stack; confirm a known forum post and a known wiki edit.
4. Record wall-clock time. That number **is** the RTO. Target: < 2 hours. RPO: 24 hours.
5. Repeat every quarter and after any volume-layout change.

Row 6 in §4 compares the **required** RTO to this measured number. If the business needs faster than the last drill, buy a warm standby, not a cluster.

---

## 10. What not to do

* Do not pick a VPS SKU from a blog post. Pick \(R_{\text{total}}\) and \(D_{\text{total}}\) that satisfy §2 and §4.
* Do not start Saleor or Keycloak on the Phase 1 guest “to try SSO.”
* Do not run `docker compose down -v`.
* Do not adopt Dokploy/Swarm so that “clustering is ready.”
* Do not treat 1,000 registered users as a capacity event.

---

## 🔗 Related

* 🌍 **[Production Deployment Plan](./production_plan.md)** — platform, service map, one-command contract, backup floor.
* 🚀 **[Production Spin-Up Runbook](./GO_LIVE.md)** — how to bring the box up.
* 📋 **[Sprint cards](./cards/README.md)** — slices 01–11. Slice 8 is the GHCR publish this plan depends on.
* 📁 **[`infra/` README](../../infra/README.md)** — image pins, `SHELL_IMAGE` rollback.
