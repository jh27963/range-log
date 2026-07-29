-- Consumption over time, by caliber, aggregated to the month.
-- Postgres has date_trunc, so — unlike the old Notion-SQL version — this
-- doesn't need a downstream aggregation step.

SELECT
  date_trunc('month', date)::date AS month,
  caliber,
  SUM(rounds_fired) AS rounds
FROM range_sessions
GROUP BY 1, caliber
ORDER BY month;
