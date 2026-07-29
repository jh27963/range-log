-- Consumption over time, by caliber.
-- Returns one row per session date; aggregate to months downstream
-- (Notion SQL has no DATE_TRUNC).

SELECT
  "date:Date:start" AS date,
  "Caliber",
  SUM("Rounds Fired") AS rounds
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
GROUP BY "date:Date:start", "Caliber"
ORDER BY date;
