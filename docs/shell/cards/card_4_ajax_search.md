# Sprint Card 4: AJAX Progressive Search Enhancement

## 🎯 1. Overview & Business Case
To deliver an premium, app-like user experience, the federated search page (`/search`) must load results smoothly and instantaneously. Currently, submitting a search triggers a full page refresh, which disrupts the user flow, clears text selections, and causes jarring layout shifts.

This card outlines the specifications to **progressive-enhance** the search page. It uses lightweight, client-side JavaScript to hijack search submissions, fetch results via AJAX in the background, and seamlessly swap out only the results container in-place, failing back to standard HTML SSR if JavaScript is disabled.

---

## 🛠 2. Technical Solution & Code Blueprint
We will embed an enhanced `<script>` block inside `shell/src/pages/search.astro`. It intercepts search submissions, requests the exact query url via `fetch`, parses the server-returned HTML stream using `DOMParser`, and patches the results container dynamically.

### Search Container Structuring
Wrap the search results block inside an explicit, queryable container:
```html
<!-- shell/src/pages/search.astro -->
<div id="search-viewport">
  <!-- Dynamic Results, Counts, and Empty State HTML goes here -->
</div>
```

### Progressive Script Blueprint
Append this script block to the bottom of `shell/src/pages/search.astro`:

```html
<script>
  // Wait for the DOM to load before binding event handlers
  document.addEventListener("DOMContentLoaded", () => {
    const form = document.querySelector("form");
    const input = document.querySelector('input[name="q"]') as HTMLInputElement;
    const viewport = document.getElementById("search-viewport");

    if (!form || !input || !viewport) return;

    form.addEventListener("submit", async (event) => {
      // 1. Hijack standard full-page browser navigation
      event.preventDefault();

      const query = input.value.trim();
      if (!query) return;

      // 2. Animate a loading placeholder state for premium feedback
      viewport.classList.add("opacity-40", "transition-opacity", "duration-200");

      // 3. Construct target query URL and update browser history in-place
      const targetUrl = new URL(window.location.href);
      targetUrl.searchParams.set("q", query);
      window.history.pushState(null, "", targetUrl.toString());

      try {
        // 4. Fetch the fully rendered SSR HTML of the target URL in the background
        const response = await fetch(targetUrl.toString());
        if (!response.ok) throw new Error("Search fetch failed.");

        const htmlString = await response.text();

        // 5. Parse the returned HTML string and swap out only the search viewport
        const parser = new DOMParser();
        const incomingDoc = parser.parseFromString(htmlString, "text/html");
        const incomingViewport = incomingDoc.getElementById("search-viewport");

        if (incomingViewport) {
          viewport.innerHTML = incomingViewport.innerHTML;
        }
      } catch (error) {
        console.error("[AJAX Search] Failed to progressive-fetch results:", error);
        // Fallback: Perform a standard navigation trigger on critical error
        window.location.href = targetUrl.toString();
      } finally {
        // 6. Clear loading state opacity filters
        viewport.classList.remove("opacity-40");
      }
    });
  });
</script>
```

---

## 📋 3. MVP Acceptance Criteria
1. Submitting a search with JS active fetches results **without** trigger-refreshing the browser window.
2. The browser URL bar updates dynamically to `?q=query` on form submit.
3. If JavaScript is disabled, the form falls back natively to standard, server-side rendered HTML search loops.
4. An elegant, subtle opacity transition (loading feedback) plays during AJAX fetches.

---

## 🚦 4. 6-Step Feature Loop Checklist
- [ ] **1. Scaffold**: Insert `id="search-viewport"` onto the results wrapper inside `search.astro`.
- [ ] **2. Document**: Record progressive enhancement design specs and transition states inside the local developer logs.
- [ ] **3. MVP Spec**: Establish transition opacity scales and DOM swap targets.
- [ ] **4. Test**: Assert that clicking search changes the URL bar without reloading the active layout structure.
- [ ] **5. Implement**: Write the JavaScript fetch, history manipulation, and DOMParser innerHTML mapping.
- [ ] **6. Review**: Perform auditing checks with JavaScript disabled to confirm absolute, standard HTML fallback operations.
