-- ============================================================
-- INGREDIENT TAGS
--
-- Shared/global, same philosophy as ingredients themselves — one
-- tag row exists once regardless of how many ingredients or users
-- reference it. This is what avoids "saving database space": tags
-- aren't duplicated per-user or per-ingredient, they're linked via
-- a join table (many ingredients can share one tag, one ingredient
-- can have many tags — e.g. peanut butter can be both "flavoring"
-- and "nut butter" at once).
--
-- created_by is optional attribution only (who added the tag),
-- mirroring ingredients.created_by — it powers a "my tags" browse
-- filter later if wanted, it's not an ownership/privacy boundary.
-- ============================================================

create table tags (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null unique,
  created_by  uuid        references auth.users(id) default auth.uid(),
  created_at  timestamptz not null default now()
);

-- Many-to-many: one ingredient can have many tags, one tag can apply
-- to many ingredients. No surrogate id needed — the pair itself is
-- the natural primary key.
create table ingredient_tags (
  ingredient_id uuid not null references ingredients(id) on delete cascade,
  tag_id        uuid not null references tags(id) on delete cascade,

  primary key (ingredient_id, tag_id)
);

alter table tags            enable row level security;
alter table ingredient_tags enable row level security;

-- Shared/global, same as ingredients — any authenticated user can
-- read, create, and tag/untag, since this is a community resource.
create policy "authenticated users only" on tags
  for all using (auth.role() = 'authenticated');

create policy "authenticated users only" on ingredient_tags
  for all using (auth.role() = 'authenticated');

grant select, insert, update, delete on tags            to authenticated;
grant select, insert, delete         on ingredient_tags  to authenticated;

create index idx_ingredient_tags_tag_id on ingredient_tags(tag_id);