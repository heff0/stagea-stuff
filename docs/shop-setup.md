# Shop — Saleor Storefront (`shop/`)

The webstore frontend for `shop.stagea-stuff.com` lives in the `shop/` directory. It is the official [Saleor storefront "Paper"](https://github.com/saleor/storefront) integrated as a **Git submodule**, so upstream history stays tied to `github.com/saleor/storefront` while this repo tracks a pinned commit.

As of this writing, the pinned commit is `be64a695e57e9cca0fccb2a53ff774c25b0bd109` on the upstream `main` branch. The stack is Next.js 16, React 19, urql 4, Tailwind 3, and `@saleor/auth-sdk` 1.0.

## 1. Submodule Registration

- Path: `shop/`
- URL: `https://github.com/saleor/storefront.git`
- Declaration: the repo-root `.gitmodules` contains:

```/dev/null/gitmodules.ini#L1-3
[submodule "shop"]
	path = shop
	url = https://github.com/saleor/storefront.git
```

After cloning this monorepo without `--recurse-submodules`, the `shop/` folder will be a stub until you initialise submodules (next section).

## 2. Working With the Submodule

### 2.1 Clone With Submodules

```/dev/null/clone.sh#L1-2
git clone --recurse-submodules <repository-url> stagea-stuff
```

If you already cloned without submodules:

```/dev/null/init-submodules.sh#L1-1
git submodule update --init --recursive
```

### 2.2 Verify the Submodule

```/dev/null/verify.sh#L1-3
git submodule status shop
# Expected: be64a695e57e9cca0fccb2a53ff774c25b0bd109 shop (heads/main)
# A leading '-' means not initialised; a leading '+' means local commits ahead of the pin.
```

### 2.3 Bump to a Newer Upstream Revision

```/dev/null/bump.sh#L1-7
cd shop
git fetch origin
git checkout main
git pull --ff-only
cd ..
git add shop
git commit -m "chore(shop): bump submodule to saleor/storefront@<short-sha>"
```

If you want to track a tag or a maintenance branch instead of `main`, check that out in `shop/` before committing — the monorepo records whatever commit is currently checked out in the submodule, not a branch name.

## 3. Local Development

Required tools: Node.js 20 LTS and pnpm 10 (via `corepack enable`).

```/dev/null/dev.sh#L1-5
cd shop
cp .env.example .env        # then edit .env (see next section)
pnpm install                # runs `pnpm run generate:all` via the predev hook
pnpm dev                    # default port: http://localhost:3000
```

Other useful scripts defined in `shop/package.json`:

- `pnpm dev:webpack` — same as `pnpm dev` (webpack dev server).
- `pnpm dev:turbopack` — run Next's Turbopack dev server.
- `pnpm generate:all` — regenerate GraphQL types (`generate` + `generate:checkout`).
- `pnpm test` / `pnpm test:run` — Vitest.
- `pnpm lint` / `pnpm lint:fix` — ESLint.
- `pnpm knip` — unused-code check.

## 4. Required Environment Variables

Configure in `shop/.env`. The storefront does not ship its own Saleor backend — it talks to an external Saleor GraphQL endpoint.

| Variable | Required | Purpose |
| --- | --- | --- |
| `NEXT_PUBLIC_SALEOR_API_URL` | yes | Saleor GraphQL endpoint. Include the trailing slash exactly as in `.env.example`. |
| `NEXT_PUBLIC_DEFAULT_CHANNEL` | yes | Channel slug from Saleor Dashboard → Configuration → Channels. |
| `NEXT_PUBLIC_STOREFRONT_URL` | yes for prod | Public URL of this storefront, e.g. `https://shop.stagea-stuff.com`. Used for canonical URLs, sitemaps, and OG tags. |

Optional variables for webhooks, multi-channel builds, and Saleor Apps are documented in the upstream `shop/README.md` and the comments in `shop/.env.example`. Do not commit a populated `.env` file.

## 5. Production Deployment Notes

- Build with `pnpm build` and serve with `pnpm start`; point nginx at port 3000 and terminate TLS at the edge.
- The `predev`/`prebuild` hooks run `pnpm run generate:all`. If you are vendoring the build output into a container, make sure `.graphqlrc.ts` and the `src/**/*.graphql` files are present at build time, otherwise codegen will fail.
- `sharp` is listed under `pnpm.onlyBuiltDependencies` upstream in `blog/`; for `shop/` it is a direct dependency and must be installed on the deployment target's architecture (set `SHARP_IGNORE_GLOBAL_LIBVIPS=1` if you hit libvips mismatches).

## 6. Known Constraints

- `shop/` must not be edited and committed back into the Stagea monorepo. Upstream changes happen in `saleor/storefront`; this repo only records the pinned commit.
- Local `shop/` patches can live in `packages/shop-adapter/` (planned, not yet scaffolded) so the submodule pointer stays clean.
