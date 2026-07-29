-- What each caliber has cost, and the blended price per round.
-- Note: "Cost per Round" exists as a formula column in Notion but
-- does not come through SQL, so it is recomputed here.

SELECT
  "Caliber",
  COUNT(*)                             AS purchases,
  SUM("Rounds")                        AS rounds,
  SUM("Total Cost")                    AS spent,
  SUM("Total Cost") / SUM("Rounds")    AS cost_per_round
FROM "collection://c7fa221c-d512-43c4-a95f-60853ff68e37"
GROUP BY "Caliber"
ORDER BY spent DESC;
