-- Rounds fired since each gun was last cleaned.
--
-- A real join against real foreign keys, so this is one query for every
-- gun at once — the old Notion-SQL version needed a manual two-step
-- (pull clean dates, then hand-substitute one gun's name and date at a
-- time) because cross-collection joins weren't reliable there.
--
-- A gun with no last_cleaned set shows 0/0, not "everything since
-- purchase" — there's no cleaning date to join against, so treat 0 here
-- as "unknown," not "just cleaned."

SELECT
  f.name AS firearm,
  f.last_cleaned,
  COALESCE(SUM(s.rounds_fired), 0) AS rounds_since_cleaning,
  COUNT(s.id)                      AS trips_since_cleaning
FROM firearms f
LEFT JOIN range_sessions s
  ON s.firearm_id = f.id AND s.date > f.last_cleaned
GROUP BY f.name, f.last_cleaned
ORDER BY rounds_since_cleaning DESC NULLS LAST;
