-- Only sessions that actually happened.
-- 371 of ~373 rows are generated backfill tagged "Reconstructed —".
-- Use this filter on any query you intend to draw conclusions from.

SELECT
  "date:Date:start" AS date,
  "Firearm",
  "Caliber",
  "Rounds Fired",
  "Distance (yds)",
  "Accuracy",
  "Target Type",
  "Notes"
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
WHERE "Notes" NOT LIKE 'Reconstructed%'
ORDER BY date DESC;
