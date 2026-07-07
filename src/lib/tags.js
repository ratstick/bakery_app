import { supabase } from "./supabase.js";

// Keeps tag names consistent — avoids "Nut Butter" and "nut butter"
// existing as two separate tags.
export function normalizeTagName(name) {
  return name.trim().toLowerCase();
}

export async function getAllTags() {
  const { data } = await supabase.from("tags").select("*").order("name");
  return data ?? [];
}

export async function getTagsForIngredient(ingredientId) {
  const { data } = await supabase
    .from("ingredient_tags")
    .select("tags(*)")
    .eq("ingredient_id", ingredientId);
  return (data ?? []).map((row) => row.tags);
}

// Finds an existing tag by name, or creates it if it doesn't exist yet.
async function getOrCreateTag(name) {
  const normalized = normalizeTagName(name);
  if (!normalized) return null;

  const { data: existing } = await supabase
    .from("tags")
    .select("*")
    .eq("name", normalized)
    .maybeSingle();

  if (existing) return existing;

  const { data: created, error } = await supabase
    .from("tags")
    .insert({ name: normalized })
    .select()
    .single();

  if (error) throw error;
  return created;
}

// Replaces all of an ingredient's tags with the given list of names.
// Simplest correct approach for a small tag count per ingredient:
// clear existing links, then re-link fresh, rather than diffing.
export async function setIngredientTags(ingredientId, tagNames) {
  await supabase
    .from("ingredient_tags")
    .delete()
    .eq("ingredient_id", ingredientId);

  const uniqueNames = [
    ...new Set(tagNames.map(normalizeTagName).filter(Boolean)),
  ];
  if (uniqueNames.length === 0) return;

  const tags = await Promise.all(uniqueNames.map(getOrCreateTag));

  const { error } = await supabase
    .from("ingredient_tags")
    .insert(
      tags.map((tag) => ({ ingredient_id: ingredientId, tag_id: tag.id })),
    );
  if (error) throw error;
}
