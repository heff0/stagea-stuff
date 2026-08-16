# Slice 1 — Host Baseline

**Status**: documented; operator performs on VPS  
**Phase 1 go-live**: yes  
**Depends on**: none (first slice)

---

## 🎯 1. Overview & Why This Increment

A production VPS that cannot run containers, or that exposes extra ports, makes every later slice a guess. This slice is one-time host setup only: provision, harden SSH, install Docker Engine + Compose v2, lock the firewall, rotate Docker logs, and clone this repository.

There is no application code in this increment. The demo is `docker run --rm hello-world` as the deploy user. After this slice the host is a blank, safe place to land `infra/compose.yaml` in slice 2.

Canonical one-time checklist: [production_plan.md §5](../production_plan.md#5-initial-setup-checklist). Do not start Ghost, Saleor, the Keycloak OIDC IdP, or the Directus Parts API.

---

## 🛠 2. Technical Blueprint

### Repository files

| Path | Action | Why |
| :--- | :--- | :--- |
| `.gitignore` | **Change** — add an explicit `/infra/.env` line (with a one-line comment) if it is not already listed | Plan requires `infra/.env` gitignored before the first deploy. Root `.env` / `.env.*` rules already match `infra/.env`; the explicit line makes the contract greppable. Keep `!.env.example` so `infra/.env.example` (slice 2) stays tracked. |
| `infra/compose.yaml` | **Do not add** | Slice 2. |
| `infra/Caddyfile` | **Do not add** | Slice 2. |
| `infra/deploy.sh` | **Do not add** | Slice 6. |
| `shell/` | **Do not change** | Slice 3. |
| `.github/` | **Do not change** | Slice 8. |

No Compose services, Caddy routes, or application env vars in this slice.

### Host (not in git)

Target: **Ubuntu 24.04 LTS, 2 vCPU, 8 GB RAM, 80 GB disk.** Provider-agnostic (Hetzner, DigitalOcean, Vultr, Linode, OVH, or equivalent).

| Step | Concrete target |
| :--- | :--- |
| User | Non-root sudo user (the deploy user). Disable password SSH and root SSH login. Key-only auth. |
| Firewall | UFW (or equivalent): inbound allow `22`, `80`, `443` only; default deny incoming; enable. |
| Unattended upgrades | Enabled for security patches. |
| Docker | Docker Engine 24+ and Compose **v2** plugin from Docker's official apt repository — not the distro `docker.io` package, not Compose v1 (`docker-compose`). |
| Group | Deploy user in the `docker` group; `docker compose version` prints v2. |
| Swap | 2 GB swap file (MediaWiki/MariaDB spike margin). |
| Log rotation | `/etc/docker/daemon.json`: `"log-driver": "json-file"`, `"log-opts": { "max-size": "10m", "max-file": "3" }`, then restart Docker. |
| Clone | `git clone` this repository to `/opt/stagea` (or another stable path). **Do not** run `git submodule update --init`. **Submodules** are not built in production. |
| Secrets file | Do not author `infra/.env` yet — that file appears with `infra/.env.example` in slice 2. Confirm `.gitignore` coverage in this slice so slice 2 cannot accidentally commit it. |

### DNS (create now, use in slice 2+)

Point at the VPS public IPv4 (and IPv6 `AAAA` if the host has it). TTL 300 while iterating.

* `A` `stagea-stuff.com` → VPS
* `A` `www` → VPS
* `A` `app` → VPS (permanent redirect to apex starts in slice 2)
* `A` `forum` → VPS (route lands in slice 4; record now so ACME is not blocked later)
* `A` `wiki` → VPS (route lands in slice 5)
* Do **not** require `blog`, `shop`, `auth`, or `parts` records in Phase 1

Verify: `dig +short forum.stagea-stuff.com` returns the VPS IP before slice 2 starts Caddy.

### Compose / Caddy / health

None. No containers except the one-shot `hello-world` demo.

---

## 📋 3. MVP Acceptance Criteria

From [production_plan.md §7 slice 1](../production_plan.md#slice-1--host-baseline), plus what later one-command deploys need:

1. **Demo**: SSH in as the deploy user and run `docker run --rm hello-world` — it prints the hello-world message and exits 0.
2. **Test**: a port scan from a machine *outside* the VPS shows only `22`, `80`, and `443` open (UFW may show `80`/`443` allowed even though nothing is bound yet — that is correct; those ports must be open for Caddy in slice 2).
3. `docker compose version` reports Compose v2.
4. `git -C /opt/stagea status` (or the chosen clone path) is a clean checkout of this repo; no `forum/`, `wiki/`, `blog/`, or `shop/` working trees from a submodule init.
5. `.gitignore` lists `/infra/.env` (or an equivalent rule that matches that path). `git check-ignore -v infra/.env` reports a matching rule.
6. Docker log rotation is configured as above (`docker info` shows the json-file max-size/max-file opts, or `/etc/docker/daemon.json` contains them).
7. The host has enough disk that a later `docker compose pull` of Caddy + Node + MariaDB will not fill the root volume (80 GB target).

---

## 🚦 4. 6-Step Feature Loop Checklist

See [docs/shell/TODO.md §1](../../shell/TODO.md#1-the-6-step-developer-feature-loop).

- [ ] **1. Scaffold**: Provision the VPS, create the deploy user, clone the repo to the stable path. No application files.
- [ ] **2. Document**: Tick every box in [production_plan.md §5.2](../production_plan.md#52-host-preparation) and §5.1 DNS on the live host notes (password manager / runbook — not in git). Confirm this card's file list still matches what was done.
- [ ] **3. MVP Spec**: The seven acceptance criteria above are the spec. Do not add extra daemons (fail2ban-as-a-project, monitoring agents, extra reverse proxies).
- [ ] **4. Test**: From an external host, scan `22`/`80`/`443` and a closed port (e.g. `4567`, `8080`, `3306`) and record the result. On the VPS, run `docker run --rm hello-world` and `docker compose version`.
- [ ] **5. Implement**: Apply SSH hardening, UFW, unattended upgrades, Docker Engine + Compose v2, swap, `daemon.json`, `.gitignore` `/infra/.env` line.
- [ ] **6. Review**: Confirm no secrets in the clone, no Submodule init, no host `ports` published, no second edge proxy. Ready for slice 2.

---

## 🚫 5. Explicit Non-Goals

* Writing `infra/compose.yaml`, `infra/Caddyfile`, or `infra/deploy.sh`.
* Building or running the Astro Shell, NodeBB, MediaWiki, Ghost, Saleor, the Keycloak OIDC IdP, or the Directus Parts API.
* Running `git submodule update --init`.
* Authoring production secrets (slice 2 introduces `infra/.env.example`; humans fill `infra/.env` then).
* Installing nginx, certbot, or any second TLS terminator.
* Kubernetes, Swarm, or a PaaS.
* Backups, GHCR, or observability (slices 7, 8, 10).

---

## 🔗 6. Depends On

None. This is the first slice. Do not start slice 2 until the demo and external port scan are green.
