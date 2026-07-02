-- ============================================================
-- LABEL PRINT AUDIT TRAIL
--
-- Records a snapshot of the exact nutrition values shown on a
-- printed label, every time a label is printed — whether the
-- baker adjusted any values or printed the calculated numbers
-- as-is. This is a business record, not a live data table: if a
-- customer ever questions a label, there's a record of exactly
-- what was printed and when.
--
-- Deliberately no UPDATE or DELETE policy/grant — an audit trail
-- that can be edited after the fact isn't much of an audit trail.
-- ============================================================

create table label_overrides (
  id                      uuid        primary key default gen_random_uuid(),
  recipe_id               uuid        not null references recipes(id) on delete cascade,
  user_id                 uuid        not null references auth.users(id) default auth.uid(),

  recipe_name_snapshot    text        not null,
  serving_size_g_snapshot numeric     not null,
  nutrition_snapshot      jsonb       not null, -- the exact per-serving values shown on the printed label
  was_manually_adjusted   boolean     not null default false,

  printed_at              timestamptz not null default now()
);

alter table label_overrides enable row level security;

create policy "users view their own label history" on label_overrides
  for select using (auth.uid() = user_id);

create policy "users insert their own label history" on label_overrides
  for insert with check (auth.uid() = user_id);

grant select, insert on label_overrides to authenticated;

create index idx_label_overrides_recipe_id on label_overrides(recipe_id);