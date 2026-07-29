# Range Log

A shooting-range tracker. Supabase (Postgres) holds the data, a Cloudflare
Worker holds the service-role key, and a single static HTML page is the app.

- **App:** https://range-log-app.pages.dev
- **Relay:** https://range-log.jd9hall.workers.dev
- **Notion:** [Range Log](https://app.notion.com/p/39ac22d42b50819c8be0f945805ffa57) — read-only historical backup, not part of the live path (see `docs/supabase-migration.md`)

---

## What it does

Log a range session from your phone: pick a gun, enter rounds fired. The app writes
a `range_sessions` row wired to the right gun and caliber. Log a purchase the same way.
Ammunition on-hand is never stored — it's computed as
`total purchased − total fired`, so the books always balance.

Under the hood it's four Postgres tables with foreign keys and two views
that compute the rollups. Two tables are append-only fact tables; nothing
is ever overwritten.

---

## Layout

```
CLAUDE.md          context for Claude Code — read this first
worker/worker.js   the relay: holds the service key, adds CORS, allowlists 4 endpoints
app/index.html     the entire front end. no build, no framework, no dependencies
supabase/schema.sql  the DDL — tables, views, RLS
sql/               saved queries + syntax notes
docs/schema.md     column-by-column reference and the ER diagram
docs/ids.md        every UUID in one place
docs/backlog.md    what's next
docs/supabase-migration.md  how (and why) this moved off Notion
```

---

## Setup

You need a Supabase project and a Cloudflare account. Both free.

**1. Supabase**

Apply `supabase/schema.sql` to a project (via the Supabase MCP `apply_migration`,
the SQL editor, or the CLI). Grab the `service_role` key from
Settings → API — that's what the Worker uses; never ship it to the browser.

**2. Worker**

Deploy `worker/worker.js` to Cloudflare Workers (`npx wrangler deploy` from
`worker/`). Set the service key as an **encrypted secret**, not a variable:

```
npx wrangler secret put SUPABASE_SERVICE_KEY
```

`SUPABASE_URL` and `ALLOWED_ORIGIN` (your app's exact origin, no trailing
slash, to lock the relay to your page) are plain vars in `wrangler.toml`.

Verify: `GET https://your-worker.workers.dev/` → `{"ok":true,...}`

**3. App**

Deploy `app/index.html` to Cloudflare Pages:

```
npx wrangler pages deploy app --project-name=your-project-name
```

Update the `RELAY` constant at the top of the `<script>` block if your
Worker URL differs.

On iOS: open in Safari → Share → Add to Home Screen. It runs full-screen.

---

## The one thing to understand

**Inventory is derived, not stored.**

```
on_hand = total_purchased − total_rounds_fired
```

Sessions and Purchases are append-only. The app never mutates the inventory table
— there's no `UPDATE`/`PATCH` path to it at all, by design.

---

## Querying

Plain Postgres against the Supabase project. In Claude Code:

> Run `sql/rounds-by-gun.sql`

Two things worth knowing:

- **`On Hand`, `Lifetime Rounds`, `Total Spent`, etc. are columns on the
  `_calc` views**, not formulas hidden from SQL — query
  `ammunition_inventory_calc` / `firearms_calc` directly for those.
- **Most of the session/purchase history is synthetic backfill** from
  before the migration, tagged `Reconstructed —` in `notes`.
  Filter it out with `WHERE notes NOT LIKE 'Reconstructed%' OR notes IS NULL`
  before drawing any conclusion. The *balances* are real; the *history* is a
  random number generator.

See `sql/README.md` for full details.

---

## Gotchas that cost time

**New endpoint = Worker change.** The relay allowlists exactly four routes.
Add a fifth call in the app without adding it to `ALLOWED` and you get a 403.

**CORS is exact-match.** `ALLOWED_ORIGIN` with a trailing slash will fail. So will
a stale URL after redeploying to a new Pages project.

**Relations are load-bearing.** `firearm_id` and `ammo_stock_id` on
`range_sessions` are `NOT NULL` — a session logged for a caliber with no
matching `ammunition_inventory` row is rejected at write time rather than
silently dropping out of a rollup. The app enforces this client-side too
(clear error message) before it ever hits the Worker.

**`notion_id` is nullable.** It's set on rows migrated from Notion, for
traceability — but every new row the live app writes has no Notion origin,
so don't make it required again.
