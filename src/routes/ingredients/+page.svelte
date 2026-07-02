<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';

  let ingredients = $state([]);
  let loading = $state(true);
  let showArchived = $state(false);

async function loadIngredients() {
  let query = supabase.from('ingredients').select('*').order('name');
  if (!showArchived) {
    query = query.eq('archived', false);
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