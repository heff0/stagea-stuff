# Slice 7 — Backup Loop

**Status**: not started — deferred (Phase 2 operability)  
**Phase 1 go-live**: no  
**Depends on**: [Slice 6 — One-Command Contract](./slice_06_one_command_contract.md)

---

## 🎯 1. Overview & Why This Increment

Phase 1 can run without backups; it cannot be *operated* without them. Add nightly logical database dumps plus an encrypted push of all named volumes to object storage at a **different provider than the VPS**. Write `infra/backup.sh` and `infra/restore.sh`. A backup that has never been restored is not a backup.

Canonical floor: [production_plan.md §8](../production_plan.md#8-backup-and-restore-minimum). Do not duplicate that table here.

---

## 🛠 2. Technical Blueprint (deferred)

| Path | Action (when this slice starts) |
| :--- | :--- |
| `infra/backup.sh` | **Add** — dump then restic/borg push. |
| `infra/restore.sh` | **Add** — guided restore, requires explicit confirmation. |
| `infra/compose.yaml` | **Change** — optional restic sidecar **or** document a host systemd timer. [§10](../production_plan.md#10-open-items-for-the-implementation-pass) leaves this choice to the implementer. |
| `infra/.env.example` | **Change** — object-storage URL, restic/borg repo password, bucket credentials. |
| `.gitignore` | Confirm no repo keys, no dump files. |
| `.github/` | Not required. |

Must capture (see §8): `forum_data` + Redis `BGSAVE`, `forum_uploads`, MariaDB `mariadb-dump --single-transaction`, `wiki_images`, `wiki_config`, `caddy_data`. `infra/.env` lives in the password manager, not only on the host.

Retention: 7 daily / 4 weekly / 6 monthly. Never `down -v` as a backup step.

---

## 📋 3. MVP Acceptance Criteria

1. **Demo**: trigger a manual backup (`./infra/backup.sh`) and list the snapshot in the remote repository.
2. **Test**: restore into a throwaway Compose project (`-p`) and confirm a known forum post and wiki edit return. Record wall-clock time (RTO target: under two hours; RPO: 24 hours).
3. Nightly schedule exists (timer or sidecar) and is documented in `infra/README.md`.
4. `./infra/deploy.sh` is unchanged in spirit — backup is a **separate** command ([§6 supporting commands](../production_plan.md#supporting-commands-deliberately-separate)).

---

## 🚦 4. 6-Step Feature Loop Checklist

- [ ] **1. Scaffold**: Choose restic vs borg; choose sidecar vs systemd timer; stub `backup.sh` / `restore.sh`.
- [ ] **2. Document**: Point at [§8](../production_plan.md#8-backup-and-restore-minimum); do not copy the capture table.
- [ ] **3. MVP Spec**: The four criteria above.
- [ ] **4. Test**: Restore drill in a throwaway project **before** declaring the slice done.
- [ ] **5. Implement**: Dumps, encrypt, push, retain, restore confirmation prompt.
- [ ] **6. Review**: Passphrase ≠ storage credentials; VPS provider ≠ bucket provider.

---

## 🚫 5. Explicit Non-Goals

* Starting Ghost / Saleor / Keycloak OIDC IdP / Directus Parts API (unless slice 9 already landed — then include blog volumes per §8).
* Replacing `deploy.sh`.
* Building **Submodules**.

---

## 🔗 6. Depends On

[Slice 6](./slice_06_one_command_contract.md) — the stack is one-command and has real named-volume data worth restoring.
