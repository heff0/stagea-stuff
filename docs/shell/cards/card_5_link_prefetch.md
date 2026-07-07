# Sprint Card 5: Astro Link Prefetching Optimization

## 🎯 1. Overview & Business Case
To maintain an elite, lightning-fast edge performance score, navigating between major shell views (such as moving from the home page to the Search box or the SSO Dashboard) must feel near-instantaneous. Standard navigations contain a delay during request-time server evaluation.

This card outlines the configuration to integrate **Astro's Native Speculative Prefetching Engine**. This loads target-route code bundles and static assets in the background immediately as a user hovers over navigation links, resulting in instant, zero-latency transitions when they click.

---

## 🛠 2. Technical Solution & Code Blueprint
We will activate prefetching globally inside `shell/astro.config.mjs` and selectively tag core structural links to be prefetched speculatively.

### 1. Enable Prefetching Globally in Astro
Modify `shell/astro.config.mjs` to register the prefetching configuration rules:

```javascript
// shell/astro.config.mjs
import { defineConfig } from "astro/config";

export default defineConfig({
  // ... other configs
  prefetch: {
    prefetchAll: false, // Do not prefetch every link automatically to save bandwidth
    defaultStrategy: 'hover' // Prefetch speculatively when a user hovers over a link
  }
});
```

### 2. Configure Speculative Prefetching in Core Links
By setting `prefetchAll: false`, we selectively opt-in core routes that we want to prefetch by appending the `data-astro-prefetch` attribute onto anchor (`<a>`) tags.

Modify `shell/src/components/Header.astro` and `shell/src/pages/index.astro` to prefetch high-traffic gateways:

```html
<!-- Example Header Link: prefetch when user hovers -->
<li>
  <a
    href="/search"
    data-astro-prefetch="hover"
    class="rounded-md px-3 py-1.5 text-sm transition hover:bg-neutral-800"
  >
    Search
  </a>
</li>

<!-- Example Dashboard Link: prefetch with viewport strategy -->
<!-- (Prefetches as soon as the link enters the user's visible viewport for super-high speed) -->
<a
  href="/account/dashboard"
  data-astro-prefetch="viewport"
  class="rounded-md bg-amber-500 px-4 py-2 text-sm font-medium text-neutral-950"
>
  Go to Dashboard
</a>
```

---

## 📋 3. MVP Acceptance Criteria
1. Navigation prefetching is activated globally in `astro.config.mjs` using `defaultStrategy: 'hover'`.
2. Hovering over the header "Search" or "Sign In" link automatically appends prefetch `<link rel="prefetch">` tags onto the HTML header in real-time.
3. Transition latency when clicking core shell routes is reduced from standard server-wait values down to under `50ms`.
4. Users on metered connections do not suffer heavy bandwidth overhead due to selective opt-in `data-astro-prefetch` tags.

---

## 🚦 4. 6-Step Feature Loop Checklist
- [ ] **1. Scaffold**: Add prefetch schemas to `astro.config.mjs` and opt-in attributes onto navigation anchors.
- [ ] **2. Document**: Record performance testing speeds and hover prefetch metrics in the local developer logs.
- [ ] **3. MVP Spec**: Formulate strategy classifications (hover, tap, viewport) for core anchor links.
- [ ] **4. Test**: Verify that hovering over a nav link triggers a parallel network fetch for that page's JS/HTML assets in the DevTools Network panel.
- [ ] **5. Implement**: Bind the prefetch controller inside `astro.config.mjs` and update layout anchor tags.
- [ ] **6. Review**: Perform Lighthouse audit runs to ensure the page load performance remains at a pristine 100/100 score.
