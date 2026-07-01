-- ============================================================
-- INGREDIENT METADATA: brand, category, package size
--
-- package_qty/package_unit represent the manufacturer's fixed
-- package size for a given product (e.g. "this barcode is always
-- a 200g jar") — an objective, shared fact about the product, not
-- something that should vary per user. When present, this is used
-- as the basis for cost-per-100g math instead of asking every user
-- to re-enter the same package size (see user_ingredient_costs in
-- 003_shared_ingredient_costs.sql, where purchase_qty/purchase_unit
-- act only as a fallback for bulk/unbarcoded items with no fixed size).
-- ============================================================

alter table ingredients
  add column brand         text,
  add column category      text,
  add column package_qty   numeric,   -- e.g. 200 — null for bulk/manual items with no fixed size
  add column package_unit  text;      -- 'g' or 'ml'
