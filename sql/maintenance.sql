-- Rounds fired since each gun was last cleaned.
--
-- Firearms has a "Last Cleaned" date. Sessions have dates and round counts.
-- Nothing in Notion joins them — this is the query that makes that field useful.
--
-- Two steps: pull the clean dates, then sum rounds after each.
-- (Notion SQL joins across data sources are unreliable; do it in two passes
-- and combine, or ask Claude to do it in one go.)

-- step 1: when was each gun last cleaned?
SELECT "Firearm", "date:Last Cleaned:start" AS last_cleaned, "Caliber"
FROM "collection://e850e5dc-bf3f-43d4-9a77-6577c60b5ecb"
ORDER BY last_cleaned;

-- step 2: for a given gun, rounds since that date.
-- Substitute the name and date from step 1.
SELECT
  "Firearm",
  SUM("Rounds Fired") AS rounds_since_cleaning,
  COUNT(*)            AS trips_since_cleaning
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
WHERE "Firearm" = 'Canik SFx Rival S'
  AND "date:Date:start" > '2026-01-01'
GROUP BY "Firearm";
