# Astro Shell — UX, Layout & Visual Guidelines

This document establishes the user experience (UX) foundations, performance-first loading constraints, mobile-first responsive guidelines, and consistent visual styling tokens for the Astro Shell (`shell/`) as the single brand wrapper of the Stagea community platform.

---

## 1. Core Visual Aesthetic & Theme Tokens

The Stagea platform enforces a dark, high-performance visual theme ("Stagea Carbon") accented with racing-inspired mechanical highlights.

```
┌────────────────────────────────────────────────────────┐
│                      Stagea Carbon                     │
├────────────────────────────────────────────────────────┤
│  Background: Deep Charcoal Carbon (#0a0c0f)            │
│  Borders: Dark Slate Grey (#1a1d24)                    │
│  Accents: High-visibility Mechanical Amber (#f59e0b)   │
└────────────────────────────────────────────────────────┘
```

### CSS Variable Variables (`shell/src/styles/global.css`)
Our core styling contract uses Tailwind CSS v4 variables to maintain absolute color and layout consistency:
* **`--color-bg`**: `rgb(10, 12, 15)` (Deep Charcoal Carbon base)
* **`--color-surface`**: `rgb(20, 24, 30)` (Slightly lighter panels and cards)
* **`--color-border`**: `rgb(26, 29, 36)` (Slim border definitions)
* **`--color-text`**: `rgb(255, 255, 255)` (Primary text output)
* **`--color-muted`**: `rgb(156, 163, 175)` (Lighter grey explanatory text)
* **`--color-accent`**: `rgb(245, 158, 11)` (Stagea Racing Mechanical Amber)
* **`--color-accent-soft`**: `rgba(245, 158, 11, 0.1)` (Amber tint used for badge backgrounds)

---

## 2. Performance-First Hydration & Speculative Loading

Performance is the single most important aspect of our user experience. A slow site is a broken site. We target a **100/100 Mobile Lighthouse Performance Score** by utilizing these technical constraints:

1. **HTML-First, Zero-JS by Default**: All landing and content pages are pre-rendered server-side. The page serves only raw, lightweight semantic HTML and styling assets. No client-side JS is loaded unless strictly necessary.
2. **Hover-Speculative Prefetching**: We configure Astro’s speculative loading engine inside `astro.config.mjs`. When a visitor hovers their cursor over a navigation link (such as the SSO Dashboard or Search box), the browser preloads that target route's assets in the background, resulting in immediate transition times upon clicking.
3. **No Layout Shift (CLS)**: All structural containers, image placeholders, and skeleton loaders declare explicit heights and aspect ratios to prevent jarring visual shifts during data loading.

---

## 3. Progressive Enhancement Layouts

Every interface input in the Shell is designed around **Progressive Enhancement**:

```
                       [ User Action Form Submit ]
                                    │
         ┌──────────────────────────┴──────────────────────────┐
         ▼                                                     ▼
┌─────────────────────────────────┐           ┌─────────────────────────────────┐
│     JavaScript is ACTIVE        │           │    JavaScript is DISABLED       │
├─────────────────────────────────┤           ├─────────────────────────────────┤
│  1. Hijack standard form submit │           │  1. Standard browser HTML post  │
│  2. Execute background fetch()   │           │  2. Server processes request    │
│  3. Swap inner HTML view        │           │  3. Serves fully-rendered page  │
│  4. Dynamic state animations    │           │  4. Robust baseline backup      │
└─────────────────────────────────┘           └─────────────────────────────────┘
```

* **Standard HTML Baselines**: All forms (including login submissions and search inputs) are backed by native `<form method="GET" action="...">` tags that function natively on basic HTML parsers.
* **JS Progressive Layering**: For modern browsers with active JS runtimes, we layer lightweight handlers to intercept form submissions, fetch payload changes asynchronously via AJAX, and seamlessly swap out container sections with smooth transitions, eliminating annoying full-page browser flashes.

---

## 4. Interaction Constraints & Loading States

To reduce perceived wait times, we enforce distinct interaction feedbacks:

* **Sub-Second Interactive Response**: All user clicks, form submissions, and toggle changes must trigger immediate feedback (such as displaying loading states, loading spinners, or opacity filters) in under `100ms`.
* **The Opacity Transition**: During background fetches (such as federated search runs), the active results container fades to `40%` opacity using Tailwind’s `transition-opacity duration-200` filters, keeping the user informed of active background operations.
* **Skeleton Cards**: Where data takes longer than `500ms` to load, render lightweight dark-surface skeleton mock cards containing subtle pulse animations (`animate-pulse`) to maintain spatial structure before data injection.

---

## 5. Multi-Tenant Consistency & SSO State Chrome

Since the platform links multiple independent backing sub-sites (forum, blog, wiki, shop) running on separate subdomains, the Astro Shell acts as the consistent visual "chrome" that anchors the user:

* **The Sticky Header Nav**: Rendered server-side on every route, maintaining an identical top bar across all sub-sites.
* **OIDC Dynamic Sign-In Badge**: The header tracks OIDC cookie state. If the user is unauthenticated, they see a clean, amber-tinted **Sign In** call-to-action. Once logged in, the badge resolves dynamically to a customized user profile launcher displaying their dynamic avatar.
* **Scoped Subdomain Badging**: In both the search results and the SSO Dashboard, clear, color-coded badge indicators are displayed to denote the target service source:
  * **Forum**: Purple badge
  * **Wiki**: Amber badge
  * **Blog**: Emerald badge
  * **Shop**: Sky-blue badge

---

## 6. Mobile-First Responsive Scaling

Every shell layout is constructed mobile-first using a fluid CSS Grid and Flexbox layout:

* **Tailwind Dynamic Grid Rules**: All grids utilize fluid responsive columns (e.g. `grid grid-cols-1 md:grid-cols-3 gap-6`), ensuring perfect readability on mobile phones, tablets, and widescreen desktop monitors.
* **Touch-Friendly Constraints**: Interactive buttons, navigation anchors, and inputs on mobile viewports must maintain a minimum hit boundary height of `44px` to accommodate comfortable thumb-taps.

---

## 🔗 Related Documentation & Compliance References

* 🧭 **[Platform Master Site-Plan](../site-plan.md)** — Overall multi-site architecture, subdomain map, and current monorepo statuses.
* ⭐️ **[System 12-Factor Compliance Audit](../12_factor_compliance.md)** — Comprehensive review of Stagea monorepo compliance with all twelve principles from 12factor.net.
* 🔐 **[Shell Security Architecture](./security.md)** — Security standards, OIDC secure cookie boundaries, network VPC insulation, and XSS sanitizers.
* 📋 **[Shell Sprint Backlog & TODO](./TODO.md)** — Active product features backlog and our 6-step vertical loop checklist.
