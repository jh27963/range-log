-- What each caliber has cost, and the blended price per round.
-- ammo_purchases.cost_per_round is per-purchase; this blends across all
-- purchases in a caliber, which is the number that actually matters.

SELECT
  caliber,
  COUNT(*)                          AS purchases,
  SUM(rounds)                       AS rounds,
  SUM(total_cost)                   AS spent,
  SUM(total_cost) / SUM(rounds)     AS cost_per_round
FROM ammo_purchases
GROUP BY caliber
ORDER BY spent DESC;
