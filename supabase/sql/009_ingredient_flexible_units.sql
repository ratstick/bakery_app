-- ============================================================
-- FLEXIBLE INGREDIENT UNITS
--
-- Two optional per-ingredient conversion factors, both nullable:
--
-- grams_per_cup — lets a SOLID ingredient also be measured by
-- volume (e.g. "1 cup of flour ≈ 120g"). Without this, solids can
-- only be entered by weight, since volume-to-weight for a solid
-- depends on the specific ingredient's density.
--
-- grams_per_each — lets ANY ingredient be measured by count (e.g.
-- "3 eggs ≈ 150g"). Independent of liquid/solid.
--
-- Both are stored as "grams per [unit]" rather than raw scientific
-- density, since that's how a baker actually knows/looks up this
-- information (recipes and packaging say "1 cup of flour is about
-- 120g," not "0.507 g/ml").
-- ============================================================

alter table ingredients
  add column grams_per_cup  numeric,
  add column grams_per_each numeric;