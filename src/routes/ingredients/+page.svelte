<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';

  let ingredients = $state([]);
  let loading = $state(true);
  let showArchived = $state(false);
  let showAllShared = $state(false); // false = only ingredients relevant to me; true = the full shared library

  // "Relevant to me" = I created it, I've priced it, or I've used it in
  // one of my own recipes. Ingredients stay shared/global in storage —
  // this is purely a browse-view filter, not a data restriction.
  async function loadMyIngredientIds() {
    const { data: userData } = await supabase.auth.getUser();
    const myUserId = userData.user.id;

    const [{ data: created }, { data: priced }, { data: used }] = await Promise.all([
      supabase.from('ingredients').select('id').eq('created_by', myUserId),
      supabase.from('user_ingredient_costs').select('ingredient_id'), // already RLS-scoped to me
      supabase.from('recipe_ingredients').select('ingredient_id') // already RLS-scoped to my recipes
    ]);

    return new Set([
      ...(created ?? []).map((r) => r.id),
      ...(priced ?? []).map((r) => r.ingredient_id),
      ...(used ?? []).map((r) => r.ingredient_id)
    ]);
  }

  async function loadIngredients() {
    loading = true;

    let query = supabase.from('ingredients').select('*').order('name');
    if (!showArchived) {
      query = query.eq('archived', false);
    }

    if (!showAllShared) {
      const myIds = await loadMyIngredientIds();
      if (myIds.size === 0) {
        ingredients = [];
        loading = false;
        return;
      }
      query = query.in('id', [...myIds]);
    }

    const { data, error } = await query;
    if (!error) ingredients = data;
    loading = false;
  }

  onMount(loadIngredients);
</script>

<h1>Ingredients</h1>

<a href="/ingredients/new">+ Add Ingredient</a>

<label>
  <input type="checkbox" bind:checked={showArchived} onchange={loadIngredients} />
  Show archived ingredients
</label>

<label>
  <input type="checkbox" bind:checked={showAllShared} onchange={loadIngredients} />
  Show all shared ingredients (not just mine)
</label>

{#if loading}
  <p>Loading...</p>
{:else if ingredients.length === 0}
  <p>No ingredients yet.</p>
{:else}
  <ul>
    {#each ingredients as ingredient}
      <li>
        <a href="/ingredients/{ingredient.id}"><strong>{ingredient.name}</strong></a>
        {#if ingredient.brand} — {ingredient.brand}{/if}
        {#if ingredient.category} ({ingredient.category}){/if}
        {#if ingredient.archived} <em>(archived)</em>{/if}
      </li>
    {/each}
  </ul>
{/if}