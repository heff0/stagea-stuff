# Slice 3 — Shell Edge Online

**Status**: implemented in repo  
**Phase 1 go-live**: yes  
**Depends on**: [Slice 2 — Edge Skeleton](./slice_02_edge_skeleton.md)

---

## 🎯 1. Overview & Why This Increment

The first real Stagea page on the internet. Add the **Astro Shell** (Shell Edge) as a Compose service **built from `shell/Dockerfile`** — the only image this repository builds in production — and point the apex at `shell:4321`. A dedicated `/healthz` endpoint makes the container `healthy` without depending on **Submodules** or the Keycloak OIDC IdP.

This increment is shippable on its own: a public, server-rendered landing site behind valid TLS. Forum and wiki come next; they are not required for the Shell to boot.

Env names are already specified in [shell_deployment.md §3](../shell_deployment.md#3-production-environment-checklist). Reuse them exactly.

---

## 🛠 2. Technical Blueprint

### Repository files

| Path | Action | Why |
| :--- | :--- | :--- |
| `shell/src/pages/healthz.ts` | **Add** | Dedicated health endpoint. The Shell has no `/healthz` today; `HEAD /` would run the full homepage (nav, optional Ghost fetch) and is a bad liveness probe. |
| `shell/Dockerfile` | **Change** | Add a `HEALTHCHECK` that hits `/healthz` so Compose and `docker ps` agree. |
| `infra/compose.yaml` | **Change** | Add service `shell`. Keep `caddy`. Still no forum/wiki/Ghost/Saleor/Keycloak. |
| `infra/Caddyfile` | **Change** | Replace apex `file_server` with `reverse_proxy shell:4321`. Keep `www`/`app` redirects. |
| `infra/caddy/placeholder.html` | **Keep** (unused by Caddy) or delete in this PR | Apex no longer serves it. Do not leave `file_server` as a fallback in front of the Shell. |
| `infra/.env.example` | **Change** | Append every Astro Shell variable from [shell_deployment.md §3](../shell_deployment.md#3-production-environment-checklist), plus `PARTS_API_URL` (optional, unused until Phase 3). |
| `infra/.env` | **Change on the host** | Copy new keys from `.env.example`. Placeholders are fine for Keycloak / Ghost / shop — those processes are **not started**. |
| `infra/README.md` | **Change** | Note the `shell` service and `/healthz`. |
| `.github/` | **Do not change** | Slice 8 publishes GHCR; this slice `build:`s on the host. |
| `forum/`, `wiki/`, `blog/`, `shop/` | **Do not change** | Never build **Submodules** in production. |

### Health endpoint (concrete choice)

**Use `GET /healthz` (and `HEAD /healthz`), not `HEAD /`.**

Add `shell/src/pages/healthz.ts` as an Astro endpoint:

```ts
import type { APIRoute } from "astro";

export const prerender = false;

export const GET: APIRoute = () =>
  new Response("ok\n", {
    status: 200,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });

export const HEAD: APIRoute = () =>
  new Response(null, {
    status: 200,
    headers: { "cache-control": "no-store" },
  });
```

Rules:

* No auth, no cookies, no fetch to forum/wiki/Ghost/Keycloak/Directus Parts API.
* Always `200` + `ok` if the Node process is up. Readiness of **Submodules** is not this probe's job.
* Publicly reachable at `https://stagea-stuff.com/healthz` (fine; no secrets).

`shell/Dockerfile` — append after `EXPOSE 4321`:

```dockerfile
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD wget -qO- http://127.0.0.1:4321/healthz || exit 1
```

`node:22-alpine` does not ship `wget`. Either (a) `apk add --no-cache wget` in the runner stage as root before `USER node`, or (b) use Node itself so the image stays minimal:

```dockerfile
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:4321/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
```

**Pick (b)** — no extra packages, Node 22 has `fetch`. Compose `healthcheck.test` must use the same command.

### Compose — `shell` service

```yaml
  shell:
    build:
      context: ../shell
      dockerfile: Dockerfile
    image: stagea-shell:local   # local tag until slice 8 switches to GHCR
    restart: unless-stopped
    # NO ports: — Caddy reaches it on the internal network only
    expose:
      - "4321"
    environment:
      NODE_ENV: ${NODE_ENV}
      HOST: ${HOST}
      PORT: ${PORT}
      PUBLIC_SITE_NAME: ${PUBLIC_SITE_NAME}
      FORUM_URL: ${FORUM_URL}
      WIKI_URL: ${WIKI_URL}
      BLOG_URL: ${BLOG_URL}
      SHOP_URL: ${SHOP_URL}
      AUTH_ISSUER_URL: ${AUTH_ISSUER_URL}
      AUTH_CLIENT_ID: ${AUTH_CLIENT_ID}
      AUTH_CLIENT_SECRET: ${AUTH_CLIENT_SECRET}
      GHOST_CONTENT_API_KEY: ${GHOST_CONTENT_API_KEY}
    env_file:
      - .env
    networks: [stagea-net]
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://127.0.0.1:4321/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 25s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
    # stateless — no named volumes
```

Caddy already joins `stagea-net`. Add `depends_on: { shell: { condition: service_healthy } }` on `caddy` so a reload does not race an empty upstream. Caddy still has the only `ports:`.

### Caddy routes (slice 3)

```caddy
stagea-stuff.com {
    reverse_proxy shell:4321
    header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}

www.stagea-stuff.com {
    redir https://stagea-stuff.com{uri} permanent
}

app.stagea-stuff.com {
    redir https://stagea-stuff.com{uri} permanent
}
```

Caddy sets `X-Forwarded-For`, `X-Forwarded-Proto`, and `Host` by default. That is required so the Astro Shell will accept `Secure` session cookies later — see [shell_deployment.md §2](../shell_deployment.md#2-reverse-proxy-configuration-nginx-ingress). Do not add a second proxy.

### Env vars (append to `infra/.env.example`)

Reuse these names exactly ([shell_deployment.md §3](../shell_deployment.md#3-production-environment-checklist)):

| Variable | Phase 1 value | Notes |
| :--- | :--- | :--- |
| `NODE_ENV` | `production` | |
| `HOST` | `0.0.0.0` | Bind inside the container. |
| `PORT` | `4321` | Container-internal only. |
| `PUBLIC_SITE_NAME` | `Stagea Community` | |
| `FORUM_URL` | `https://forum.stagea-stuff.com/` | Public URL for nav; forum process starts in slice 4. |
| `WIKI_URL` | `https://wiki.stagea-stuff.com/` | Public URL for nav; wiki process starts in slice 5. |
| `BLOG_URL` | `https://blog.stagea-stuff.com/` | Placeholder URL only. **Do not start Ghost.** |
| `SHOP_URL` | `https://shop.stagea-stuff.com/` | Placeholder URL only. **Do not start Saleor.** |
| `AUTH_ISSUER_URL` | `https://auth.stagea-stuff.com/realms/stagea` | Placeholder. **Do not start the Keycloak OIDC IdP.** Schema is optional; Shell boots without it. |
| `AUTH_CLIENT_ID` | `shell-client` | Placeholder. |
| `AUTH_CLIENT_SECRET` | `change-me` | Placeholder secret; real value in Phase 3. |
| `GHOST_CONTENT_API_KEY` | `change-me` | Placeholder; real value in slice 9. |
| `PARTS_API_URL` | (commented or empty) | Directus Parts API — Phase 3. Optional in `astro.config.mjs`. |

`ACME_EMAIL` remains from slice 2.

### Health checks

| Check | Command / expect |
| :--- | :--- |
| Container | `docker compose -f infra/compose.yaml --env-file infra/.env ps` → `shell` and `caddy` are `healthy` |
| Public | `curl -fsS https://stagea-stuff.com/healthz` → `ok` |
| Apex HTML | `curl -fsS https://stagea-stuff.com` → real Astro Shell HTML (not the slice 2 placeholder) |
| Forwarded proto | Shell logs or a temporary debug header / SSR check that the request is treated as HTTPS (`X-Forwarded-Proto: https`). Caddy default; fail the slice if cookies would be marked insecure. |
| Restart | `docker compose -f infra/compose.yaml --env-file infra/.env restart shell` — `/healthz` returns `ok` again without a manual `up`. |

### Image pin

| Service | Source | Pin |
| :--- | :--- | :--- |
| `shell` | `build: ../shell` + `image: stagea-shell:local` | Only repo-built image. Builder/runner base in `shell/Dockerfile` is already `node:22-alpine` — pin that digest or minor in a follow-up if the Dockerfile still floats; do not switch to `:latest`. |
| `caddy` | official | unchanged from slice 2 |

---

## 📋 3. MVP Acceptance Criteria

From [production_plan.md §7 slice 3](../production_plan.md#slice-3--shell-edge-online):

1. **Demo**: `https://stagea-stuff.com` serves the real Astro Shell, server-rendered (view-source shows the landing markup, not an empty SPA shell).
2. **Test**: `docker compose ps` shows `shell` `healthy`; the Shell receives `X-Forwarded-Proto: https`; `restart shell` recovers automatically.
3. `https://stagea-stuff.com/healthz` returns `200` and `ok` with no auth.
4. `www` and `app` still redirect to apex.
5. `shell` has **no** `ports:` mapping. `ss -lntp` / `docker compose ps` show host `80`/`443` on Caddy only.
6. `infra/.env.example` lists every Shell variable from [shell_deployment.md §3](../shell_deployment.md#3-production-environment-checklist).
7. Compose still has no Ghost, Saleor, Keycloak OIDC IdP, or Directus Parts API service.
8. Escape hatch still starts the stack: `docker compose -f infra/compose.yaml --env-file infra/.env up -d`.

---

## 🚦 4. 6-Step Feature Loop Checklist

See [docs/shell/TODO.md §1](../../shell/TODO.md#1-the-6-step-developer-feature-loop).

- [ ] **1. Scaffold**: Add `shell/src/pages/healthz.ts` returning `ok`. Leave Compose/Caddy edits for Implement after the endpoint exists locally (`pnpm --dir shell dev`, curl `/healthz`).
- [ ] **2. Document**: Update `infra/README.md`. Do not copy the service map; link [production_plan.md §3](../production_plan.md#3-service-map).
- [ ] **3. MVP Spec**: The eight acceptance criteria above.
- [ ] **4. Test**: Add a small Astro/Vitest or `curl` check that `GET /healthz` is `200` and does not import auth/search. Optionally `pnpm --dir shell check` after the new page.
- [ ] **5. Implement**: Dockerfile `HEALTHCHECK`, Compose `shell` service, Caddy `reverse_proxy`, `.env.example` inventory, host `.env` fill.
- [ ] **6. Review**: `pnpm --dir shell check && pnpm --dir shell build`. Confirm no Submodule build, no extra host ports, no Keycloak/Ghost/Saleor containers.

---

## 🚫 5. Explicit Non-Goals

* Starting Ghost, Saleor, the Keycloak OIDC IdP, or the Directus Parts API.
* Publishing the Shell on a host port (`4321:4321`).
* Serving the Shell on `app.` instead of the apex (apex is the plan of record; `app` redirects).
* Building **Submodules**.
* Writing `infra/deploy.sh` (slice 6).
* Switching Compose from `build:` to GHCR (slice 8).
* OIDC login on the live site (Phase 3).

---

## 🔗 6. Depends On

[Slice 2 — Edge Skeleton](./slice_02_edge_skeleton.md) must be green: Caddy healthy, production (not staging) cert on the apex, `www`/`app` redirects, `infra/.env` present and gitignored.
