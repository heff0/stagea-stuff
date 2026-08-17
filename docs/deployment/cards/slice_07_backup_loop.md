# Slice 7 — Backup Loop

**Status**: implemented in repo (restore drill still required on a real host)  
**Phase 1 go-live**: no (operability)  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md)

---

## 🎯 1. Overview & Why This Increment

Phase 1 can run without backups; it cannot be *operated* without them. Nightly logical dumps plus an encrypted restic push of named volumes to object storage at a **different provider than the VPS**. `infra/backup.sh` and `infra/restore.sh` are separate from `./infra/deploy.sh`.

Canonical floor: [production_plan.md §8](../production_plan.md#8-backup-and-restore-minimum). Do not duplicate that table here.

---

## 🛠 2. What landed

| Path | Action |
| :--- | :--- |
| `infra/backup.sh` | **Add** — MariaDB `mariadb-dump --single-transaction`, Redis `BGSAVE`, tar named volumes, `restic backup` + `forget` (7/4/6). |
| `infra/restore.sh` | **Add** — confirm by retyping snapshot id; restore into `stagea-restore` by default; import SQL; `up -d`. |
| `infra/systemd/stagea-backup.{service,timer}` | **Add** — host timer (not Compose sidecar). |
| `infra/.env.example` | **Change** — `RESTIC_*`, `AWS_*`, optional keep / staging / restore project. |
| `infra/README.md` | **Change** — operator commands + timer install. |
| `.gitignore` | Staging / dump noise. |

**Choices (open item from production_plan §10):** restic (not borg); **host systemd timer** (not sidecar) — no `docker.sock`, schedule survives `compose down`.

Does not start Ghost / Saleor / Keycloak / Directus. Does not put `infra/.env` in the snapshot.

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: `./infra/backup.sh` after `--init` lists a snapshot in the remote repository.
2. **Test**: `./infra/restore.sh <id>` into `-p stagea-restore`; known forum post + wiki edit return. Record wall-clock (RTO &lt; 2h; RPO 24h).
3. Nightly timer documented and installable from `infra/systemd/`.
4. `./infra/deploy.sh` unchanged in spirit — backup is a separate command.

---

## 🚦 4. 6-Step Feature Loop Checklist

- [x] **1. Scaffold**: restic + host systemd timer; `backup.sh` / `restore.sh`.
- [x] **2. Document**: Point at [§8](../production_plan.md#8-backup-and-restore-minimum); `infra/README.md`.
- [x] **3. MVP Spec**: The four criteria above.
- [ ] **4. Test**: Restore drill on a host with real volumes **before** calling the slice operationally done.
- [x] **5. Implement**: Dumps, encrypt, push, retain, restore confirmation.
- [x] **6. Review**: Passphrase ≠ storage credentials; VPS provider ≠ bucket provider (documented).

---

## 🚫 5. Explicit Non-Goals

* Starting Ghost / Saleor / Keycloak OIDC IdP / Directus Parts API.
* Replacing `deploy.sh`.
* Building **Submodules**.
* Compose sidecar with `docker.sock`.

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md) — the stack is one-command and has named-volume data worth restoring.
