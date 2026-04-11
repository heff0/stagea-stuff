# 🧱 Monorepo Architecture: Car Community Platform

## Goals

- Permissive licensing (MIT / Apache 2.0 / BSD)
- Lightweight, Docker-first deployment
- Modern UX (fast, SSR where useful)
- Clean SSO across all services (OIDC)
- Modular + scalable (microfrontends via subdomains)

---

# 🌐 System Overview


app.example.com (Astro shell)
│
├── forum.example.com (Forum)
├── wiki.example.com (Wiki)
├── blog.example.com (Blog)
├── shop.example.com (Shop)
├── parts.example.com (Parts API / UI)
└── auth.example.com (Identity Provider)


---

# 🔐 Identity Layer

**Primary:** :contentReference[oaicite:0]{index=0}  
- Apache 2.0
- OpenID Connect (OIDC)
- Central auth for all services

---

> 💡 **Alternatives**
>
> - :contentReference[oaicite:1]{index=1} (Apache 2.0, more modular, less UI)
> - :contentReference[oaicite:2]{index=2} (modern, but GPL)
> - :contentReference[oaicite:3]{index=3} (Apache 2.0, SaaS-friendly)

---

# 🧩 Monorepo Structure


repo/
├── apps/
│ ├── shell/ # Astro wrapper (global nav)
│ ├── parts-ui/ # optional frontend for parts
│ └── adapters/
│ ├── forum/
│ ├── wiki/
│ ├── shop/
│ └── blog/
│
├── services/
│ ├── auth/ # Keycloak config
│ └── parts-api/ # Directus config
│
├── packages/
│ ├── ui/
│ ├── auth-client/
│ ├── api-client/
│ └── config/
│
├── infra/
│ ├── docker/
│ ├── nginx/
│ └── compose.yaml
│
├── turbo.json
├── pnpm-workspace.yaml
└── package.json


---

# 🌐 Shell (Global Wrapper)

**Primary:** :contentReference[oaicite:4]{index=4}  

### Responsibilities
- Global navigation
- Auth-aware UI
- Links to all subdomains
- Fast SSR/edge rendering

---

> 💡 **Alternatives**
>
> - :contentReference[oaicite:5]{index=5} (more dynamic, heavier)
> - :contentReference[oaicite:6]{index=6} (lightweight, modern)
> - :contentReference[oaicite:7]{index=7} (Vue ecosystem)
