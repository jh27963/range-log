# Migrating off Notion to Supabase

**Done — all 5 phases.** The app has been fully cut over to Supabase
(2026-07-29). Notion is untouched and left in place as a read-only
historical backup; nothing writes to it anymore. See `docs/schema.md` for
the live schema and `docs/ids.md` for the current endpoint/deployment
reference — this file is now a record of how the migration happened, not a
todo list.

**Why:** every other project of yours lives in Supabase. Notion's SQL-via-MCP
layer can't see formulas/rollups (`On Hand (Calc)`, `Lifetime Rounds`, etc.),
so every query already has to recompute them from the fact tables — that's a
real Postgres schema fighting to get out. Doing this now, while the schema
issues in `docs/backlog.md` are already being looked at, means fixing them
once instead of once in Notion and again in Postgres.

**Why not all at once:** this touches every layer — schema, Worker, app,
every saved query. Phase 1 (below) proves the data is portable and correct
without touching anything user-facing; phases 2-5 are a separate future
session.

## Phase 1 results (done)

- Supabase project: `ywblwmbaiplnphiqzalm` ("jh27963's Project" — the only
  project on the account, already used by `my-team`). No new project created.
- Schema applied — see `supabase/schema.sql` for the exact DDL, including a
  fix applied after the initial migration: both calc views needed
  `security_invoker = on` (Postgres/Supabase default for views is otherwise
  definer-like, which the security linter correctly flags as bypassing RLS
  on the underlying tables).
- Row counts loaded and verified: `firearms` 5, `ammunition_inventory` 4
  (junk rows — stray `.45 ACP`, empty untitled — excluded per
  `docs/backlog.md`), `ammo_purchases` 43, `range_sessions` 372. Every
  `firearm_id`/`ammo_stock_id`/`stock_id` foreign key resolved (0 unresolved).
- Reconciled exactly against the known-good numbers in
  `sql/inventory-reconcile.sql`: 9mm 600, .380 ACP 250, 5.56 NATO 570,
  .22 LR 750 — all four match.
- `get_advisors` (security) clean of new findings beyond the RLS-no-policy
  INFO level already present on every table in this project.

---

## 1. Schema (done — see `supabase/schema.sql`)

Same shape as `docs/schema.md`, but relations are real foreign keys and
rollups/formulas are views instead of app-side recomputation. Every table
also has a `notion_id text unique` column — the source-of-truth link back
to Notion, kept for traceability and idempotent re-import, not just a
migration artifact to drop later.

`Gun` / `Ammo Stock` / `Stock` are `NOT NULL` foreign keys instead of
optional relations — this is the fix for backlog item "session with blank
Ammo Stock silently drops out of rollups." A missing relation is now an
insert-time error instead of a silent data bug.

`ammo_purchases.cost_per_round` is a generated column (`total_cost / rounds`,
null-guarded), matching the Notion formula 1:1.

**Synthetic data:** the `Reconstructed —` tagging convention was preserved in
`notes` on migrated rows rather than dropping the synthetic history — the
balances depend on the full purchase ledger being present, and
`sql/real-sessions.sql` already knows how to filter it out.

## 2. The Worker (done)

Rewrote `worker/worker.js` to proxy Supabase instead of Notion — same
thin-relay shape (CORS, health check, method+path allowlist), following the
precedent in `my-team/worker/index.js` (plain `fetch()` to PostgREST with
the `service_role` key, no supabase-js dependency). Four routes: `GET
/firearms`, `GET /inventory` (both read the `_calc` views), `POST
/sessions`, `POST /purchases`. `SUPABASE_URL` is a plain `wrangler.toml`
var; `SUPABASE_SERVICE_KEY` is a Worker secret the user set himself so the
raw key never touched this conversation.

**Bug found during this rewrite:** all four tables had `notion_id text
unique NOT NULL` — fine for the migrated Notion rows, but it meant the live
app could never insert a *new* row, since new rows have no Notion origin.
Fixed with `alter table ... alter column notion_id drop not null` across
all four tables. `supabase/schema.sql` reflects the fix.

## 3. The app (done)

`app/index.html`'s data layer rewritten: the Notion property readers
(`pTitle`, `pRollNum`, etc.) and `DS_*` data-source constants are gone,
replaced by a plain `api()` helper hitting the four new routes and flat
JSON field access. **Behavior change, intentional:** logging a session now
requires a matching ammo-inventory row for the gun's caliber (blocked
client-side with a clear message otherwise) — `ammo_stock_id` is `NOT
NULL`, so this is enforcing at write-time what used to fail silently.
`ammo_purchases.total_cost` is also `NOT NULL`; the app defaults an
unentered cost to `0` rather than omitting the field. Copy fixes bundled in
since this code was already being touched: header subtitle, the Log tab's
stale "deducts rounds from inventory" footnote, the Guns tab footnote.

**App hosting moved from Netlify to Cloudflare Pages** (user's call,
matching every other project) — reused an existing `range-log-app` Pages
project rather than creating a new one. `https://range-log-app.pages.dev`
is now the one canonical URL; the old Netlify URL is retired (left alone,
not deleted, but no longer functional once the Worker stopped speaking
Notion's response shape) — this also closes the `docs/backlog.md` item
about settling on one URL.

## 4. Queries (done)

All 6 files in `sql/` rewritten as plain Postgres against the tables/views
above — no `collection://` prefix, no `"date:Date:start"` quoting, and two
files (`rounds-by-month.sql`, `maintenance.sql`) got strictly better:
`date_trunc` handles monthly aggregation in one query instead of a
downstream step, and the maintenance query joins all guns at once instead
of the old manual per-gun two-step (real foreign keys make the join
trivial). Every rewritten query was run once via `execute_sql` to confirm
it's valid.

## 5. Cutover (done)

Verified with a real round-trip before calling it done: `POST /sessions`
and `POST /purchases` via curl, then the same two writes again through the
actual deployed UI in a browser (gun/caliber dropdowns populated from live
data, on-hand numbers updated correctly, Guns tab reflected the new
session) — all test rows deleted afterward so real data stayed clean.
Notion is now read-only by consequence, not by a separate action: nothing
in the Worker talks to it anymore.

## Decisions made along the way

- Notion stays as a read-only historical backup — not deleted.
- Same Supabase project as the other data (only one exists on the account)
  — no dedicated project.
- The two known-junk Ammunition Inventory rows were excluded during the
  Phase 1 import rather than cleaned up in Notion first — Notion itself is
  untouched, start to finish.
- No dual-write / transition period — full rip-and-replace of the Worker's
  routing logic, redeploy is the cutover.
