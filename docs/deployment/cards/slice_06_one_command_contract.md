# Slice 6 — One-Command Contract

**Status**: implemented in repo  
**Phase 1 go-live**: yes  
**Depends on**: [Slice 5 — Wiki Node Online](./slice_05_wiki_node_online.md)

---

## 🎯 1. Overview & Why This Increment

This is the headline goal. After one-time host setup (slice 1) and first-run wizards (slices 4–5), **routine** production spin-up is a single command. Write a thin, auditable wrapper — not an abstraction layer — that preflights, pulls, ups, waits for health, and prints a one-screen summary.

If the wrapper is deleted, the escape hatch still deploys the stack. That constraint keeps the wrapper honest.

Behavior is specified in [production_plan.md §6](../production_plan.md#6-the-one-command-contract). This card does not invent extra flags or a second Compose file.

---

## 🛠 2. Technical Blueprint

### Repository files

| Path | Action | Why |
| :--- | :--- | :--- |
| `infra/deploy.sh` | **Add** | The one command. Executable (`chmod 755`). POSIX-ish bash. |
| `infra/README.md` | **Change** | Document `./infra/deploy.sh`, `--check`, `--skip-git-pull`, and the escape hatch. |
| `infra/compose.yaml` | **Change only if needed** | Every Phase 1 service must have a Compose `healthcheck` so the wait loop can succeed. Add any missing probes (Caddy, shell, forum, forum-redis, wiki, wiki-db). Do not add new services. |
| `infra/.env.example` | **Change only if needed** | Must list every key `deploy.sh` treats as required for Phase 1. |
| `.gitignore` | **Confirm** | `/infra/.env` still ignored. |
| `.github/` | **Do not change** | Slice 8. |
| `infra/backup.sh` / `infra/restore.sh` | **Do not add** | Slice 7. Supporting commands in §6 are documented as future; do not stub them here. |

### `deploy.sh` behavior (exact, from §6)

Shebang `#!/usr/bin/env bash` and `set -euo pipefail`. Resolve the repo root from the script location (`SCRIPT_DIR`) so the operator can run `./infra/deploy.sh` from any cwd. All `docker compose` invocations use:

```bash
docker compose -f infra/compose.yaml --env-file infra/.env
```

from the repo root.

#### Default run (`./infra/deploy.sh`)

Execute **in this order**. Do not skip steps. Do not add host provisioning, DNS edits, secret generation, or application installers.

1. **Preflight — env file**
   * Fail if `infra/.env` is missing.
   * Fail if `infra/.env` is world-readable (other-read bit set; require `chmod 600` / mode `600` or `640` at most — **implement as: fail if `$(stat)` shows other-read or if mode is more permissive than `0640`**. Prefer fail-unless-`600` to match [§5.3](../production_plan.md#53-repository-and-secrets)).
   * Fail if any **required** key is missing or empty. Required Phase 1 keys (must match `.env.example`):
     * `ACME_EMAIL`
     * `NODE_ENV`, `HOST`, `PORT`, `PUBLIC_SITE_NAME`
     * `FORUM_URL`, `WIKI_URL`, `BLOG_URL`, `SHOP_URL`
     * `AUTH_ISSUER_URL`, `AUTH_CLIENT_ID`, `AUTH_CLIENT_SECRET` (placeholders allowed; keys must be present)
     * `GHOST_CONTENT_API_KEY` (placeholder allowed)
     * `FORUM_REDIS_PASSWORD`
     * `WIKI_DB_NAME`, `WIKI_DB_USER`, `WIKI_DB_PASSWORD`, `WIKI_DB_ROOT_PASSWORD`
   * Print a clear message naming the missing file, permission problem, or key. **Change nothing** (no `pull`, no `up`).
2. **Preflight — Docker**
   * Fail if Docker is not running (`docker info`).
   * Fail if Compose v2 is unavailable (`docker compose version` must report v2, not the v1 `docker-compose` binary as the only option).
3. **`git pull --ff-only`** on the current branch, from the repo root.
   * Skippable with `--skip-git-pull` for pinned rollbacks (the "skippable with a flag" in §6).
   * Fast-forward only; refuse a merge. Fail if the pull cannot FF.
4. **`docker compose -f infra/compose.yaml --env-file infra/.env pull`**
   * Pulls pinned upstream images. For `shell` (build: on host until slice 8), `pull` may no-op or pull the base; that is fine. Do not add a separate undocumented build wrapper — `up` will build `shell` if needed.
5. **`docker compose -f infra/compose.yaml --env-file infra/.env up -d --remove-orphans`**
   * Creates/reconciles Caddy, shell, forum, forum-redis, wiki, wiki-db only.
6. **Health-wait**
   * Poll `docker compose … ps` (or `inspect` Health) until every Compose service with a `healthcheck` is `healthy`, or a timeout expires (implement **120 seconds** default; document `DEPLOY_HEALTH_TIMEOUT` if overridable).
   * Services: `caddy`, `shell`, `forum`, `forum-redis`, `wiki`, `wiki-db`.
7. **Summary**
   * Print one screen: service name, health, image tag, public URL.
   * URLs: `https://stagea-stuff.com` (shell), `https://forum.stagea-stuff.com` (forum), `https://wiki.stagea-stuff.com` (wiki). Internal-only services (`forum-redis`, `wiki-db`) print `—` for URL.
8. **Exit**
   * Exit `0` only if every healthchecked service is healthy.
   * Exit non-zero if any is unhealthy or the timeout fired. Do not `down` the stack on failure (leave it for diagnosis).

Idempotent: a second run against a healthy stack is a no-op (pull + up reconcile; health-wait succeeds immediately).

#### `--check` (`./infra/deploy.sh --check`)

Preflight **only** (steps 1–2). Changes nothing: no `git pull`, no `pull`, no `up`, no health-wait. Exit 0 if preflight passes; non-zero otherwise.

`--check` and `--skip-git-pull` together: `--check` still does not pull git.

#### Escape hatch (must always work)

```bash
docker compose -f infra/compose.yaml --env-file infra/.env up -d
```

`deploy.sh` must not become the only way to interpolate env, choose the Compose file, or start containers. No hidden `COMPOSE_FILE` in the operator's shell profile as a requirement. Document the escape hatch in `infra/README.md` and in the script's `--help` (a few lines of usage is enough; not a framework).

#### Supporting commands (document only — do not implement in this slice)

| Command | Purpose |
| :--- | :--- |
| `./infra/deploy.sh --check` | Preflight only |
| `docker compose -f infra/compose.yaml logs -f <service>` | Tail |
| `docker compose -f infra/compose.yaml ps` | State |
| `./infra/backup.sh` | Slice 7 |
| `./infra/restore.sh <snapshot>` | Slice 7 |

### Compose / Caddy / env

No new Caddy routes. No new services. No Ghost, Saleor, Keycloak OIDC IdP, or Directus Parts API.

If any Phase 1 service lacks a `healthcheck`, add it in this slice so step 6 can succeed. Do not weaken the wait to "container running."

### Image pins

Unchanged. `deploy.sh` must not retag images to `:latest`.

---

## 📋 3. MVP Acceptance Criteria

From [production_plan.md §7 slice 6](../production_plan.md#slice-6--one-command-contract):

1. **Demo**: on a freshly rebooted host, `./infra/deploy.sh` alone brings the entire Phase 1 stack to healthy (Caddy, Astro Shell, forum, Redis, wiki, MariaDB).
2. **Test**: deliberately corrupt `infra/.env` (missing file, or `chmod 644`, or delete a required key) and confirm the script fails fast with a clear message and **changes nothing** (no new containers, no image pull). Restore `.env`. Run `./infra/deploy.sh` twice; the second run is a no-op (all healthy, no recreate storm).
3. `./infra/deploy.sh --check` on a valid `.env` exits 0 and does not call `up` or `pull`.
4. Escape hatch still deploys the same stack without the script.
5. `--skip-git-pull` skips step 3 and still completes 4–8.
6. Summary lists service, health, image tag, public URL.
7. Script never runs `down -v`, never starts Ghost/Saleor/Keycloak/Directus, never calls `git submodule update`.
8. Forum post + wiki edit from slices 4–5 still exist after the reboot demo.

---

## 🚦 4. 6-Step Feature Loop Checklist

See [docs/shell/TODO.md §1](../../shell/TODO.md#1-the-6-step-developer-feature-loop).

- [ ] **1. Scaffold**: Add `infra/deploy.sh` with `set -euo pipefail`, usage/`--help`, and stub functions for preflight / pull / up / wait / summary.
- [ ] **2. Document**: `infra/README.md` — one command, `--check`, `--skip-git-pull`, escape hatch, non-goals from [§6](../production_plan.md#explicit-non-goals-for-the-one-command).
- [ ] **3. MVP Spec**: The eight acceptance criteria above.
- [ ] **4. Test**: On the VPS (or a throwaway clone of the project), run the corrupt-`.env` cases and `--check` before wiring `up`. Confirm each failure path prints the reason and does not `up`.
- [ ] **5. Implement**: Full step list 1–8, health-wait timeout, summary table, reboot demo.
- [ ] **6. Review**: Read the script end-to-end — no hidden magic, no second Compose file, no submodule init. Phase 1 go-live checklist is complete.

---

## 🚫 5. Explicit Non-Goals

From [§6](../production_plan.md#explicit-non-goals-for-the-one-command): the one command does **not** provision hosts, edit DNS, generate secrets, run interactive application installers, or migrate data between hosts.

Also not this slice:

* `infra/backup.sh` / `infra/restore.sh` (slice 7).
* GHCR publish / drop `build:` (slice 8).
* Ghost, Saleor, Keycloak OIDC IdP, Directus Parts API.
* A TUI, Make, or Taskfile as a second entry point.

---

## 🔗 6. Depends On

[Slice 5 — Wiki Node Online](./slice_05_wiki_node_online.md): Phase 1 content stack is up via the escape hatch, all six services exist, first-run wizards are done, named volumes have real data to prove the reboot demo.
