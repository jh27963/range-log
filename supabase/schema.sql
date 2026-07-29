-- Range Log Phase 1 schema — Supabase project ywblwmbaiplnphiqzalm.
-- Mirrors docs/schema.md's Notion relations as real foreign keys, and its
-- rollups/formulas as views instead of app-side recomputation. Every table
-- keeps a notion_id for traceability back to the source during migration.
-- This schema is not yet wired to the app or Worker — see docs/supabase-migration.md.

create table firearms (
  id uuid primary key default gen_random_uuid(),
  notion_id text unique not null,
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
  notion_id text unique not null,
  caliber text not null,
  low_stock_alert integer,
  notes text
);

create table range_sessions (
  id uuid primary key default gen_random_uuid(),
  notion_id text unique not null,
  firearm_id uuid not null references firearms(id),
  ammo_stock_id uuid not null references ammunition_inventory(id),
  date date not null,
  caliber text,
  rounds_fired integer not null,
  ammo_type text,
  distance_yds integer,
  accuracy text,
  target_type text,
  notes text
);

create table ammo_purchases (
  id uuid primary key default gen_random_uuid(),
  notion_id text unique not null,
  stock_id uuid not null references ammunition_inventory(id),
  date date not null,
  caliber text,
  rounds integer not null,
  total_cost numeric not null,
  cost_per_round numeric generated always as
    (case when rounds = 0 then null else total_cost / rounds end) stored,
  ammo_type text,
  brand text,
  vendor text,
  notes text
);

create view ammunition_inventory_calc
  with (security_invoker = on) as
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

create view firearms_calc
  with (security_invoker = on) as
select
  f.*,
  coalesce(s.lifetime_rounds, 0) as lifetime_rounds,
  coalesce(s.range_trips, 0) as range_trips,
  s.last_fired
from firearms f
left join (select firearm_id, sum(rounds_fired) lifetime_rounds,
                  count(*) range_trips, max(date) last_fired
           from range_sessions group by firearm_id) s on s.firearm_id = f.id;

alter table firearms enable row level security;
alter table ammunition_inventory enable row level security;
alter table range_sessions enable row level security;
alter table ammo_purchases enable row level security;

-- RLS is enabled with no policies yet — matches every other table in this
-- Supabase project. Access policies are a Phase 2 concern once the Worker
-- is rewritten to talk to Supabase and needs a specific role to read/write.
