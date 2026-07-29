-- Recompute on-hand from the fact tables and check it against Notion.
--
-- On Hand (Calc) is a formula column in Notion:
--     Total Purchased − Total Rounds Fired
-- Formula columns don't come through SQL, so this rebuilds it from scratch.
-- Run both halves and subtract. They should agree with the app.
--
-- Expected as of the July 2026 backfill:
--   9mm        15650 bought − 15050 fired =  600
--   .380 ACP     950 bought −   700 fired =  250
--   5.56 NATO   1500 bought −   930 fired =  570
--   .22 LR      3750 bought −  3000 fired =  750

-- half 1: purchased
SELECT "Caliber", SUM("Rounds") AS purchased
FROM "collection://c7fa221c-d512-43c4-a95f-60853ff68e37"
GROUP BY "Caliber";

-- half 2: fired
SELECT "Caliber", SUM("Rounds Fired") AS fired
FROM "collection://4fae7323-f890-47c9-8004-c43c8fb27cac"
WHERE "Caliber" IS NOT NULL
GROUP BY "Caliber";
