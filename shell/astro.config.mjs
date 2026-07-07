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
  // Environment contract. Declared variables are strictly typed and validated.
  // Using defaults for local dev lets the app start up with zero config, while
  // staging/production overrides can be injected via the environment (12-factor).
  env: {
    schema: {
      PUBLIC_SITE_NAME: envField.string({
        context: "client",
        access: "public",
        default: "Stagea",
      }),
      AUTH_ISSUER_URL: envField.string({
        context: "server",
        access: "secret",
        optional: true,
      }),
      AUTH_CLIENT_ID: envField.string({
        context: "server",
        access: "public",
        optional: true,
      }),
      AUTH_CLIENT_SECRET: envField.string({
        context: "server",
        access: "secret",
        optional: true,
      }),
      FORUM_URL: envField.string({
        context: "server",
        access: "public",
        default: "http://localhost:4567/",
      }),
      WIKI_URL: envField.string({
        context: "server",
        access: "public",
        default: "http://localhost:8080/w/",
      }),
      BLOG_URL: envField.string({
        context: "server",
        access: "public",
        default: "http://localhost:2368/",
      }),
      SHOP_URL: envField.string({
        context: "server",
        access: "public",
        default: "http://localhost:3000/",
      }),
      PARTS_API_URL: envField.string({
        context: "server",
        access: "public",
        optional: true,
      }),
      SEARCH_API_URL: envField.string({
        context: "server",
        access: "public",
        optional: true,
      }),
    },
  },
});
