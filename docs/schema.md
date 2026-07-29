# Schema

Live in Supabase (Postgres), project `ywblwmbaiplnphiqzalm`. Full DDL in
`supabase/schema.sql` — this is the readable version of that.

Four tables. Two are append-only fact tables (`range_sessions`,
`ammo_purchases`), two are dimension tables (`firearms`,
`ammunition_inventory`) whose interesting columns are computed by two
views (`firearms_calc`, `ammunition_inventory_calc`) rather than stored.

```
                    ┌──────────────────┐
                    │    firearms      │
                    │  (dimension)     │
                    │                  │
                    │ lifetime_rounds ◄┼──┐  firearms_calc
                    │ range_trips    ◄┼──┤  firearms_calc
                    │ last_fired     ◄┼──┤  firearms_calc
                    └──────────────────┘  │
                                          │ firearm_id
                    ┌──────────────────┐  │
                    │  range_sessions  ├──┘
                    │  (fact, append)  │
                    └────────┬─────────┘
                             │ ammo_stock_id
                             ▼
                    ┌──────────────────────┐
                    │ ammunition_inventory │
                    │    (dimension)       │
                    │                      │
                    │ total_rounds_fired ◄─┤ ammunition_inventory_calc
                    │ total_purchased    ◄─┤ ammunition_inventory_calc
                    │ total_spent        ◄─┤ ammunition_inventory_calc
                    │ on_hand              │ = total_purchased − total_rounds_fired
                    └──────────▲───────────┘
                               │ stock_id
                    ┌──────────┴───────┐
                    │  ammo_purchases  │
                    │  (fact, append)  │
                    └──────────────────┘
```

---

## `range_sessions` — fact table

One row per weapon fired per visit. Shooting three guns on one trip = three
rows sharing a date.

| Column | Type | Notes |
|---|---|---|
| id | uuid | primary key |
| notion_id | text | original Notion page ID, nullable — only set on rows migrated from Notion; rows created by the live app have no Notion origin |
| date | date | |
| caliber | text | Denormalized — see below |
| rounds_fired | number | |
| ammo_type | text | FMJ, JHP, Match Grade, Hollow Point, Soft Point, Other |
| distance_yds | number | |
| accuracy | text | Excellent, Good, Fair, Poor |
| target_type | text | |
| **firearm_id** | **FK → firearms, NOT NULL** | Drives all `firearms_calc` rollups |
| **ammo_stock_id** | **FK → ammunition_inventory, NOT NULL** | Drives `total_rounds_fired`. Required — this is the fix for a bug where a session with no ammo relation silently dropped out of every rollup in the Notion version |
| notes | text | Synthetic backfill rows are tagged `Reconstructed — ...` here |

## `ammo_purchases` — fact table

One row per buy.

| Column | Type | Notes |
|---|---|---|
| id | uuid | primary key |
| notion_id | text | nullable, same as above |
| date | date | |
| caliber | text | |
| rounds | number | |
| total_cost | numeric, NOT NULL | dollars — app defaults an unentered cost to 0 |
| cost_per_round | numeric, generated | `total_cost / rounds`, null-guarded |
| ammo_type | text | |
| brand | text | |
| vendor | text | |
| **stock_id** | **FK → ammunition_inventory, NOT NULL** | Drives `total_purchased` |
| notes | text | |

## `ammunition_inventory` — dimension

One row per caliber. **Never write to this table directly.** Everything
that matters is derived by the `ammunition_inventory_calc` view.

| Column | Type | Notes |
|---|---|---|
| id | uuid | primary key |
| notion_id | text | nullable |
| caliber | text, NOT NULL | |
| low_stock_alert | number | threshold; the only field you'd hand-edit |
| notes | text | |

`ammunition_inventory_calc` adds: `total_rounds_fired` (sum of
`rounds_fired` over related sessions), `total_purchased` (sum of `rounds`
over related purchases), `total_spent` (sum of `total_cost`), and
**`on_hand`** = `total_purchased − total_rounds_fired` — this is the stock
level, and it is never stored anywhere.

## `firearms` — dimension

One row per gun.

| Column | Type | Notes |
|---|---|---|
| id | uuid | primary key |
| notion_id | text | nullable |
| name | text, NOT NULL | |
| type | text | Pistol, Revolver, Rifle, Shotgun, AR/Modern Sporting, Rimfire, Other |
| caliber | text | |
| make | text | |
| model | text | |
| purchase_date | date | gates nothing anymore — was used to gate synthetic backfill generation, which is done |
| last_cleaned | date | pairs with `last_fired` for a maintenance signal (`sql/maintenance.sql`) |

`firearms_calc` adds: `lifetime_rounds` (sum of `rounds_fired` over related
sessions), `range_trips` (count of related sessions), `last_fired` (latest
session date).

---

## Deliberate denormalization

**`caliber` on `range_sessions` and `ammo_purchases`** duplicates the
caliber implied by the `firearm_id`/`stock_id` relation. Kept because
filtering/grouping on a plain column is simpler than joining every time,
and caliber never changes for a given gun or inventory row. Both are
write-once and set from the same source by the app, so they can't drift in
practice.

## Row-level security

RLS is enabled on all four tables with no policies defined — matches every
other table in this Supabase project. The Worker holds the `service_role`
key, which bypasses RLS entirely; there's no other consumer of this data
yet, so no policies are needed. Add policies here if that changes (e.g. a
second, less-trusted client reading directly).
