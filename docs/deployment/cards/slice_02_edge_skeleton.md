# Slice 2 — Edge Skeleton

**Status**: implemented in repo  
**Phase 1 go-live**: yes  
**Depends on**: [Slice 1 — Host Baseline](./slice_01_host_baseline.md)

---

## 🎯 1. Overview & Why This Increment

Public TLS is the hardest infrastructure problem and the one most likely to rate-limit you if you get it wrong. This slice adds **exactly one** Compose service — Caddy — serving a static placeholder on the apex with a real Let's Encrypt certificate. `www` and `app` redirect to the apex so those names get certificates now, not in a later surprise ACME burst.

After this slice, every later service is "add a container + a Caddy `reverse_proxy` site." The edge never gets redesigned.

Service map (do not duplicate): [production_plan.md §3](../production_plan.md#3-service-map). Request path: [§4](../production_plan.md#4-request-path).

---

## 🛠 2. Technical Blueprint

### Repository files

| Path | Action | Why |
| :--- | :--- | :--- |
| `infra/compose.yaml` | **Add** | Single production Compose file. This slice: one service (`caddy`) only. |
| `infra/Caddyfile` | **Add** | Apex placeholder + `www`/`app` redirects. Bind-mounted read-only into Caddy. |
| `infra/caddy/placeholder.html` | **Add** | Static page Caddy serves on `https://stagea-stuff.com` until slice 3. |
| `infra/.env.example` | **Add** | Authoritative inventory. This slice: ACME + pin comments. Grow it in later slices; never invent a second inventory file. |
| `infra/.env` | **Create on the host only** | Copy from `.env.example`. `chmod 600`. Never commit. |
| `.gitignore` | **Confirm** | `/infra/.env` (slice 1). `git check-ignore -v infra/.env` must match. |
| `infra/README.md` | **Change** | Replace the "Future: root compose.yaml" note with: production Compose lives here; local `homepage/` is unchanged. |
| `docs/site-plan.md` §2 | **Change** (same PR as `infra/compose.yaml`) | Record the apex decision: Shell Edge on `stagea-stuff.com`; `app.stagea-stuff.com` is a permanent redirect to apex. See [production_plan.md §3](../production_plan.md#3-service-map). |
| `infra/deploy.sh` | **Do not add** | Slice 6. Use the escape hatch to start Caddy. |
| `shell/` | **Do not change** | Slice 3. |
| `.github/` | **Do not change** | Slice 8. |

### Compose — service names and network

```yaml
# infra/compose.yaml — slice 2 shape (implement this; do not leave extras)
name: stagea

networks:
  stagea-net:
    driver: bridge
    # internal: false — Caddy must reach the public internet for ACME.
    # Application services added later join this network and publish no host ports.

services:
  caddy:
    image: caddy:2.10-alpine   # pin; confirm tag on Docker Hub at implement time. Never :latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      # Optional: "443:443/udp" for HTTP/3. No other host ports. Ever.
    expose: []                 # ports: above are the only host bindings in the whole stack
    environment:
      ACME_EMAIL: ${ACME_EMAIL}
    env_file:
      - .env                   # relative to infra/ when using -f infra/compose.yaml from repo root, use infra/.env via --env-file
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy/placeholder.html:/usr/share/caddy/index.html:ro
      - caddy_data:/data
      - caddy_config:/config
    networks: [stagea-net]
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://127.0.0.1:2019/config/"]
      interval: 10s
      timeout: 3s
      retries: 5
      start_period: 15s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  caddy_data:
  caddy_config:
```

Invoke from the **repository root** (the contract slice 6 will wrap):

```bash
docker compose -f infra/compose.yaml --env-file infra/.env up -d
```

`env_file: .env` inside the Compose file is resolved relative to `infra/` (the Compose file's directory). The `--env-file infra/.env` flag interpolates `${ACME_EMAIL}` in the Compose file. Use both: flag for interpolation, `env_file` so the container sees `ACME_EMAIL`.

**Do not** add `shell`, `forum`, `forum-redis`, `wiki`, `wiki-db`, Ghost, Saleor, Keycloak, or Directus services.

### Caddy routes

```caddy
# infra/Caddyfile
{
    email {$ACME_EMAIL}
    # First run: uncomment the next line, obtain certs, then comment it and reload
    # acme_ca https://acme-staging-v02.api.letsencrypt.org/directory
}

stagea-stuff.com {
    root * /usr/share/caddy
    file_server
    header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}

www.stagea-stuff.com {
    redir https://stagea-stuff.com{uri} permanent
}

app.stagea-stuff.com {
    redir https://stagea-stuff.com{uri} permanent
}
```

Caddy provisions HTTP-01 certificates. DNS for `stagea-stuff.com`, `www`, and `app` must resolve to this host **before** the first `up` (slice 1). A failed ACME attempt can trip Let's Encrypt rate limits — use the staging CA for the first issuance, then switch to production and recreate/reload Caddy.

### Env vars (`infra/.env.example` — slice 2 inventory)

```bash
# Copy to infra/.env and fill in. chmod 600. Never commit infra/.env.

# Caddy Let's Encrypt account contact (required)
ACME_EMAIL=ops@example.com
```

Later slices **append** to this file. They do not create `infra/.env.production` or similar.

### Health checks

* Compose: Caddy admin API on `127.0.0.1:2019` as above (`healthy` in `docker compose ps`).
* Public: `curl -fsSI https://stagea-stuff.com` returns `200` and a valid certificate chain. `curl -fsSI http://stagea-stuff.com` returns `301`/`308` to `https://`.

### Image pin

| Service | Image | Pin rule |
| :--- | :--- | :--- |
| `caddy` | official `caddy` | `caddy:2.10-alpine` (or current `2.x-alpine` minor). Never `:latest`. |

Official image only. Do not `build:` Caddy.

---

## 📋 3. MVP Acceptance Criteria

From [production_plan.md §7 slice 2](../production_plan.md#slice-2--edge-skeleton):

1. **Demo**: `https://stagea-stuff.com` loads the placeholder over valid TLS; `http://` redirects to `https://`.
2. **Test**: `curl -vI https://stagea-stuff.com` (or SSL Labs) shows a valid chain. Response includes `Strict-Transport-Security`.
3. `https://www.stagea-stuff.com` and `https://app.stagea-stuff.com` redirect to `https://stagea-stuff.com` (preserve path).
4. `docker compose -f infra/compose.yaml --env-file infra/.env ps` shows only `caddy`, status `healthy`.
5. `docker compose -f infra/compose.yaml --env-file infra/.env config` lists no `ports` except Caddy `80`/`443`.
6. `caddy_data` volume exists after first successful issuance (account key + certs). Do not delete it.
7. `git check-ignore -v infra/.env` matches. `infra/.env.example` is tracked. `chmod 600 infra/.env` on the host.
8. Escape hatch alone is enough to start this slice (no `deploy.sh` yet).

---

## 🚦 4. 6-Step Feature Loop Checklist

See [docs/shell/TODO.md §1](../../shell/TODO.md#1-the-6-step-developer-feature-loop).

- [ ] **1. Scaffold**: Add empty-but-valid `infra/compose.yaml`, `infra/Caddyfile`, `infra/caddy/placeholder.html`, `infra/.env.example`.
- [ ] **2. Document**: Update `infra/README.md` and `docs/site-plan.md` §2 (apex vs `app.`). Link this card from the cards index (already listed).
- [ ] **3. MVP Spec**: The eight acceptance criteria above. One service only.
- [ ] **4. Test**: On the VPS, after DNS is green, `up -d` and run the `curl -vI` / redirect checks. Confirm `docker compose ps` is `healthy`.
- [ ] **5. Implement**: Pin `caddy:2.10-alpine`, wire volumes, healthcheck, logging, staging-then-production ACME.
- [ ] **6. Review**: No extra services, no host ports besides Caddy, no `:latest`, no committed `.env`, no nginx sitting in front of Caddy.

---

## 🚫 5. Explicit Non-Goals

* Adding the Astro Shell, forum, wiki, Ghost, Saleor, Keycloak OIDC IdP, or Directus Parts API.
* Writing `infra/deploy.sh` (slice 6).
* Building any **Submodule**.
* A second edge proxy (nginx from [shell_deployment.md](../shell_deployment.md) is a later hardening reference, not day-1).
* Wildcard DNS-01 certificates.
* Publishing Caddy's admin API (`:2019`) on the host.

---

## 🔗 6. Depends On

[Slice 1 — Host Baseline](./slice_01_host_baseline.md) must be demonstrably green: Docker + Compose v2, UFW allowing `80`/`443`, DNS for apex/`www`/`app` pointing at this host, `.gitignore` covering `infra/.env`.
