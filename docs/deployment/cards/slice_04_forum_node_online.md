# Slice 4 — Forum Node Online

**Status**: implemented in repo  
**Phase 1 go-live**: yes  
**Depends on**: [Slice 3 — Shell Edge Online](./slice_03_shell_edge_online.md)

---

## 🎯 1. Overview & Why This Increment

First service with real user-generated state. Add official NodeBB plus Redis on the internal network, route `forum.stagea-stuff.com`, and complete the interactive setup wizard. Named volumes and an internal-only dependency are the pattern every later stateful service copies.

**Submodules** (`forum/`) stay unused. Production never builds NodeBB from this repo.

---

## 🛠 2. Technical Blueprint

### Repository files

| Path | Action | Why |
| :--- | :--- | :--- |
| `infra/compose.yaml` | **Change** | Add `forum` and `forum-redis`. Do not add a host `ports:` on either. |
| `infra/Caddyfile` | **Change** | Add `forum.stagea-stuff.com` → `forum:4567`. |
| `infra/.env.example` | **Change** | Append Redis password and NodeBB public URL (already have `FORUM_URL` from slice 3). |
| `infra/.env` | **Change on the host** | Real `FORUM_REDIS_PASSWORD` (`openssl rand -base64 32`). |
| `infra/README.md` | **Change** | Document `forum` / `forum-redis` and first-run wizard. |
| `forum/` | **Do not change** | **Submodule**. Official image only. |
| `infra/deploy.sh` | **Do not add** | Slice 6. Persistence demo uses the escape hatch until then. |
| `.github/` | **Do not change** | |

### Compose — service names

| Service | Image (pin; confirm at implement time) | Host ports | Volumes |
| :--- | :--- | :--- | :--- |
| `forum` | official `nodebb/docker:4.4` (or current `4.x` minor — never `:latest`) | none (`expose: ["4567"]`) | `forum_data`, `forum_uploads` |
| `forum-redis` | official `redis:7.4-alpine` | none (`expose: ["6379"]`) | `forum_redis_data` |

Volume mapping (adjust container paths to match the pinned `nodebb/docker` image docs at implement time; names are fixed by the plan):

* `forum_data` → NodeBB config / persist dir (commonly `/opt/config` or `/usr/src/app` config path — **read the image's documented config mount**, do not invent a bind-mount of `forum/`).
* `forum_uploads` → NodeBB uploads (commonly `/usr/src/app/public/uploads`).
* `forum_redis_data` → `/data` with Redis AOF enabled (`redis-server --appendonly yes`).

```yaml
  forum-redis:
    image: redis:7.4-alpine
    restart: unless-stopped
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${FORUM_REDIS_PASSWORD}"]
    expose: ["6379"]
    volumes:
      - forum_redis_data:/data
    networks: [stagea-net]
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${FORUM_REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    logging: { driver: json-file, options: { max-size: "10m", max-file: "3" } }

  forum:
    image: nodebb/docker:4.4
    restart: unless-stopped
    depends_on:
      forum-redis:
        condition: service_healthy
    expose: ["4567"]
    environment:
      url: ${FORUM_URL}   # https://forum.stagea-stuff.com/
      # Redis host MUST be the Compose service name, not localhost
    volumes:
      - forum_data:/opt/config
      - forum_uploads:/usr/src/app/public/uploads
    networks: [stagea-net]
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:4567"]  # if image lacks wget, use the image's documented probe or node fetch
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 60s
    logging: { driver: json-file, options: { max-size: "10m", max-file: "3" } }
```

First-run: NodeBB's web setup wizard (one-time, human). Point it at Redis host `forum-redis`, port `6379`, password `${FORUM_REDIS_PASSWORD}`. Public URL `https://forum.stagea-stuff.com`. Persist the generated config in `forum_data` so later `up` skips the wizard.

If the pinned image uses different env names (`REDIS_HOST`, `CONFIG_DIR`, …), use **those** names in Compose and list them in `infra/.env.example`. Do not start a second Redis.

### Caddy routes (add)

```caddy
forum.stagea-stuff.com {
    reverse_proxy forum:4567
    header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}
```

DNS `forum` A record was created in slice 1. Confirm `dig +short forum.stagea-stuff.com` before the first Caddy reload so ACME succeeds.

### Env vars (append)

```bash
# Forum (NodeBB) — official image, not the forum/ Submodule
FORUM_URL=https://forum.stagea-stuff.com/
FORUM_REDIS_PASSWORD=change-me
```

`FORUM_URL` already exists for the Astro Shell; keep a single key.

### Health checks

| Check | Expect |
| :--- | :--- |
| `forum-redis` | `healthy`; `docker compose port forum-redis 6379` fails / no host binding |
| `forum` | `healthy` after wizard; `https://forum.stagea-stuff.com` is the NodeBB UI |
| Uploads | Upload a file; it remains after a full stack restart |
| Isolation | From outside the VPS, `forum:4567` and Redis `:6379` are closed |

### Image pins

Official images only. Never `build: ../forum`. Never `:latest`.

---

## 📋 3. MVP Acceptance Criteria

From [production_plan.md §7 slice 4](../production_plan.md#slice-4--forum-node-online):

1. **Demo**: `https://forum.stagea-stuff.com` serves a working forum. Create a post. Then `docker compose -f infra/compose.yaml --env-file infra/.env down` (no `-v`) and bring the stack back with the escape hatch (`up -d`). After slice 6, the same demo is `down && ./infra/deploy.sh`. The post is still there.
2. **Test**: Redis has no host port binding. Uploads persist across a full stack restart.
3. Compose `config` shows no `ports` on `forum` or `forum-redis`.
4. `forum/` Submodule is not cloned, built, or bind-mounted.
5. Apex Astro Shell still healthy; nav `FORUM_URL` is the public HTTPS URL.
6. No Ghost, Saleor, Keycloak OIDC IdP, or Directus Parts API services.

---

## 🚦 4. 6-Step Feature Loop Checklist

See [docs/shell/TODO.md §1](../../shell/TODO.md#1-the-6-step-developer-feature-loop).

- [ ] **1. Scaffold**: Draft `forum` + `forum-redis` service blocks locally in `infra/compose.yaml` (no host ports).
- [ ] **2. Document**: `infra/README.md` first-run wizard (Redis hostname `forum-redis`). Link [production_plan.md §5.5](../production_plan.md#55-per-application-bootstrap-one-time-interactive).
- [ ] **3. MVP Spec**: The six acceptance criteria above.
- [ ] **4. Test**: Write the persistence procedure (create post → `down` without `-v` → `up -d` → post exists). Confirm `docker compose config` has no Redis host port.
- [ ] **5. Implement**: Pin images, volumes, Caddy site, `.env.example`, run the wizard on the VPS.
- [ ] **6. Review**: No `down -v` in docs or scripts. No Submodule build. Apex still green.

---

## 🚫 5. Explicit Non-Goals

* Building NodeBB from `forum/`.
* Host-publishing `4567` or `6379`.
* OIDC / Keycloak OIDC IdP login on the forum (slice 11).
* `infra/deploy.sh` (slice 6) — use the escape hatch; do not block this slice on the wrapper.
* Ghost, wiki, Saleor, Directus Parts API.
* `docker compose down -v` (deletes production data).

---

## 🔗 6. Depends On

[Slice 3 — Shell Edge Online](./slice_03_shell_edge_online.md): apex Astro Shell healthy, Caddy routing pattern proven, `FORUM_URL` already in `.env.example`, DNS for `forum` in place.
