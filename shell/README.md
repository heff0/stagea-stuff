# `shell/`

End-user-facing Stagea community shell. This is the application that will live at `app.stagea-stuff.com` (and serve as the marketing root for `stagea-stuff.com`). Per `docs/site-plan.md` §5, the shell owns:

- **Landing page** (this scaffold's `/`).
- **Global header / navbar** linking to every Stagea service.
- **Federated search** across forum / wiki / blog / shop  *— planned, not in this scaffold.*
- **OIDC session exchange** with the `auth/` Keycloak service  *— planned, not in this scaffold.*

## Stack

| Layer | Choice |
| --- | --- |
| Framework | Astro 6 (SSR via `@astrojs/node`, `mode: standalone`) |
| Language | TypeScript (`astro/tsconfigs/strict`) |
| Styling | Tailwind 4 via `@tailwindcss/vite` |
| Package manager | pnpm 10 (Corepack) |
| Node | 20 LTS or newer |

The Astro `node` adapter is in place so the future `/account`, `/search`, and `/api/*` routes can run server logic. Static pages still pre-render where useful — add `export const prerender = true;` to any page that doesn't need request-time data.

## What's in this scaffold

```/dev/null/layout.txt#L1-15
shell/
├── astro.config.mjs        # SSR + Tailwind + env schema (search/auth fields commented out)
├── package.json            # @stagea/shell, pnpm scripts
├── tsconfig.json           # extends astro/strict, ~/ path alias
├── .env.example            # documented env contract
├── public/
│   └── favicon.svg
└── src/
    ├── env.d.ts
    ├── styles/global.css   # Tailwind 4 entry + Stagea @theme tokens
    ├── components/
    │   └── Header.astro    # sticky global navbar (every page)
    ├── layouts/
    │   └── Layout.astro    # html/head/body/footer wrapper
    └── pages/
        ├── index.astro     # landing page (hero + service cards)
        ├── search.astro    # placeholder; no search yet
        └── account.astro   # placeholder; no login yet
```

## Routes

| Path | State | Description |
| --- | --- | --- |
| `/` | live | Hero + cards for forum / wiki / blog / shop |
| `/search` | placeholder | Reserved for federated search. UI exists, no backend wired |
| `/account` | placeholder | Reserved for OIDC login. UI exists, no backend wired |

The navbar links forum / wiki / blog / shop at their current `localhost:<port>` URLs. When a reverse-proxy edge lands in `infra/`, switch those to `/forum`, `/wiki`, `/blog`, `/shop` on the same origin.

## Running it

```/dev/null/dev.sh#L1-3
cd shell
pnpm install
pnpm dev        # http://localhost:4321/
```

Other scripts:

- `pnpm build` — produce `dist/server/entry.mjs` + `dist/client/`.
- `pnpm start` — `node ./dist/server/entry.mjs` (runs the standalone Node server).
- `pnpm preview` — run the build locally without `node` directly.
- `pnpm check` — `astro check` (type-check `.astro` + `.ts`).

## Planned: turning this into a real submodule

Right now `shell/` is a regular folder committed inside the parent monorepo. When the codebase is stable enough to extract:

1. `cd shell && git init && git add . && git commit -m "init"`
2. Create a `github.com/heff0/stagea-shell` repo, set it as `origin`, push `main`.
3. Back in the parent repo: `git rm -r --cached shell && git submodule add https://github.com/heff0/stagea-shell.git shell`.

At that point `shell/` joins `forum/`, `wiki/`, `blog/`, `shop/` as a tracked submodule with a pinned commit.
