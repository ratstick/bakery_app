-- ============================================================
-- BAKERY APP — INITIAL SCHEMA
-- All weights stored in grams, all volumes in milliliters.
-- Conversion to/from cups, tbsp, etc. happens in the UI only.
-- ============================================================


-- ============================================================
-- TABLES
-- ============================================================

-- Master ingredient library.
-- One row per unique ingredient. Nutrition values are per 100g/100ml,
-- which is the canonical basis used throughout the app. The UI lets
-- users enter values as printed on a label (per serving) and converts
-- to this basis on save — see 005_label_serving_g.sql.
create table ingredients (
  id                uuid        primary key default gen_random_uuid(),
  name              text        not null,
  barcode           text        unique,       -- null for manually entered ingredients
  is_liquid         boolean     not null default false, -- drives ml vs g display in UI

  -- Nutrition per 100g/100ml (all nullable — scanned or manual data is often incomplete)
  energy_kcal       numeric,
  fat_g             numeric,
  saturated_fat_g   numeric,
  trans_fat_g       numeric,
  carbohydrate_g    numeric,
  fibre_g           numeric,
  sugars_g          numeric,
  protein_g         numeric,
  sodium_mg         numeric,
  -- Required by CFIA label format
  vitamin_d_mcg     numeric,
  calcium_mg        numeric,
  iron_mg           numeric,
  potassium_mg      numeric,

  created_at        timestamptz not null default now()
);

-- Recipes = named sets of ingredients only (no instructions/method —
-- those stay private to the baker elsewhere).
create table recipes (
  id                uuid        primary key default gen_random_uuid(),
  name              text        not null,
  description       text,
  servings          integer     not null check (servings > 0),
  serving_size_g    numeric     not null check (serving_size_g > 0),
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Ingredients within a recipe.
-- quantity_g is canonical (always grams or ml).
-- display_qty/display_unit store what the user typed (e.g. 2, "cups").
-- component groups ingredients within a recipe (e.g. "Base", "Frosting").
-- Empty string = no component / single-component recipe.
create table recipe_ingredients (
  id                uuid        primary key default gen_random_uuid(),
  recipe_id         uuid        not null references recipes(id) on delete cascade,
  ingredient_id     uuid        not null references ingredients(id),
  quantity_g        numeric     not null check (quantity_g > 0),
  display_qty       numeric,
  display_unit      text,
  component         text        not null default '',
  sort_order        integer     not null default 0,

  unique (recipe_id, ingredient_id, component)
);

-- Inventory: current stock level for each ingredient.
create table inventory (
  id                uuid        primary key default gen_random_uuid(),
  ingredient_id     uuid        not null references ingredients(id) unique,
  quantity_g        numeric     not null default 0 check (quantity_g >= 0),
  last_updated      timestamptz not null default now()
);


-- ============================================================
-- AUTO-UPDATE updated_at ON RECIPES
-- ============================================================

create or replace function update_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger recipes_updated_at
  before update on recipes
  for each row
  execute function update_updated_at();


-- ============================================================
-- ROW LEVEL SECURITY
-- At this point in the project, everything is scoped to "any
-- authenticated user" — this gets tightened to per-owner scoping
-- for recipes/inventory in 002_multi_user_rls.sql. Ingredients
-- stay shared/global permanently (see 002 for reasoning).
-- ============================================================

alter table ingredients        enable row level security;
alter table recipes            enable row level security;
alter table recipe_ingredients enable row level security;
alter table inventory          enable row level security;

create policy "authenticated users only" on ingredients
  for all using (auth.role() = 'authenticated');

create policy "authenticated users only" on recipes
  for all using (auth.role() = 'authenticated');

create policy "authenticated users only" on recipe_ingredients
  for all using (auth.role() = 'authenticated');

create policy "authenticated users only" on inventory
  for all using (auth.role() = 'authenticated');


-- ============================================================
-- GRANTS
-- IMPORTANT: this Supabase project has "Automatically expose new
-- tables" turned OFF (intentional — we want explicit RLS, not
-- blanket exposure). That setting also controls whether the
-- `authenticated` role gets baseline table privileges at all.
-- Without these grants, every query fails with "permission denied"
-- even when RLS policies look correct — RLS is checked AFTER these
-- baseline grants, not instead of them.
-- ============================================================

grant select, insert, update, delete on ingredients        to authenticated;
grant select, insert, update, delete on recipes             to authenticated;
grant select, insert, update, delete on recipe_ingredients  to authenticated;
grant select, insert, update, delete on inventory            to authenticated;


-- ============================================================
-- INDEXES
-- ============================================================

create index idx_recipe_ingredients_recipe_id on recipe_ingredients(recipe_id);
create index idx_inventory_ingredient_id      on inventory(ingredient_id);
create index idx_ingredients_barcode          on ingredients(barcode);
