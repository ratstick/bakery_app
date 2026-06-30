<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';

  let ingredients = $state([]);
  let loading = $state(true);

  onMount(async () => {
    const { data, error } = await supabase
      .from('ingredients')
      .select('*')
      .order('name');

    if (!error) {
      ingredients = data;
    }
    loading = false;
  });
</script>

<h1>Ingredients</h1>

<a href="/ingredients/new">+ Add Ingredient</a>

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
      </li>
    {/each}
  </ul>
{/if}