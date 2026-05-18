# `infra/`

Stagea-monorepo infrastructure glue. Lives in the parent repo so it can be edited and committed without touching any submodule.

## Files

### `homepage/`

A tiny static landing page that links to every service running on the host. Lets you treat `http://localhost:8090/` as the local-dev hub and click through to the forum, wiki, blog, shop, admins, and ops UIs without remembering individual ports.

Bring it up:

```/dev/null/homepage.sh#L1-2
cd infra/homepage && docker compose up -d
# open http://localhost:8090/
```

The container is `stagea-homepage` (`nginx:alpine`), bound to `8090:80`, and `restart: unless-stopped` so it comes back after a Docker Desktop restart. `index.html` is bind-mounted read-only, so edits are visible on browser refresh — no rebuild needed.

### `blog.override.yaml`

A Docker Compose override that resolves the host-port conflicts between Ghost's dev stack (`blog/compose.dev.yaml`) and the saleor-platform stack:

| Service | Upstream host port | After override |
| --- | --- | --- |
| Ghost Redis | `6379:6379` | unexposed (use `docker exec -it ghost-dev-redis redis-cli`) |
| Ghost mailpit SMTP | `1025:1025` | `11025:1025` |
| Ghost mailpit web UI | `8025:8025` | `18025:8025` |
| Ghost mailpit web UI (e2e) | `8026:8025` | `18026:8025` |

The override file uses Compose's `!override` tag to replace the inherited `ports:` lists rather than append to them, which is what allows the SMTP/web ports to move and the Redis port to disappear entirely.

### `blog-dev.sh`

Thin wrapper around `pnpm nx run ghost-monorepo:docker:dev` that:

1. `cd`s into `blog/`.
2. Sets `DEV_COMPOSE_FILES` to include both Ghost's chosen variant (`compose.dev.sqlite.yaml` by default) and `../infra/blog.override.yaml`.
3. Hands off to Nx, which orchestrates the full dev build.

Use it instead of `cd blog && pnpm dev:sqlite` whenever you want Ghost to run alongside the saleor-platform stack.

```/dev/null/usage.sh#L1-3
./infra/blog-dev.sh                # dev:sqlite (default)
./infra/blog-dev.sh dev            # MySQL variant
./infra/blog-dev.sh dev:mailgun    # Mailgun variant
```

## Future

The `site-plan.md` reserves this directory for the eventual root `compose.yaml`, per-edge `nginx/` configs, and TLS automation. As those land, document them here and update the README's "Repository Layout" table.
