-- ============================================================
-- PER-USER INGREDIENT COSTS
-- Cost is kept separate from the shared `ingredients` table so
-- nutrition data stays shared/objective (true regardless of who
-- scanned/entered it) while pricing stays private per user
-- (regional, store-dependent, changes over time). Also sets up
-- cleanly for future multi-currency / multi-store-source pricing.
-- ============================================================

create table user_ingredient_costs (
  id                uuid        primary key default gen_random_uuid(),
  user_id           uuid        not null references auth.users(id) default auth.uid(),
  ingredient_id     uuid        not null references ingredients(id) on delete cascade,

  purchase_price    numeric     not null,
  -- purchase_qty/purchase_unit are only used when the ingredient has
  -- no shared package size (see 004_ingredient_brand_category_package.sql)
  -- — otherwise the shared package size is used and these stay null.
  purchase_qty      numeric,
  purchase_unit     text,       -- 'g' or 'ml'
  currency          text        not null default 'CAD',

  cost_last_updated timestamptz not null default now(),

  unique (user_id, ingredient_id)
);

alter table user_ingredient_costs enable row level security;

create policy "users manage their own ingredient costs" on user_ingredient_costs
  for all using (auth.uid() = user_id);

grant select, insert, update, delete on user_ingredient_costs to authenticated;

create index idx_user_ingredient_costs_ingredient_id on user_ingredient_costs(ingredient_id);
