-- ============================================================
-- LABEL SERVING SIZE
--
-- Nutrition is always stored per-100g/100ml (see ingredients table
-- in 001_initial_schema.sql), but users enter values exactly as
-- printed on a product label (e.g. "per 32g serving"), not as
-- per-100g math they'd have to do by hand.
--
-- This column remembers what serving size was used for that
-- conversion, purely so the edit form can convert per-100g values
-- back to "per label serving" for display/editing, and back again
-- on save. It is NOT used by any nutrition calculation elsewhere —
-- recipe scaling always reads the canonical per-100g columns.
-- ============================================================

alter table ingredients
  add column label_serving_g numeric;
