# Slice 5 — Wiki Node Online

**Status**: implemented in repo  
**Phase 1 go-live**: yes  
**Depends on**: [Slice 4 — Forum Node Online](./slice_04_forum_node_online.md)

---

## 🎯 1. Overview & Why This Increment

Add official MediaWiki plus MariaDB, persist `LocalSettings.php` in a named volume, and route `wiki.stagea-stuff.com`. After this slice, **Phase 1 is content-complete**: apex Astro Shell + forum + wiki are live.

**Submodules** (`wiki/`) stay unused. Production never builds MediaWiki from this repo.

---

## 🛠 2. Technical Blueprint

### Repository files

| Path | Action | Why |
| :--- | :--- | :--- |
| `infra/compose.yaml` | **Change** | Add `wiki` and `wiki-db`. No host `ports:` on either. |
| `infra/Caddyfile` | **Change** | Add `wiki.stagea-stuff.com` → `wiki:80`. |
| `infra/.env.example` | **Change** | Append MariaDB + MediaWiki DB keys. |
| `infra/.env` | **Change on the host** | Unique passwords (`openssl rand -base64 32`). Never reuse the forum Redis password. |
| `infra/README.md` | **Change** | Document installer + how `LocalSettings.php` lands in `wiki_config`. |
| `wiki/` | **Do not change** | **Submodule**. Official image only. |
| `infra/deploy.sh` | **Do not add** | Slice 6. |
| `.github/` | **Do not change** | |

Open item from [production_plan.md §10](../production_plan.md#10-open-items-for-the-implementation-pass): volume-persist `LocalSettings.php` vs a templated file in `infra/`. **This card picks volume persist** so secrets stay out of git and the installer output is the source of truth.

### Compose — service names

| Service | Image (pin; confirm at implement time) | Host ports | Volumes |
| :--- | :--- | :--- | :--- |
| `wiki` | official `mediawiki:1.43` (current LTS minor — never `:latest`) | none (`expose: ["80"]`) | `wiki_images`, `wiki_config` |
| `wiki-db` | official `mariadb:11.4` (LTS — never `:latest`) | none (`expose: ["3306"]`) | `wiki_db_data` |

```yaml
  wiki-db:
    image: mariadb:11.4
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: ${WIKI_DB_NAME}
      MARIADB_USER: ${WIKI_DB_USER}
      MARIADB_PASSWORD: ${WIKI_DB_PASSWORD}
      MARIADB_ROOT_PASSWORD: ${WIKI_DB_ROOT_PASSWORD}
    expose: ["3306"]
    volumes:
      - wiki_db_data:/var/lib/mysql
    networks: [stagea-net]
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    logging: { driver: json-file, options: { max-size: "10m", max-file: "3" } }

  wiki:
    image: mediawiki:1.43
    restart: unless-stopped
    depends_on:
      wiki-db:
        condition: service_healthy
    expose: ["80"]
    environment:
      # Official image uses the web installer; DB host is the Compose name:
      # host=wiki-db, name/user/password from .env
    volumes:
      - wiki_images:/var/www/html/images
      - wiki_config:/var/www/html   # see LocalSettings note below
    networks: [stagea-net]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://127.0.0.1/"]
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 45s
    logging: { driver: json-file, options: { max-size: "10m", max-file: "3" } }
```

**`wiki_config` mount:** the official image's docroot is `/var/www/html`. Mounting the *entire* docroot on a named volume is correct **only if** the volume is first populated from the image (Docker copies image contents into an empty named volume on first create). After first `up`, persist `LocalSettings.php` *inside that volume* (installer download → `docker compose cp` into the running container at `/var/www/html/LocalSettings.php`, or copy via a one-off). Subsequent restarts see the file. Do **not** commit `LocalSettings.php` to git.

If the implementer prefers a narrower mount, use `wiki_config` at `/var/www/html/LocalSettings.php` via a subpath or a tiny wrapper that copies `/persist/LocalSettings.php` into place — but the volume **name** must remain `wiki_config`.

Installer (one-time, human): open `https://wiki.stagea-stuff.com`, run the web installer, DB host `wiki-db`, name/user/password from `.env`. Download `LocalSettings.php` and persist it into `wiki_config` as above.

### Caddy routes (add)

```caddy
wiki.stagea-stuff.com {
    reverse_proxy wiki:80
    header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
}
```

Confirm `dig +short wiki.stagea-stuff.com` before reload.

### Env vars (append)

```bash
# Wiki (MediaWiki) — official image, not the wiki/ Submodule
WIKI_URL=https://wiki.stagea-stuff.com/
WIKI_DB_NAME=mediawiki
WIKI_DB_USER=wiki
WIKI_DB_PASSWORD=change-me
WIKI_DB_ROOT_PASSWORD=change-me
```

`WIKI_URL` already exists for the Astro Shell; keep a single key.

### Health checks

| Check | Expect |
| :--- | :--- |
| `wiki-db` | `healthy`; no host `:3306` |
| `wiki` | `healthy` after `LocalSettings.php` is in place; `https://wiki.stagea-stuff.com` is the wiki |
| Edit persist | An edit survives `down` (no `-v`) + escape-hatch `up -d` |
| Host reboot | After `sudo reboot`, Caddy + shell + forum + wiki return without a human (`restart: unless-stopped`) |
| Isolation | MariaDB unreachable from outside the VPS |

### Image pins

Official `mediawiki` and `mariadb` only. Never `build: ../wiki`. Never `:latest`.

---

## 📋 3. MVP Acceptance Criteria

From [production_plan.md §7 slice 5](../production_plan.md#slice-5--wiki-node-online):

1. **Demo**: `https://wiki.stagea-stuff.com` serves a wiki; an edit survives a redeploy (`down` without `-v`, then escape-hatch `up -d`).
2. **Test**: MariaDB is unreachable from outside; the wiki survives a host reboot unattended.
3. `LocalSettings.php` lives in `wiki_config`, not in git.
4. `wiki/` Submodule is not cloned, built, or bind-mounted.
5. Apex + forum still healthy. Phase 1 **content** is complete (deploy wrapper is slice 6).
6. No Ghost, Saleor, Keycloak OIDC IdP, or Directus Parts API services.
7. Escape hatch still deploys the whole Phase 1 *content* stack.

---

## 🚦 4. 6-Step Feature Loop Checklist

See [docs/shell/TODO.md §1](../../shell/TODO.md#1-the-6-step-developer-feature-loop).

- [ ] **1. Scaffold**: Draft `wiki` + `wiki-db` blocks and the Caddy site.
- [ ] **2. Document**: `infra/README.md` installer + `wiki_config` persist steps. Link [production_plan.md §5.5](../production_plan.md#55-per-application-bootstrap-one-time-interactive).
- [ ] **3. MVP Spec**: The seven acceptance criteria above.
- [ ] **4. Test**: Edit → `down` → `up -d` → edit present. External scan: `3306` closed. After implement: reboot test.
- [ ] **5. Implement**: Pin images, volumes, `.env` secrets, installer, persist `LocalSettings.php`.
- [ ] **6. Review**: No `down -v`. No Submodule build. No second database published. Ready for slice 6.

---

## 🚫 5. Explicit Non-Goals

* Building MediaWiki from `wiki/`.
* Host-publishing `80` (wiki) or `3306`.
* Committing `LocalSettings.php`.
* VisualEditor / extra extensions beyond a stock installer wiki.
* OIDC (slice 11).
* Ghost / blog (slice 9).
* `infra/deploy.sh` (slice 6).
* Backups (slice 7) — but do not use `down -v`.

---

## 🔗 6. Depends On

[Slice 4 — Forum Node Online](./slice_04_forum_node_online.md): internal-network + named-volume pattern proven, Caddy multi-site proven, DNS for `wiki` in place.
