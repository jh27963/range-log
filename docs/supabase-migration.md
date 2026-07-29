# Migrating off Notion to Supabase

Not started. This is the plan for when it happens — written while the Notion
version is still the live one, so treat anything here as a proposal to revisit,
not a spec already agreed to.

**Why:** every other project of yours lives in Supabase. Notion's SQL-via-MCP
layer can't see formulas/rollups (`On Hand (Calc)`, `Lifetime Rounds`, etc.),
so every query already has to recompute them from the fact tables — that's a
real Postgres schema fighting to get out. Doing this now, while the schema
issues in `docs/backlog.md` are already being looked at, means fixing them
once instead of once in Notion and again in Postgres.

**Why not now:** this touches every layer — schema, Worker, app, every saved
query — and today's task was just getting the current version shipped. Full
scope below.

---

## 1. Schema

Same shape as `docs/schema.md`, but relations become real foreign keys and
rollups/formulas become views (or generated columns) instead of app-side
recomputation.

```sql
create table firearms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text,
  caliber text,
  make text,
  model text,
  purchase_date date,
  last_cleaned date
);

create table ammunition_inventory (
  id uuid primary key default gen_random_uuid(),
  caliber text not null,
  low_stock_alert integer,
  notes text
);

create table range_sessions (
  id uuid primary key default gen_random_uuid(),
  firearm_id uuid not null references firearms(id),
  ammo_stock_id uuid not null references ammunition_inventory(id),
  date date not null,
  caliber text,        -- kept denormalized, same rationale as today
  rounds_fired integer not null,
  ammo_type text,
  distance_yds integer,
  accuracy text,
  target_type text,
  notes text
);

create table ammo_purchases (
  id uuid primary key default gen_random_uuid(),
  stock_id uuid not null references ammunition_inventory(id),
  date date not null,
  caliber text,
  rounds integer not null,
  total_cost numeric not null,
  ammo_type text,
  brand text,
  vendor text,
  notes text
);
```

`Gun` / `Ammo Stock` / `Stock` become `NOT NULL` foreign keys instead of
optional relations — this is the fix for backlog item "session with blank
Ammo Stock silently drops out of rollups." A missing relation becomes an
insert-time error instead of a silent data bug.

Rollups become a view:

```sql
create view ammunition_inventory_calc as
select
  i.*,
  coalesce(p.total_purchased, 0) as total_purchased,
  coalesce(s.total_fired, 0) as total_rounds_fired,
  coalesce(p.total_purchased, 0) - coalesce(s.total_fired, 0) as on_hand,
  coalesce(p.total_spent, 0) as total_spent
from ammunition_inventory i
left join (select stock_id, sum(rounds) total_purchased, sum(total_cost) total_spent
           from ammo_purchases group by stock_id) p on p.stock_id = i.id
left join (select ammo_stock_id, sum(rounds_fired) total_fired
           from range_sessions group by ammo_stock_id) s on s.ammo_stock_id = i.id;
```

Same pattern for `firearms_calc` (lifetime rounds, range trips, last fired).

**Synthetic data:** keep the `Reconstructed —` tagging convention in `notes`
on migrated rows rather than dropping the synthetic history — the balances
depend on the full purchase ledger being present, and `sql/real-sessions.sql`
already knows how to filter it out.

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

1. Stand up the schema in a Supabase project.
2. One-time export: pull every row from all 4 Notion data sources (via the
   existing MCP SQL access) and insert into the new tables, preserving IDs
   only where useful (Notion page IDs don't need to survive; the FK
   relationships do).
3. Reconcile before cutover: compare `On Hand (Calc)` per caliber in Notion
   against `ammunition_inventory_calc.on_hand` in Supabase. They must match
   exactly before the old version is retired — this is the one number that
   actually matters.
4. Point the Worker at Supabase, redeploy, redeploy the app if endpoint
   shapes changed.
5. Leave Notion read-only (don't delete) for a few weeks as a backup until
   confidence is high.

## Open questions for when this actually starts

- Keep Notion around as a read-only historical archive, or export and
  decommission it entirely?
- Same Supabase project as your other data, or a dedicated one for this?
- Does `docs/backlog.md`'s Notion cleanup items (dead column, junk rows) get
  fixed in Notion first, or just not carried over into the new schema at all?
