-- Lifetime rounds, trips, and average distance per weapon.
-- firearms_calc already has these as rollup columns; this recomputes them
-- directly from the fact table, useful as a cross-check on the view.

SELECT
  f.name AS firearm,
  s.caliber,
  COUNT(*)               AS trips,
  SUM(s.rounds_fired)    AS rounds,
  AVG(s.distance_yds)    AS avg_distance
FROM range_sessions s
JOIN firearms f ON f.id = s.firearm_id
GROUP BY f.name, s.caliber
ORDER BY rounds DESC;
