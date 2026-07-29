-- Lifetime rounds, trips, and average distance per weapon.
-- Recomputed from the Sessions fact table (the Firearms rollups
-- exist in Notion but are invisible to SQL).

SELECT
  "Firearm",
  "Caliber",
  COUNT(*)              AS trips,
  SUM("Rounds Fired")   AS rounds,
  AVG("Distance (yds)") AS avg_distance
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
WHERE "Firearm" IS NOT NULL
GROUP BY "Firearm", "Caliber"
ORDER BY rounds DESC;
