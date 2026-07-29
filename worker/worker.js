/**
 * Range Log — Notion API relay
 *
 * Holds the Notion integration token server-side so it never ships to the browser,
 * and adds the CORS headers Notion's API does not send.
 *
 * Set NOTION_TOKEN as an encrypted Worker secret (do NOT hardcode it here):
 *   Workers & Pages > range-log > Settings > Variables > Add variable > Encrypt
 *
 * Optional: set ALLOWED_ORIGIN to the exact origin you serve the app from
 * (e.g. https://range-log.pages.dev) to lock the relay to your page only.
 */

const NOTION_VERSION = "2025-09-03";

// Only these Notion endpoints may be reached through the relay.
const ALLOWED = [
  { method: "POST",  pattern: /^\/v1\/data_sources\/[0-9a-f-]{32,36}\/query$/i },
  { method: "POST",  pattern: /^\/v1\/pages$/i },
  { method: "PATCH", pattern: /^\/v1\/pages\/[0-9a-f-]{32,36}$/i },
];

function corsHeaders(env) {
  return {
    "Access-Control-Allow-Origin": env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "GET,POST,PATCH,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
  };
}

function json(body, status, env) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(env) },
  });
}

export default {
  async fetch(request, env) {
    // Preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(env) });
    }

    if (!env.NOTION_TOKEN) {
      return json({ error: "NOTION_TOKEN secret is not set on this Worker." }, 500, env);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Health check — open this in a browser to confirm the Worker is live.
    if (path === "/" || path === "/health") {
      return json({ ok: true, service: "range-log relay" }, 200, env);
    }

    // Allowlist check: refuse anything we did not explicitly permit.
    const permitted = ALLOWED.some(
      (rule) => rule.method === request.method && rule.pattern.test(path)
    );
    if (!permitted) {
      return json({ error: `Not allowed: ${request.method} ${path}` }, 403, env);
    }

    // Forward to Notion with the token attached.
    const notionRes = await fetch("https://api.notion.com" + path + url.search, {
      method: request.method,
      headers: {
        "Authorization": `Bearer ${env.NOTION_TOKEN}`,
        "Notion-Version": NOTION_VERSION,
        "Content-Type": "application/json",
      },
      body: request.method === "GET" ? undefined : await request.text(),
    });

    const text = await notionRes.text();
    return new Response(text, {
      status: notionRes.status,
      headers: { "Content-Type": "application/json", ...corsHeaders(env) },
    });
  },
};
