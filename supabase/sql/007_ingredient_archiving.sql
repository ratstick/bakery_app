-- ============================================================
-- INGREDIENT ARCHIVING (soft delete)
--
-- Ingredients are a shared table across all users, so a hard
-- delete is risky: it would silently cascade-delete every user's
-- private cost entries for that ingredient (user_ingredient_costs
-- has ON DELETE CASCADE), and RLS means you can't even see whether
-- someone else has data tied to it before deleting.
--
-- Archiving instead just hides an ingredient from "add to a new
-- recipe" flows going forward, without touching existing recipes
-- (which still need its nutrition data to calculate correctly) or
-- anyone else's cost data. True permanent deletion is a manual
-- cleanup task done directly in Supabase, not exposed in the UI.
-- ============================================================

alter table ingredients
  add column archived boolean not null default false;

create index idx_ingredients_archived on ingredients(archived);