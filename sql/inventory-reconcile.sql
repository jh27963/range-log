-- Recompute on-hand straight from the fact tables and compare against
-- ammunition_inventory_calc.on_hand — they should always agree exactly.
-- This exists to catch a bug in the view itself, not in the data (there's
-- no separate Notion formula to distrust anymore).
--
-- Known-good as of the Supabase migration (2026-07-29):
--   9mm         600
--   .380 ACP    250
--   5.56 NATO   570
--   .22 LR      750

SELECT
  i.caliber,
  COALESCE(p.purchased, 0)                        AS purchased,
  COALESCE(s.fired, 0)                             AS fired,
  COALESCE(p.purchased, 0) - COALESCE(s.fired, 0)  AS on_hand
FROM ammunition_inventory i
LEFT JOIN (SELECT stock_id, SUM(rounds) AS purchased
           FROM ammo_purchases GROUP BY stock_id) p ON p.stock_id = i.id
LEFT JOIN (SELECT ammo_stock_id, SUM(rounds_fired) AS fired
           FROM range_sessions GROUP BY ammo_stock_id) s ON s.ammo_stock_id = i.id
ORDER BY i.caliber;
