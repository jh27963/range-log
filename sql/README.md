# SQL

Plain Postgres, run against the Supabase project (`ywblwmbaiplnphiqzalm`) via
the `execute_sql` tool, or any Postgres client / the Supabase SQL editor.

## Running one

In Claude Code, with the Supabase MCP connected, just ask:

> Run `sql/rounds-by-gun.sql`

or paste the SQL directly. Results come back as JSON — one object per row, keys are
column names.

## The `_calc` views

`On Hand (Calc)`, `Lifetime Rounds`, `Total Purchased`, `Total Spent`,
`Range Trips`, `Last Fired` — everything that used to be a Notion
formula/rollup invisible to SQL is now just a column on
`ammunition_inventory_calc` / `firearms_calc`. Query those views directly
when you want the derived numbers; query the base tables + a join when you
want to recompute something yourself (several files here do the latter on
purpose, as a cross-check on the views).

## Excluding synthetic history

Most of the session and purchase rows are generated backfill from before
the Supabase migration, tagged `Reconstructed —` in `notes`. To query only
real sessions:

```sql
WHERE notes NOT LIKE 'Reconstructed%' OR notes IS NULL
```

(The `OR notes IS NULL` matters — a real session logged with no notes
would otherwise get swept out by `NOT LIKE` along with the synthetic rows.)
Almost every analytical query you write should include this, or you're
charting a random number generator.

## Files

| File | What |
|---|---|
| `rounds-by-gun.sql` | lifetime rounds, trips, avg distance per weapon |
| `cost-by-caliber.sql` | spend and blended cost per round, per caliber |
| `inventory-reconcile.sql` | recompute on-hand from the fact tables; should match `ammunition_inventory_calc.on_hand` |
| `real-sessions.sql` | only the sessions that actually happened |
| `rounds-by-month.sql` | consumption over time, aggregated by month |
| `maintenance.sql` | rounds fired since each gun was last cleaned |
