// @ts-check
import { defineConfig, envField } from "astro/config";
import node from "@astrojs/node";
import tailwindcss from "@tailwindcss/vite";

// Stagea community shell. SSR-first so that future /account, /search, and
// /api/* endpoints can run server logic. Static pages are still pre-rendered
// where they make sense (set `export const prerender = true` per page).
export default defineConfig({
  site: "https://stagea-stuff.com",
  output: "server",
  adapter: node({ mode: "standalone" }),
  server: {
    host: "127.0.0.1",
    port: 4321,
  },
  vite: {
    plugins: [tailwindcss()],
  },
  // Environment contract. Add real entries when login/search land; for now
  // the placeholder PUBLIC_SITE_NAME proves the schema works end-to-end.
  env: {
    schema: {
      PUBLIC_SITE_NAME: envField.string({
        context: "client",
        access: "public",
        default: "Stagea",
      }),
      // Future entries (kept here as documentation, commented out until used):
      //   AUTH_ISSUER_URL: envField.string({ context: "server", access: "secret" }),
      //   AUTH_CLIENT_ID:  envField.string({ context: "server", access: "public" }),
      //   AUTH_CLIENT_SECRET: envField.string({ context: "server", access: "secret" }),
      //   SEARCH_API_URL:  envField.string({ context: "server", access: "public" }),
    },
  },
});
