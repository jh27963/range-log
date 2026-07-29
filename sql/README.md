# SQL

These run through the Notion MCP tool `notion-query-data-sources`. There is no SQL
*engine* behind Notion — the MCP layer translates SQL into API calls. Most of what
you'd expect works; the exceptions are listed below.

## Running one

In Claude Code, with the Notion MCP connected, just ask:

> Run `sql/rounds-by-gun.sql`

or paste the SQL directly. Results come back as JSON — one object per row, keys are
column names.

## Syntax rules

**`FROM` takes a `collection://` URI, quoted:**

```sql
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
```

**Column names need double quotes** — they contain spaces and dots.

**Date columns are prefixed.** The `Date` column is addressed as
`"date:Date:start"` — plain `"Date"` will not resolve.

**Formulas and rollups return nothing.** `On Hand (Calc)`, `Lifetime Rounds`,
`Total Purchased`, `Total Spent`, `Cost per Round`, `Last Fired`, `Range Trips` —
all invisible to SQL. Recompute them from the fact tables instead. Every query here
does exactly that.

## Works

`SELECT` · `WHERE` · `GROUP BY` · `ORDER BY` · `LIMIT` · `COUNT` · `SUM` · `AVG`
· `MIN` · `MAX` · arithmetic on aggregates · `IS NULL` / `IS NOT NULL` · `LIKE`

## Excluding synthetic history

371 of the session rows are generated backfill. To query only real sessions:

```sql
WHERE "Notes" NOT LIKE 'Reconstructed%'
```

Almost every analytical query you write should include this, or you're charting a
random number generator.

## Files

| File | What |
|---|---|
| `rounds-by-gun.sql` | lifetime rounds, trips, avg distance per weapon |
| `cost-by-caliber.sql` | spend and blended cost per round, per caliber |
| `inventory-reconcile.sql` | recompute on-hand from the fact tables; should match `On Hand (Calc)` |
| `real-sessions.sql` | only the sessions that actually happened |
| `rounds-by-month.sql` | consumption over time |
| `maintenance.sql` | rounds fired since each gun was last cleaned |
