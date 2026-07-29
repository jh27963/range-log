-- Only sessions that actually happened.
-- Most rows from the original backfill are tagged "Reconstructed —".
-- Use this filter on any query you intend to draw conclusions from.

SELECT
  s.date,
  f.name AS firearm,
  s.caliber,
  s.rounds_fired,
  s.distance_yds,
  s.accuracy,
  s.target_type,
  s.notes
FROM range_sessions s
JOIN firearms f ON f.id = s.firearm_id
WHERE s.notes NOT LIKE 'Reconstructed%' OR s.notes IS NULL
ORDER BY s.date DESC;
