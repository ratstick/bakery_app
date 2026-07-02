-- ============================================================
-- FIX: inventory's UNIQUE constraint was left global-per-ingredient
-- from the original single-user schema (001), and never updated
-- when 002_multi_user_rls.sql made inventory per-user. As written,
-- only one user in the whole app could ever have a stock record
-- for a given ingredient. user_ingredient_costs got this right the
-- first time; inventory didn't. Fixing it now, before any real
-- inventory data exists.
-- ============================================================

alter table inventory drop constraint inventory_ingredient_id_key;
alter table inventory add constraint inventory_user_ingredient_unique unique (user_id, ingredient_id);