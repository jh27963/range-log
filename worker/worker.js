/**
 * Range Log — Supabase relay
 *
 * Holds the Supabase service-role key server-side so it never ships to the browser,
 * and adds the CORS headers PostgREST does not send by default.
 *
 * Set SUPABASE_SERVICE_KEY as an encrypted Worker secret (do NOT hardcode it here):
 *   npx wrangler secret put SUPABASE_SERVICE_KEY   (from this worker/ directory)
 *
 * SUPABASE_URL and ALLOWED_ORIGIN are plain vars — see wrangler.toml.
 */

// Only these routes may be reached through the relay.
const ALLOWED = [
  { method: "GET",  path: "/firearms" },
  { method: "GET",  path: "/inventory" },
  { method: "POST", path: "/sessions" },
  { method: "POST", path: "/purchases" },
];

// Route -> PostgREST resource. GET routes read the `_calc` views (rollups
// computed as real columns); POST routes insert into the base tables.
const TARGET = {
  "GET /firearms":  "firearms_calc?select=*",
  "GET /inventory": "ammunition_inventory_calc?select=*",
  "POST /sessions":  "range_sessions",
  "POST /purchases": "ammo_purchases",
};

function corsHeaders(env) {
  return {
    "Access-Control-Allow-Origin": env.ALLOWED_ORIGIN || "*",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
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

    if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_KEY) {
      return json({ error: "SUPABASE_URL or SUPABASE_SERVICE_KEY is not set on this Worker." }, 500, env);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    // Health check — open this in a browser to confirm the Worker is live.
    if (path === "/" || path === "/health") {
      return json({ ok: true, service: "range-log relay" }, 200, env);
    }

    // Allowlist check: refuse anything we did not explicitly permit.
    const permitted = ALLOWED.some(
      (rule) => rule.method === request.method && rule.path === path
    );
    if (!permitted) {
      return json({ error: `Not allowed: ${request.method} ${path}` }, 403, env);
    }

    const target = TARGET[`${request.method} ${path}`];
    const headers = {
      apikey: env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
      "Content-Type": "application/json",
    };
    if (request.method === "POST") headers["Prefer"] = "return=representation";

    const sbRes = await fetch(`${env.SUPABASE_URL}/rest/v1/${target}`, {
      method: request.method,
      headers,
      body: request.method === "GET" ? undefined : await request.text(),
    });

    const text = await sbRes.text();
    return new Response(text, {
      status: sbRes.status,
      headers: { "Content-Type": "application/json", ...corsHeaders(env) },
    });
  },
};
