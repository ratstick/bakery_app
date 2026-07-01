-- ============================================================
-- MULTI-USER UPDATE
-- Originally scoped single-user (any authenticated user could see
-- everything). This migration tightens ownership so the app works
-- correctly for multiple real users:
--
--   ingredients        = shared/global (community nutrition database,
--                         no owner — any authenticated user can read
--                         and contribute)
--   recipes, inventory = private per-user
--   recipe_ingredients = scoped via its parent recipe's owner
--   (ingredient costs move to their own private table — see
--   003_shared_ingredient_costs.sql)
-- ============================================================

-- recipes: add owner
alter table recipes
  add column user_id uuid not null references auth.users(id) default auth.uid();

-- inventory: add owner
alter table inventory
  add column user_id uuid not null references auth.users(id) default auth.uid();

-- recipe_ingredients: no user_id needed, ownership flows through recipe_id


-- ============================================================
-- RLS POLICY UPDATES
-- ============================================================

-- ingredients: unchanged — stays shared across all authenticated users
-- (the "authenticated users only" policy from 001 is correct as-is)

-- recipes: scope to owner
drop policy "authenticated users only" on recipes;
create policy "users manage their own recipes" on recipes
  for all using (auth.uid() = user_id);

-- inventory: scope to owner
drop policy "authenticated users only" on inventory;
create policy "users manage their own inventory" on inventory
  for all using (auth.uid() = user_id);

-- recipe_ingredients: scope through the parent recipe's owner
drop policy "authenticated users only" on recipe_ingredients;
create policy "users manage their own recipe ingredients" on recipe_ingredients
  for all using (
    auth.uid() = (select user_id from recipes where recipes.id = recipe_ingredients.recipe_id)
  );
