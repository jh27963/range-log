# Range Log

A shooting-range tracker. Notion holds the data, a Cloudflare Worker holds the
token, and a single static HTML page is the app.

- **App:** https://range-log-app-v5.netlify.app
- **Relay:** https://range-log.jd9hall.workers.dev
- **Notion:** [Range Log](https://app.notion.com/p/39ac22d42b50819c8be0f945805ffa57)

---

## What it does

Log a range session from your phone: pick a gun, enter rounds fired. The app writes
a Sessions row wired to the right gun and caliber. Log a purchase the same way.
Ammunition on-hand is never stored — it's computed as
`total purchased − total fired`, so the books always balance.

Under the hood it's four Notion databases with relations and rollups. Two are
append-only fact tables; nothing is ever overwritten.

---

## Layout

```
CLAUDE.md          context for Claude Code — read this first
worker/worker.js   the relay: holds the token, adds CORS, allowlists 3 endpoints
app/index.html     the entire front end. no build, no framework, no dependencies
sql/               saved queries + syntax notes
docs/schema.md     column-by-column reference and the ER diagram
docs/ids.md        every UUID in one place
docs/backlog.md    what's next
```

---

## Setup

You need a Notion integration token and a Cloudflare account. Both free.

**1. Notion integration**

Create one at [notion.so/my-integrations](https://www.notion.so/my-integrations)
with read/update/insert capabilities. Then **share the Range Log page with it** —
Notion → page → ••• → Connections → connect. Without this the token sees nothing.

**2. Worker**

Deploy `worker/worker.js` to Cloudflare Workers. Then set the token as an
**encrypted secret**, not a variable:

```
Settings → Variables and Secrets → Add
  Name:  NOTION_TOKEN
  Type:  Secret
  Value: ntn_...
```

Optionally add a plain variable `ALLOWED_ORIGIN` set to your app's exact origin
(no trailing slash) to lock the relay to your page.

Verify: `GET https://your-worker.workers.dev/` → `{"ok":true,...}`

**3. App**

Deploy `app/index.html` to any static host. Netlify Drop works from a phone;
Cloudflare Pages needs a desktop. Update the `RELAY` constant at the top of the
`<script>` block if your Worker URL differs.

On iOS: open in Safari → Share → Add to Home Screen. It runs full-screen.

---

## The one thing to understand

**Inventory is derived, not stored.**

```
On Hand (Calc) = Total Purchased − Total Rounds Fired
```

Sessions and Purchases are append-only. The app never mutates the inventory table.
An earlier version did — it kept a `Rounds on Hand` number and decremented it on
each session — and that field is still sitting in Notion, dead. Delete it, don't
revive it.

If you're about to write a `PATCH` against Ammunition Inventory, you're about to
undo the migration.

---

## Querying

The Notion MCP accepts SQL. In Claude Code:

> Run `sql/rounds-by-gun.sql`

Two things that will bite you:

- **Formulas and rollups are invisible to SQL.** `On Hand (Calc)`,
  `Lifetime Rounds`, `Total Spent` — none of them come back. Recompute from the
  fact tables. Every query in `sql/` does this.
- **371 of ~373 sessions are synthetic**, tagged `Reconstructed —` in Notes.
  Filter them out with `WHERE "Notes" NOT LIKE 'Reconstructed%'` before drawing
  any conclusion. The *balances* are real; the *history* is a random number
  generator.

See `sql/README.md` for full syntax notes.

---

## Gotchas that cost time

**Data sources, not databases.** Notion API `2025-09-03` queries
`/v1/data_sources/{id}/query`. The old `/v1/databases/{id}/query` returns
"Invalid request URL." Database IDs and data source IDs are different UUIDs.

**New endpoint = Worker change.** The relay allowlists exactly three routes.
Add a fourth call in the app without adding it to `ALLOWED` and you get a 403 that
looks like a Notion error but isn't.

**CORS is exact-match.** `ALLOWED_ORIGIN` with a trailing slash will fail. So will
a stale URL after redeploying to a new Netlify site.

**Relations are load-bearing.** A session with a blank `Ammo Stock` silently drops
out of every rollup. The inventory number goes quietly wrong. Always set both
relations on write.
