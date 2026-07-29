# Migrating off Notion to Supabase

**Phase 1 (schema + data + reconciliation) is done.** Phases 2-5 below
(Worker, app, queries, cutover) are not started — the live app is still
100% Notion-backed today. Nothing here changed the Worker or `app/index.html`.

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

## 2. The Worker

Your other Supabase project (`my-team/worker`) keeps a thin Cloudflare Worker
in front of Supabase rather than calling Supabase directly from the client —
same shape as `range-log`'s current relay. Follow that precedent: repurpose
`worker/worker.js` to hold the Supabase service-role key and proxy a small
allowlist of operations (insert session, insert purchase, read views), same
CORS/allowlist structure it already has. Don't switch to client-side
`anon` key + RLS unless there's a specific reason to diverge from the
`my-team` pattern.

## 3. The app

`app/index.html`'s `fetch()` calls change from Notion's page-creation shape
to plain inserts/selects against the Worker's new endpoints. The three
allowlisted routes get replaced with their Supabase equivalents (e.g.
`POST /sessions`, `POST /purchases`, `GET /inventory`). No framework, no
build step — same file, new payload shapes.

## 4. Queries

Rewrite `sql/*.sql` as plain Postgres against the views above. This is
strictly simpler than today — no `collection://` prefix, no
`"date:Date:start"` prefix quirk, and formulas/rollups actually come back
since they're just views now.

## 5. Migration + cutover

1. ~~Stand up the schema in a Supabase project.~~ Done.
2. ~~One-time export: pull every row from all 4 Notion data sources and
   insert into the new tables.~~ Done — 372 sessions, 43 purchases, 5
   firearms, 4 inventory rows. Notion page IDs preserved as `notion_id`
   rather than discarded (useful for auditing, not just migration plumbing).
3. ~~Reconcile before cutover.~~ Done — exact match, see Phase 1 results above.
4. **Not started:** point the Worker at Supabase, redeploy, redeploy the app
   if endpoint shapes changed.
5. **Not started:** leave Notion read-only (don't delete) for a few weeks as
   a backup until confidence is high in the new backend.

## Decisions made when Phase 1 started

- Notion stays as a read-only historical backup after cutover — not deleted,
  not decided later.
- Same Supabase project as your other data (only one exists on the account)
  — no dedicated project.
- The two known-junk Ammunition Inventory rows were excluded during import
  rather than cleaned up in Notion first — Notion itself is untouched.
