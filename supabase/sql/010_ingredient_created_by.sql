-- ============================================================
-- TRACKS WHO CREATED EACH INGREDIENT
--
-- Ingredients stay shared/global (unchanged) — this column is only
-- used to power a personalized "my ingredients" view, so a user
-- isn't confronted with every other user's entries by default when
-- browsing. Nullable since existing rows predate this column and
-- can't be retroactively attributed.
-- ============================================================

alter table ingredients
  add column created_by uuid references auth.users(id) default auth.uid();