<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';

  const recipeId = $page.params.id;

  let recipe = $state(null);
  let rows = $state([]); // recipe_ingredients joined with ingredient + cost data
  let loading = $state(true);
  let errorMessage = $state('');

  onMount(async () => {
    const { data: recipeData, error: recipeError } = await supabase
      .from('recipes')
      .select('*')
      .eq('id', recipeId)
      .single();

    if (recipeError) {
      errorMessage = recipeError.message;
      loading = false;
      return;
    }
    recipe = recipeData;

    // Pull each recipe_ingredients row with the full ingredient record nested in it
    const { data: riData, error: riError } = await supabase
      .from('recipe_ingredients')
      .select('*, ingredients(*)')
      .eq('recipe_id', recipeId);

    if (riError) {
      errorMessage = riError.message;
      loading = false;
      return;
    }

    // Pull your private cost entries for just the ingredients in this recipe
    const ingredientIds = riData.map((r) => r.ingredient_id);
    const { data: costData } = await supabase
      .from('user_ingredient_costs')
      .select('*')
      .in('ingredient_id', ingredientIds);

    // Merge cost data onto each row by ingredient_id
    rows = riData.map((row) => ({
      ...row,
      cost: costData?.find((c) => c.ingredient_id === row.ingredient_id) ?? null
    }));

    loading = false;
  });

  // Resolves the package size to use for cost math: shared package size
  // wins if it exists, otherwise fall back to what the user entered
  // themselves when they priced this ingredient.
  function resolvePackageSize(ingredient, cost) {
    if (ingredient.package_qty) return ingredient.package_qty;
    return cost?.purchase_qty ?? null;
  }

  function nutrientContribution(row, field) {
    const perHundred = row.ingredients[field];
    if (perHundred === null || perHundred === undefined) return null;
    return (perHundred * row.quantity_g) / 100;
  }

  function costContribution(row) {
    if (!row.cost) return null;
    const packageSize = resolvePackageSize(row.ingredients, row.cost);
    if (!packageSize) return null;
    const costPer100 = (row.cost.purchase_price / packageSize) * 100;
    return (costPer100 * row.quantity_g) / 100;
  }

  // Reactive totals — recalculate automatically any time `rows` changes
  const nutritionFields = [
    'energy_kcal', 'fat_g', 'saturated_fat_g', 'trans_fat_g',
    'carbohydrate_g', 'fibre_g', 'sugars_g', 'protein_g',
    'sodium_mg', 'vitamin_d_mcg', 'calcium_mg', 'iron_mg', 'potassium_mg'
  ];

  let totals = $derived.by(() => {
    const result = {};
    for (const field of nutritionFields) {
      const values = rows.map((r) => nutrientContribution(r, field)).filter((v) => v !== null);
      result[field] = values.length ? values.reduce((a, b) => a + b, 0) : null;
    }
    return result;
  });

  let totalCost = $derived.by(() => {
    const values = rows.map(costContribution).filter((v) => v !== null);
    const knownCount = values.length;
    const total = values.reduce((a, b) => a + b, 0);
    return { total, isPartial: knownCount < rows.length };
  });

  let perServing = $derived.by(() => {
    if (!recipe || !recipe.servings) return null;
    const nutrition = {};
    for (const field of nutritionFields) {
      nutrition[field] = totals[field] === null ? null : totals[field] / recipe.servings;
    }
    return {
      nutrition,
      cost: totalCost.total / recipe.servings
    };
  });

  // Group rows by component for display — empty string = no component
  let grouped = $derived.by(() => {
    const groups = {};
    for (const row of rows) {
      const key = row.component || '(main)';
      if (!groups[key]) groups[key] = [];
      groups[key].push(row);
    }
    return groups;
  });
</script>

{#if loading}
  <p>Loading...</p>
{:else if errorMessage}
  <p class="error">{errorMessage}</p>
{:else}
    <h1>{recipe.name}</h1>
    <p><a href="/recipes/{recipe.id}/edit">Edit this recipe</a></p>
  {#if recipe.notes}<p>{recipe.notes}</p>{/if}

  <h2>Ingredients</h2>
  {#each Object.entries(grouped) as [component, componentRows]}
    {#if component !== '(main)'}<h3>{component}</h3>{/if}
    <ul>
      {#each componentRows as row}
        <li>
          {row.display_qty} {row.display_unit} {row.ingredients.name}
          {#if !row.cost}
            <em>(no price entered)</em>
          {/if}
        </li>
      {/each}
    </ul>
  {/each}

  <h2>Cost</h2>
  <p>
    Total: ${totalCost.total.toFixed(2)}
    {#if totalCost.isPartial}<em>(incomplete — some ingredients have no price on file)</em>{/if}
  </p>
  {#if perServing}
    <p>Per serving: ${perServing.cost.toFixed(2)}</p>
  {/if}

  <h2>Nutrition (per serving)</h2>
  {#if perServing}
    <table>
      <tbody>
        <tr><td>Energy</td><td>{perServing.nutrition.energy_kcal?.toFixed(1) ?? '—'} kcal</td></tr>
        <tr><td>Fat</td><td>{perServing.nutrition.fat_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>&nbsp;&nbsp;Saturated Fat</td><td>{perServing.nutrition.saturated_fat_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>&nbsp;&nbsp;Trans Fat</td><td>{perServing.nutrition.trans_fat_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>Carbohydrate</td><td>{perServing.nutrition.carbohydrate_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>&nbsp;&nbsp;Fibre</td><td>{perServing.nutrition.fibre_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>&nbsp;&nbsp;Sugars</td><td>{perServing.nutrition.sugars_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>Protein</td><td>{perServing.nutrition.protein_g?.toFixed(2) ?? '—'} g</td></tr>
        <tr><td>Sodium</td><td>{perServing.nutrition.sodium_mg?.toFixed(1) ?? '—'} mg</td></tr>
        <tr><td>Vitamin D</td><td>{perServing.nutrition.vitamin_d_mcg?.toFixed(1) ?? '—'} mcg</td></tr>
        <tr><td>Calcium</td><td>{perServing.nutrition.calcium_mg?.toFixed(1) ?? '—'} mg</td></tr>
        <tr><td>Iron</td><td>{perServing.nutrition.iron_mg?.toFixed(2) ?? '—'} mg</td></tr>
        <tr><td>Potassium</td><td>{perServing.nutrition.potassium_mg?.toFixed(1) ?? '—'} mg</td></tr>
      </tbody>
    </table>
  {/if}
{/if}