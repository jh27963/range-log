# Range Log

Personal shooting-range tracker. Notion is the database; a static HTML app is the
front end; a Cloudflare Worker sits between them holding the API token.

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
    - holds NOTION_TOKEN as an encrypted secret
    - adds CORS headers (Notion's API sends none)
    - allowlists exactly 3 endpoints
        |
        v
  Notion API  (version 2025-09-03)
        |
        v
  4 Notion databases
```

Nothing is bundled or compiled. `app/index.html` is deployed as-is.

---

## The data model — read this before touching anything

**Two append-only fact tables, one derived balance.**

```
Ammo Purchases  ──┐
                  ├──>  Ammunition Inventory
Range Sessions  ──┘      On Hand (Calc) = Total Purchased − Total Rounds Fired
```

Sessions and Purchases are the only things ever written. Inventory is *never*
mutated — its stock level is a formula over two rollups. This means the ledger
always reconciles and there is a full audit trail.

**This was a deliberate migration.** An earlier version had a mutable
`Rounds on Hand` number that the app decremented on each session. That is
denormalized and drifts. Do not reintroduce it. If you find yourself writing a
`PATCH` against Ammunition Inventory, stop — you are about to undo this.

### Relations are load-bearing

- `Range Sessions.Gun` → Firearms
- `Range Sessions.Ammo Stock` → Ammunition Inventory
- `Ammo Purchases.Stock` → Ammunition Inventory

Every rollup depends on these. A session row with a blank `Ammo Stock` silently
drops out of `Total Rounds Fired`, and the inventory number goes quietly wrong.
Always populate both relations on write.

---

## Notion API gotchas (each of these broke a build)

**Data sources, not databases.** As of API version `2025-09-03` you query
`/v1/data_sources/{id}/query`, not `/v1/databases/{id}/query`. Page creation
parents onto `{"type":"data_source_id","data_source_id":"..."}`. The database IDs
and data source IDs are *different UUIDs* — using the wrong one returns
"Invalid request URL."

**Formulas and rollups do not come back through SQL.** `On Hand (Calc)`,
`Lifetime Rounds`, `Total Purchased` etc. return nothing in a
`notion-query-data-sources` result. Read them via the REST API
(`properties["X"].formula.number` / `.rollup.number`), or recompute in the query.

**Date columns in SQL are prefixed:** `"date:Date:start"`, not `"Date"`.

**Rate limits are real.** Bulk writes need ~0.2–0.35s of spacing and retry with
backoff on 429/5xx. Do not fire hundreds of writes in a tight loop.

---

## History is mostly synthetic

371 of the ~373 session rows are **reconstructed backfill**, tagged in Notes as
`Reconstructed — auto-generated backfill`. They were generated to a spec (weekly
visits from Sept 2023, fixed rounds per caliber, ownership-gated) and the purchase
ledger was sized backward from a real safe count so the balances land on truth.

The *balances* are real. The *history* is not. Do not draw conclusions from
accuracy trends or distance distributions over the 2023–2026 window — that is a
random number generator, not a shooter. Only sessions from 2026-07-09 onward are
real.

Filter synthetic rows out with:

```sql
WHERE "Notes" NOT LIKE 'Reconstructed%'
```

---

## Layout

```
worker/worker.js      the relay. deploy to Cloudflare Workers.
app/index.html        the whole front end. deploy to any static host.
sql/*.sql             saved queries, runnable via the Notion MCP
docs/schema.md        full column-by-column reference
docs/ids.md           every UUID in one place
docs/backlog.md       what's next
```

---

## Working on this

**To query the data:** use the Notion MCP tool `notion-query-data-sources`. The
`sql/` directory has working examples — start there rather than guessing at syntax.

**To change the app:** edit `app/index.html` directly. No build. Redeploy by
dropping the file on the static host. If you add a new Notion endpoint, you must
also add it to the Worker's `ALLOWED` allowlist or it will 403.

**To change the schema:** the Notion MCP `notion-update-data-source` tool takes
SQL-ish DDL (`ADD COLUMN "X" ROLLUP('Relation','Target','sum')`). Update
`docs/schema.md` in the same commit.

**Secrets:** `NOTION_TOKEN` lives only as an encrypted Worker secret. It is not in
this repo and must never be. If it leaks, rotate at notion.so/my-integrations and
update the Worker secret — no code change needed.
