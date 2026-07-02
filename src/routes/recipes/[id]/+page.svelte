<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import { toBaseUnitForIngredient, unitsForIngredient } from '$lib/units.js';
  import { findDuplicateGroups } from '$lib/duplicateCheck.js';

  const recipeId = $page.params.id;

  let recipe = $state(null);
  let rows = $state([]); // { id, ingredient_id, component, display_qty, display_unit, ingredients, cost }
  let allIngredients = $state([]); // full ingredient records, for the swap dropdown + nutrition math
  let originalIngredientIds = new Map(); // row.id -> the ingredient it had on load, used to detect swaps

  let loading = $state(true);
  let errorMessage = $state('');
  let inventoryByIngredient = $state({}); // ingredient_id -> quantity_g on hand, for the current user

  // Save-swap panel state
  let showSavePanel = $state(false);
  let saveMode = $state('overwrite'); // 'overwrite' | 'new'
  let newRecipeName = $state('');
  let saving = $state(false);
  let saveSuccess = $state(null); // { recipeId, mode: 'new' | 'overwrite' } or null after a successful save

  onMount(async () => {
    const { data: allIngredientsData } = await supabase.from('ingredients').select('*').order('name');
    allIngredients = allIngredientsData ?? [];

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
    newRecipeName = `${recipe.name} (variant)`;

    const { data: riData, error: riError } = await supabase
      .from('recipe_ingredients')
      .select('*, ingredients(*)')
      .eq('recipe_id', recipeId);

    if (riError) {
      errorMessage = riError.message;
      loading = false;
      return;
    }

    const ingredientIds = riData.map((r) => r.ingredient_id);
    const { data: costData } = await supabase
      .from('user_ingredient_costs')
      .select('*')
      .in('ingredient_id', ingredientIds);

    rows = riData.map((row) => ({
      id: row.id,
      ingredient_id: row.ingredient_id,
      component: row.component,
      display_qty: row.display_qty,
      display_unit: row.display_unit,
      ingredients: row.ingredients,
      cost: costData?.find((c) => c.ingredient_id === row.ingredient_id) ?? null
    }));

    originalIngredientIds = new Map(rows.map((r) => [r.id, r.ingredient_id]));

    // RLS already scopes this to the current user — this is only your own stock.
    const { data: inventoryData } = await supabase
      .from('inventory')
      .select('*')
      .in('ingredient_id', ingredientIds);

    inventoryByIngredient = Object.fromEntries(
      (inventoryData ?? []).map((inv) => [inv.ingredient_id, inv.quantity_g])
    );

    loading = false;
  });

  // Swapping an ingredient: look up the new ingredient's full record,
  // fetch (or reuse a cached) cost entry for it, and reset the unit
  // if it isn't valid for the new ingredient (e.g. the old ingredient
  // supported "each" but the new one doesn't) — we can't safely carry
  // a unit across to an ingredient that doesn't support it.
  async function handleSwap(index, newIngredientId) {
    const newIngredient = allIngredients.find((i) => i.id === newIngredientId);
    const oldRow = rows[index];
    const unitStillValid = unitsForIngredient(newIngredient).includes(oldRow.display_unit);

    let cost = rows.find((r) => r.ingredient_id === newIngredientId)?.cost ?? null;
    if (!cost) {
      const { data } = await supabase
        .from('user_ingredient_costs')
        .select('*')
        .eq('ingredient_id', newIngredientId)
        .maybeSingle();
      cost = data;
    }

    rows[index] = {
      ...oldRow,
      ingredient_id: newIngredientId,
      ingredients: newIngredient,
      cost,
      display_unit: unitStillValid ? oldRow.display_unit : '',
      display_qty: unitStillValid ? oldRow.display_qty : ''
    };
    rows = [...rows]; // trigger reactivity
  }

  function unitsFor(ingredient) {
    if (!ingredient) return [];
    return unitsForIngredient(ingredient);
  }

  function resolvePackageSize(ingredient, cost) {
    if (ingredient.package_qty) return ingredient.package_qty;
    return cost?.purchase_qty ?? null;
  }

  // Computes this row's quantity in canonical grams/ml on the fly from
  // whatever display_qty/display_unit currently is — rather than
  // trusting a stored quantity_g, since a swap can leave the unit
  // temporarily invalid (empty) until the user picks a new one.
  function rowQuantityG(row) {
    if (!row.display_qty || !row.display_unit) return null;
    try {
      return toBaseUnitForIngredient(Number(row.display_qty), row.display_unit, row.ingredients);
    } catch {
      return null;
    }
  }

  function nutrientContribution(row, field) {
    const qtyG = rowQuantityG(row);
    const perHundred = row.ingredients[field];
    if (qtyG === null || perHundred === null || perHundred === undefined) return null;
    return (perHundred * qtyG) / 100;
  }

  // How much more of this ingredient is needed than you currently have
  // in stock, or null if you have enough (or the quantity isn't valid yet).
  function stockShortfall(row) {
    const needed = rowQuantityG(row);
    if (needed === null) return null;
    const have = inventoryByIngredient[row.ingredient_id] ?? 0;
    return needed > have ? { needed, have } : null;
  }

  function costContribution(row) {
    const qtyG = rowQuantityG(row);
    if (qtyG === null || !row.cost) return null;
    const packageSize = resolvePackageSize(row.ingredients, row.cost);
    if (!packageSize) return null;
    const costPer100 = (row.cost.purchase_price / packageSize) * 100;
    return (costPer100 * qtyG) / 100;
  }

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
    return { total: values.reduce((a, b) => a + b, 0), isPartial: values.length < rows.length };
  });

  let perServing = $derived.by(() => {
    if (!recipe || !recipe.servings) return null;
    const nutrition = {};
    for (const field of nutritionFields) {
      nutrition[field] = totals[field] === null ? null : totals[field] / recipe.servings;
    }
    return { nutrition, cost: totalCost.total / recipe.servings };
  });

  let grouped = $derived.by(() => {
    const groups = {};
    for (const row of rows) {
      const key = row.component || '(main)';
      if (!groups[key]) groups[key] = [];
      groups[key].push(row);
    }
    return groups;
  });

  // True if any row's ingredient no longer matches what was loaded —
  // this is what decides whether "Save this swap" appears at all.
  let hasSwap = $derived(rows.some((r) => originalIngredientIds.get(r.id) !== r.ingredient_id));

  let duplicateGroups = $derived(
    findDuplicateGroups(rows.map((r) => ({ ingredient_id: r.ingredient_id, component: r.component })))
  );

  async function handleSaveSwap() {
    errorMessage = '';

    if (duplicateGroups.length > 0) {
      errorMessage = 'This swap creates a duplicate ingredient in the same component. Go to Edit Recipe to rename or merge it before saving.';
      return;
    }

    if (rows.some((r) => rowQuantityG(r) === null)) {
      errorMessage = 'One of the swapped ingredients is missing a valid quantity/unit. Fix it before saving.';
      return;
    }

    saving = true;

    if (saveMode === 'overwrite') {
      for (const row of rows) {
        const { error } = await supabase
          .from('recipe_ingredients')
          .update({
            ingredient_id: row.ingredient_id,
            display_qty: Number(row.display_qty),
            display_unit: row.display_unit,
            quantity_g: rowQuantityG(row)
          })
          .eq('id', row.id);

        if (error) {
          errorMessage = error.message;
          saving = false;
          return;
        }
      }

      originalIngredientIds = new Map(rows.map((r) => [r.id, r.ingredient_id]));
      showSavePanel = false;
      saving = false;
      saveSuccess = { recipeId: recipe.id, mode: 'overwrite' };
      return;
    }

    // saveMode === 'new': clone the recipe under a new name, with the swapped ingredients
    const { data: newRecipe, error: newRecipeError } = await supabase
      .from('recipes')
      .insert({
        name: newRecipeName,
        servings: recipe.servings,
        serving_size_g: recipe.serving_size_g,
        notes: recipe.notes
      })
      .select()
      .single();

    if (newRecipeError) {
      errorMessage = newRecipeError.message;
      saving = false;
      return;
    }

    const { error: insertError } = await supabase.from('recipe_ingredients').insert(
      rows.map((row) => ({
        recipe_id: newRecipe.id,
        ingredient_id: row.ingredient_id,
        component: row.component,
        display_qty: Number(row.display_qty),
        display_unit: row.display_unit,
        quantity_g: rowQuantityG(row)
      }))
    );

    if (insertError) {
      errorMessage = insertError.message;
      saving = false;
      return;
    }

    saving = false;
    showSavePanel = false;
    saveSuccess = { recipeId: newRecipe.id, mode: 'new' };
  }
</script>

{#if loading}
  <p>Loading...</p>
{:else if errorMessage && !recipe}
  <p class="error">{errorMessage}</p>
{:else}
  <h1>{recipe.name}</h1>
  <p>{recipe.servings} servings &middot; {recipe.serving_size_g}g per serving</p>
  {#if recipe.notes}<p>{recipe.notes}</p>{/if}
  <p><a href="/recipes/{recipe.id}/edit">Edit this recipe</a></p>
  <p><a href="/recipes/{recipe.id}/label">Print Label</a></p>
  <h2>Ingredients</h2>
  {#each Object.entries(grouped) as [component, componentRows]}
    {#if component !== '(main)'}<h3>{component}</h3>{/if}
    <ul>
      {#each componentRows as row}
        {@const rowIndex = rows.indexOf(row)}
        <li>
          <select
            value={row.ingredient_id}
            onchange={(e) => handleSwap(rowIndex, e.target.value)}
          >
            {#each allIngredients as ingredient}
              <option value={ingredient.id}>{ingredient.name}</option>
            {/each}
          </select>

          <input type="number" step="any" bind:value={row.display_qty} style="width: 5em;" />

          <select bind:value={row.display_unit}>
            <option value="" disabled>unit</option>
            {#each unitsFor(row.ingredients) as unit}
              <option value={unit}>{unit}</option>
            {/each}
          </select>

          {#if !row.cost}<em>(no price entered)</em>{/if}
          {#if rowQuantityG(row) === null}<em class="warning">(pick a valid unit)</em>{/if}
          {#if stockShortfall(row)}
            <em class="warning">
              (not enough on hand — have {stockShortfall(row).have.toFixed(0)}g, need {stockShortfall(row).needed.toFixed(0)}g)
            </em>
          {/if}
        </li>
      {/each}
    </ul>
  {/each}

  {#if hasSwap}
    <p><button onclick={() => (showSavePanel = true)}>Save this swap</button></p>
  {/if}

  {#if showSavePanel}
    <fieldset>
      <legend>Save changes</legend>
      <label>
        <input type="radio" bind:group={saveMode} value="overwrite" />
        Overwrite this recipe
      </label>
      <label>
        <input type="radio" bind:group={saveMode} value="new" />
        Save as a new recipe
      </label>

      {#if saveMode === 'new'}
        <label>
          New recipe name
          <input type="text" bind:value={newRecipeName} />
        </label>
      {/if}

      {#if errorMessage}<p class="error">{errorMessage}</p>{/if}

      <button onclick={handleSaveSwap} disabled={saving}>
        {saving ? 'Saving...' : 'Confirm Save'}
      </button>
      <button onclick={() => (showSavePanel = false)}>Cancel</button>
    </fieldset>
  {/if}
{#if saveSuccess}
  <fieldset>
    <legend>{saveSuccess.mode === 'new' ? 'New recipe saved' : 'Recipe updated'}</legend>
    <p>
      {saveSuccess.mode === 'new'
        ? `"${newRecipeName}" was created successfully.`
        : 'Your changes were saved.'}
    </p>
    <button onclick={() => goto(`/recipes/${saveSuccess.recipeId}`)}>View Recipe</button>
    <button onclick={() => goto(`/recipes/${saveSuccess.recipeId}/edit`)}>Edit Recipe</button>
    <button onclick={() => (saveSuccess = null)}>Stay Here</button>
  </fieldset>
{/if}
  <h2>Cost</h2>
  <p>
    Total: ${totalCost.total.toFixed(2)}
    {#if totalCost.isPartial}<em>(incomplete — some ingredients have no price on file)</em>{/if}
  </p>
  {#if perServing}<p>Per serving: ${perServing.cost.toFixed(2)}</p>{/if}

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