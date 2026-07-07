-- ============================================================
-- BAKERY APP — CONSOLIDATED SCHEMA
--
-- This is the current, complete database schema in one file —
-- ideal for setting up a fresh Supabase project from scratch.
--
-- The full incremental history (how this schema evolved, and why
-- each change was made) lives in supabase/sql/001_*.sql through
-- 011_*.sql. That folder is a historical record, not something you
-- need to run — this single file already reflects the end result
-- of all of them combined.
--
-- All weights are stored in grams, all volumes in milliliters.
-- Conversion to/from cups, tbsp, etc. happens in the UI only.
-- ============================================================


-- ============================================================
-- TABLES
-- ============================================================

-- Master ingredient library — shared/global across all users
-- (a community nutrition database). One row per unique ingredient.
-- Nutrition values are per 100g/100ml, the canonical basis used
-- throughout the app; the UI lets users enter values as printed on
-- a label (per serving) and converts to this basis on save.
create table ingredients (
  id                uuid        primary key default gen_random_uuid(),
  name              text        not null,
  barcode           text        unique,       -- null for manually entered ingredients
  is_liquid         boolean     not null default false,

  brand             text,
  category          text,

  -- Manufacturer's fixed package size (e.g. "this barcode is always
  -- a 200g jar") — an objective, shared fact, used as the basis for
  -- cost-per-100g math so every user doesn't have to re-enter it.
  package_qty       numeric,
  package_unit      text,       -- 'g' or 'ml'

  -- Lets a solid also be measured by volume (e.g. "1 cup of flour ≈
  -- 120g") or any ingredient be measured by count (e.g. "1 egg ≈
  -- 50g"). Both optional; stored as "grams per X" since that's how a
  -- baker actually knows the value, not raw scientific density.
  grams_per_cup     numeric,
  grams_per_each    numeric,

  -- Nutrition per 100g/100ml (all nullable — data is often incomplete)
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

  -- Remembers what label serving size was used to enter the nutrition
  -- values above, purely so the edit form can convert per-100g back
  -- to "per serving" for display. Never used in nutrition calculations.
  label_serving_g   numeric,

  -- Soft delete: hides from "add to a new recipe" pickers without
  -- breaking any existing recipe that already references it, and
  -- without cascading into other users' private cost data.
  archived          boolean     not null default false,

  -- Who created it, for personalized "my ingredients" filtering.
  -- Nullable — not retroactively knowable for pre-existing rows.
  created_by        uuid        references auth.users(id) default auth.uid(),

  created_at        timestamptz not null default now()
);

-- Recipes = named sets of ingredients only (no instructions/method —
-- those stay private to the baker elsewhere). Private per-user.
create table recipes (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users(id) default auth.uid(),
  name              text        not null,
  description       text,
  servings          integer     not null check (servings > 0),
  serving_size_g    numeric     not null check (serving_size_g > 0),
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- Ingredients within a recipe. No user_id of its own — ownership
-- flows through the parent recipe.
create table recipe_ingredients (
  id                uuid        primary key default gen_random_uuid(),
  recipe_id         uuid        not null references recipes(id) on delete cascade,
  ingredient_id     uuid        not null references ingredients(id),
  quantity_g        numeric     not null check (quantity_g > 0), -- canonical, always g or ml
  display_qty       numeric,    -- what the user actually typed, e.g. 2
  display_unit      text,       -- the unit they typed it in, e.g. "cups"
  component         text        not null default '', -- e.g. "Base"/"Frosting"; '' = single-part recipe
  sort_order        integer     not null default 0,

  unique (recipe_id, ingredient_id, component)
);

-- Current stock level per ingredient, private per-user.
create table inventory (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users(id) default auth.uid(),
  ingredient_id     uuid        not null references ingredients(id),
  quantity_g        numeric     not null default 0 check (quantity_g >= 0),
  last_updated      timestamptz not null default now(),

  unique (user_id, ingredient_id)
);

-- Per-user ingredient pricing — kept separate from the shared
-- `ingredients` table so nutrition data stays shared/objective while
-- pricing stays private (regional, store-dependent, changes over time).
create table user_ingredient_costs (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users(id) default auth.uid(),
  ingredient_id     uuid        not null references ingredients(id) on delete cascade,

  purchase_price    numeric     not null,
  -- Only used when the ingredient has no shared package_qty/package_unit
  -- (e.g. bulk/unbarcoded items) — otherwise the shared size is used.
  purchase_qty      numeric,
  purchase_unit     text,       -- 'g' or 'ml'
  currency          text        not null default 'CAD',

  cost_last_updated timestamptz not null default now(),

  unique (user_id, ingredient_id)
);

-- Audit trail: a snapshot of the exact nutrition values shown on a
-- printed CFIA label, every time a label is printed — whether values
-- were manually adjusted or printed as calculated. Deliberately has
-- no UPDATE or DELETE policy/grant; an editable audit trail isn't one.
create table label_overrides (
  id                      uuid        primary key default gen_random_uuid(),
  recipe_id               uuid        not null references recipes(id) on delete cascade,
  user_id                 uuid        not null references auth.users(id) default auth.uid(),

  recipe_name_snapshot    text        not null,
  serving_size_g_snapshot numeric     not null,
  nutrition_snapshot      jsonb       not null,
  was_manually_adjusted   boolean     not null default false,

  printed_at              timestamptz not null default now()
);

-- Shared/global tags, same philosophy as ingredients — one tag row
-- exists once regardless of how many ingredients or users reference
-- it. created_by is optional attribution only, not an ownership
-- boundary. Tag names are stored lowercase (normalized in the app
-- layer) to avoid "Nut Butter" and "nut butter" existing as two
-- separate tags.
create table tags (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null unique,
  created_by  uuid        references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now()
);

-- Many-to-many: one ingredient can have many tags (e.g. peanut butter
-- can be both "flavoring" and "nut butter" at once), one tag can
-- apply to many ingredients. No surrogate id — the pair is the key.
create table ingredient_tags (
  ingredient_id uuid not null references ingredients(id) on delete cascade,
  tag_id        uuid not null references tags(id) on delete cascade,

  primary key (ingredient_id, tag_id)
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
--
-- ingredients, tags, ingredient_tags: shared/global — any
-- authenticated user can read and contribute. Everything else is
-- private per-user.
-- ============================================================

alter table ingredients            enable row level security;
alter table recipes                enable row level security;
alter table recipe_ingredients     enable row level security;
alter table inventory              enable row level security;
alter table user_ingredient_costs  enable row level security;
alter table label_overrides        enable row level security;
alter table tags                   enable row level security;
alter table ingredient_tags        enable row level security;

create policy "authenticated users only" on ingredients
  for all using (auth.role() = 'authenticated');

create policy "users manage their own recipes" on recipes
  for all using (auth.uid() = user_id);

create policy "users manage their own recipe ingredients" on recipe_ingredients
  for all using (
    auth.uid() = (select user_id from recipes where recipes.id = recipe_ingredients.recipe_id)
  );

create policy "users manage their own inventory" on inventory
  for all using (auth.uid() = user_id);

create policy "users manage their own ingredient costs" on user_ingredient_costs
  for all using (auth.uid() = user_id);

create policy "users view their own label history" on label_overrides
  for select using (auth.uid() = user_id);

create policy "users insert their own label history" on label_overrides
  for insert with check (auth.uid() = user_id);

create policy "authenticated users only" on tags
  for all using (auth.role() = 'authenticated');

create policy "authenticated users only" on ingredient_tags
  for all using (auth.role() = 'authenticated');


-- ============================================================
-- GRANTS
--
-- IMPORTANT: this project has "Automatically expose new tables"
-- turned OFF in Supabase (intentional — explicit RLS, not blanket
-- exposure). That setting also controls whether the `authenticated`
-- role gets baseline table privileges at all. Without these grants,
-- every query fails with "permission denied" even when RLS policies
-- look correct — RLS is checked AFTER these grants, not instead of
-- them. If you create this project fresh, make sure that Supabase
-- setting is off, and that these grants are run.
-- ============================================================

grant select, insert, update, delete on ingredients            to authenticated;
grant select, insert, update, delete on recipes                 to authenticated;
grant select, insert, update, delete on recipe_ingredients      to authenticated;
grant select, insert, update, delete on inventory                to authenticated;
grant select, insert, update, delete on user_ingredient_costs    to authenticated;
grant select, insert                on label_overrides           to authenticated;
grant select, insert, update, delete on tags                     to authenticated;
grant select, insert, delete         on ingredient_tags           to authenticated;


-- ============================================================
-- INDEXES
-- ============================================================

create index idx_recipe_ingredients_recipe_id       on recipe_ingredients(recipe_id);
create index idx_inventory_ingredient_id            on inventory(ingredient_id);
create index idx_ingredients_barcode                on ingredients(barcode);
create index idx_ingredients_archived               on ingredients(archived);
create index idx_user_ingredient_costs_ingredient_id on user_ingredient_costs(ingredient_id);
create index idx_label_overrides_recipe_id          on label_overrides(recipe_id);
create index idx_ingredient_tags_tag_id             on ingredient_tags(tag_id);
