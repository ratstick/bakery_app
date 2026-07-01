<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';

  let recipes = $state([]);
  let loading = $state(true);

  onMount(async () => {
    const { data, error } = await supabase
      .from('recipes')
      .select('*')
      .order('name');

    if (!error) recipes = data;
    loading = false;
  });
</script>

<h1>Recipes</h1>

<a href="/recipes/new">+ New Recipe</a>

{#if loading}
  <p>Loading...</p>
{:else if recipes.length === 0}
  <p>No recipes yet.</p>
{:else}
  <ul>
    {#each recipes as recipe}
      <li><a href="/recipes/{recipe.id}">{recipe.name}</a> — {recipe.servings} servings</li>
    {/each}
  </ul>
{/if}