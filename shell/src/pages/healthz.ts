import type { APIRoute } from "astro";

export const prerender = false;

export const GET: APIRoute = () =>
  new Response("ok\n", {
    status: 200,
    headers: {
      "content-type": "text/plain; charset=utf-8",
      "cache-control": "no-store",
    },
  });

export const HEAD: APIRoute = () =>
  new Response(null, {
    status: 200,
    headers: { "cache-control": "no-store" },
  });
