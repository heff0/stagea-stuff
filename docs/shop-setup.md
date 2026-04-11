# Shop (Saleor storefront)

The webstore frontend for **shop.stagea-stuff.com** lives in the **`shop/`** directory. It is the official [Saleor storefront](https://github.com/saleor/storefront) (“Paper”) integrated as a **Git submodule**, so upstream history stays tied to `github.com/saleor/storefront` while this repo tracks a pinned commit.

## Submodule setup

- **`shop/`** is registered as a submodule pointing at `https://github.com/saleor/storefront.git`.
- **`.gitmodules`** at the repo root defines the submodule path and URL.

After cloning this monorepo, you must initialize submodules (see below) or the `shop/` folder will be empty until you do.

## Working with the submodule

### Clone with submodules

```bash
git clone --recurse-submodules <repository-url>
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

### Update the storefront to a newer upstream revision

```bash
cd shop
git fetch origin
git checkout main
git pull
cd ..
git add shop
git commit -m "Bump shop submodule to latest Saleor storefront"
```

Use a branch or tag in `shop/` if you prefer to track something other than `main`.

## Deployment and environment

Deploy the Next.js app from **`shop/`** (see `shop/README.md` for scripts: `pnpm install`, `pnpm dev`, `pnpm build`).

Configure Saleor-related variables as in **`shop/.env.example`**. For production at **shop.stagea-stuff.com**, set at least:

| Variable | Purpose |
| -------- | ------- |
| `NEXT_PUBLIC_SALEOR_API_URL` | Saleor GraphQL endpoint (include trailing slash as in the example). |
| `NEXT_PUBLIC_DEFAULT_CHANNEL` | Channel slug from Saleor Dashboard → Configuration → Channels. |
| `NEXT_PUBLIC_STOREFRONT_URL` | Public URL of this storefront, e.g. `https://shop.stagea-stuff.com`. |

Optional variables (multi-channel builds, webhooks, etc.) are documented in the upstream README and `shop/.env.example`.

## Quick local start (after submodule init)

```bash
cd shop
cp .env.example .env
# Edit .env with your Saleor API URL and channel
pnpm install
pnpm dev
```

Open the URL shown in the terminal (default [http://localhost:3000](http://localhost:3000)).
