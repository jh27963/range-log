# Range Log

Personal shooting-range tracker. Supabase (Postgres) is the database; a static
HTML app is the front end; a Cloudflare Worker sits between them holding the
service-role key. Ran on Notion until 2026-07-29 — see
`docs/supabase-migration.md` for why and how it moved, and the "Legacy"
section of `docs/ids.md` if you ever need to read the old Notion data.

Owner is a database person — prefers relational thinking, SQL, normalized schemas.
Talk to him that way. He is comfortable with schema discussions and will push back
on denormalized designs.

---

## Architecture

```
  iPhone / browser
        |
        v
  app/index.html            static page, no build step, no framework
        |  fetch()
        v
  Cloudflare Worker         range-log.jd9hall.workers.dev
    - holds SUPABASE_SERVICE_KEY as an encrypted secret
    - adds CORS headers (PostgREST doesn't send them by default)
    - allowlists exactly 4 endpoints
        |
        v
  Supabase (PostgREST)
        |
        v
  4 Postgres tables + 2 views
```

Nothing is bundled or compiled. `app/index.html` is deployed as-is, to
Cloudflare Pages.

---

## The data model — read this before touching anything

**Two append-only fact tables, one derived balance.**

```
ammo_purchases  ──┐
                  ├──>  ammunition_inventory
range_sessions  ──┘      on_hand = total_purchased − total_rounds_fired
```

Sessions and Purchases are the only things ever written. Inventory is *never*
mutated — its stock level is a view over two rollups. This means the ledger
always reconciles and there is a full audit trail.

**This was a deliberate migration** (twice, now — Notion had already been
through it once). Do not reintroduce a mutable on-hand number. If you find
yourself writing an `UPDATE` against `ammunition_inventory`, stop — you are
about to undo this.

### Relations are load-bearing

- `range_sessions.firearm_id` → `firearms`, **NOT NULL**
- `range_sessions.ammo_stock_id` → `ammunition_inventory`, **NOT NULL**
- `ammo_purchases.stock_id` → `ammunition_inventory`, **NOT NULL**

Every rollup depends on these. Because they're real foreign keys with `NOT
NULL`, a write with a missing relation is now rejected at insert time
instead of silently dropping out of a rollup — the app also validates this
client-side before it ever calls the Worker (a gun whose caliber has no
matching inventory row can't be logged, with a clear error instead of a
failed request).

---

## Working on this

**To query the data:** plain Postgres via the Supabase MCP `execute_sql`
tool. The `sql/` directory has working examples — start there.

**To change the app:** edit `app/index.html` directly. No build. Redeploy
with `npx wrangler pages deploy app --project-name=range-log-app`. If you
add a new Worker endpoint, add it to `ALLOWED` in `worker/worker.js` or it
403s.

**To change the schema:** apply DDL via the Supabase MCP `apply_migration`
tool (or the SQL editor). Update `supabase/schema.sql` and `docs/schema.md`
in the same commit.

**Secrets:** `SUPABASE_SERVICE_KEY` lives only as an encrypted Worker
secret, set via `npx wrangler secret put SUPABASE_SERVICE_KEY` from
`worker/`. It is not in this repo and must never be. If it leaks, rotate it
in the Supabase dashboard (Settings → API) and update the Worker secret —
no code change needed. `notion_id` on every table is nullable — only rows
migrated from Notion have one; don't make it required.

---

## History is mostly synthetic

Most of the session/purchase rows are **reconstructed backfill** from
before the Supabase migration, tagged in `notes` as
`Reconstructed — auto-generated backfill`. They were generated to a spec
(weekly visits from Sept 2023, fixed rounds per caliber, ownership-gated)
and the purchase ledger was sized backward from a real safe count so the
balances land on truth.

The *balances* are real. The *history* is not. Do not draw conclusions from
accuracy trends or distance distributions over the 2023–2026 window — that is a
random number generator, not a shooter. Only sessions from 2026-07-09 onward are
real.

Filter synthetic rows out with:

```sql
WHERE notes NOT LIKE 'Reconstructed%' OR notes IS NULL
```

---

## Layout

```
worker/worker.js      the relay. deploy to Cloudflare Workers.
app/index.html        the whole front end. deploy to Cloudflare Pages.
supabase/schema.sql   the DDL — tables, views, RLS.
sql/*.sql             saved queries, plain Postgres
docs/schema.md        full column-by-column reference
docs/ids.md           every UUID in one place
docs/backlog.md       what's next
docs/supabase-migration.md  how (and why) this moved off Notion
```

---

## Legacy: Notion API gotchas (kept for anyone reading the old data directly)

These applied to the Notion-backed version and are irrelevant to the live
app/Worker now, but matter if you ever query Notion directly (it's still
sitting there, read-only, as a backup).

**Data sources, not databases.** API version `2025-09-03` queries
`/v1/data_sources/{id}/query`, not `/v1/databases/{id}/query`.

**Formulas and rollups did not come back through Notion's SQL.** Recompute
from the fact tables, or read via the REST API's `.formula.number` /
`.rollup.number`. (Not a concern in Postgres — they're just columns on the
`_calc` views now.)

**Date columns in Notion SQL were prefixed:** `"date:Date:start"`, not
`"Date"`.
