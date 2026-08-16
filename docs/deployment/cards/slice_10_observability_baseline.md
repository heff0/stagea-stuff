# Slice 10 — Observability Baseline

**Status**: not started — deferred (Phase 2 operability)  
**Phase 1 go-live**: no  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md)

---

## 🎯 1. Overview & Why This Increment

Failures should be known before users report them. Add any missing container health checks, an uptime probe against each public host, and a disk-space alert. Deliberately minimal — **no Prometheus stack** at this scale.

---

## 🛠 2. Technical Blueprint (deferred)

| Path | Action (when this slice starts) |
| :--- | :--- |
| `infra/compose.yaml` | **Change** — fill any missing `healthcheck` blocks (Phase 1 should already have them; Ghost/MySQL if slice 9 landed). |
| `infra/README.md` | **Change** — where alerts go (email, ntfy, Uptime Kuma, Healthchecks.io — pick one cheap external probe). |
| `.github/` | Optional: workflow that curls `/healthz` and the public hosts from CI on a schedule. Not required if an external uptime tool is used. |
| Host | Disk-space alert (e.g. systemd timer + `df`, or the uptime tool's disk agent). Fire before the root volume is full. |

Public probes: `https://stagea-stuff.com/healthz`, `https://forum.stagea-stuff.com`, `https://wiki.stagea-stuff.com`, plus `https://blog.stagea-stuff.com` if slice 9 is live. Do not probe Redis/MariaDB from the internet.

Do not start the Keycloak OIDC IdP, Saleor, or the Directus Parts API for this slice.

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: stop a container and receive an alert.
2. **Test**: fill a volume in a scratch environment and confirm the disk alert fires before the host wedges.
3. Every Compose service that should be healthy has a `healthcheck`; `deploy.sh` wait still matches.
4. No Prometheus / Grafana / Loki required to close this slice.

---

## 🚦 4. 6-Step Feature Loop Checklist

- [ ] **1. Scaffold**: Choose the uptime product; list probe URLs.
- [ ] **2. Document**: `infra/README.md` + link [§4 request path](../production_plan.md#4-request-path) (do not redraw it).
- [ ] **3. MVP Spec**: The four criteria above.
- [ ] **4. Test**: Kill `shell` / `forum` / `wiki` one at a time; confirm alert + recovery via `deploy.sh`.
- [ ] **5. Implement**: Probes, disk alert, missing healthchecks.
- [ ] **6. Review**: Nothing listening on extra host ports; no metrics stack sprawl.

---

## 🚫 5. Explicit Non-Goals

* Prometheus, Grafana, ELK, or a second observability Compose stack.
* APM / tracing.
* Identity or commerce (slice 11).

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md) so there is a health-wait contract to align with. Slice 9 optional (add blog probes if present).
