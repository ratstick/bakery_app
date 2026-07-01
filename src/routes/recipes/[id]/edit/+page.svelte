<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import { toBaseUnit, VOLUME_UNITS, WEIGHT_UNITS } from '$lib/units.js';
  import { findDuplicateGroups, mergeRows } from '$lib/duplicateCheck.js';

  const recipeId = $page.params.id;

  let name = $state('');
  let servings = $state('');
  let servingSizeG = $state('');
  let notes = $state('');

  let allIngredients = $state([]);
  let rows = $state([]); // { id (null if new), ingredient_id, component, display_qty, display_unit }
  let originalRowIds = []; // tracks which rows existed on load, so we know what to delete
  let duplicateGroups = $derived(findDuplicateGroups(rows));
  let duplicateRowIndexes = $derived(new Set(duplicateGroups.flat()));
  let loading = $state(true);
  let saving = $state(false);
  let errorMessage = $state('');

  onMount(async () => {
    const { data: ingredientsList } = await supabase
      .from('ingredients')
      .select('id, name, is_liquid')
      .order('name');
    allIngredients = ingredientsList ?? [];

    const { data: recipe, error: recipeError } = await supabase
      .from('recipes')
      .select('*')
      .eq('id', recipeId)
      .single();

    if (recipeError) {
      errorMessage = recipeError.message;
      loading = false;
      return;
    }

    name = recipe.name;
    servings = recipe.servings;
    servingSizeG = recipe.serving_size_g;
    notes = recipe.notes ?? '';

    const { data: riData, error: riError } = await supabase
      .from('recipe_ingredients')
      .select('*')
      .eq('recipe_id', recipeId);

    if (riError) {
      errorMessage = riError.message;
      loading = false;
      return;
    }

    rows = riData.map((r) => ({
      id: r.id,
      ingredient_id: r.ingredient_id,
      component: r.component,
      display_qty: r.display_qty,
      display_unit: r.display_unit
    }));
    originalRowIds = riData.map((r) => r.id);

    loading = false;
  });

  function addRow() {
    rows = [...rows, { id: null, ingredient_id: '', component: '', display_qty: '', display_unit: '' }];
  }
  function handleMerge(groupIndexes) {
    const [firstIndex, secondIndex] = groupIndexes;
    const ingredient = allIngredients.find((i) => i.id === rows[firstIndex].ingredient_id);

    const merged = mergeRows(rows[firstIndex], rows[secondIndex], ingredient.is_liquid);

    rows = rows.filter((_, i) => i !== firstIndex && i !== secondIndex);
    rows = [...rows, merged];
}
  function removeRow(index) {
    rows = rows.filter((_, i) => i !== index);
  }

  function unitsFor(ingredientId) {
    const ingredient = allIngredients.find((i) => i.id === ingredientId);
    if (!ingredient) return [];
    return ingredient.is_liquid ? VOLUME_UNITS : WEIGHT_UNITS;
  }

  async function handleSave() {
    errorMessage = '';
    if (duplicateGroups.length > 0) {
      errorMessage = 'You have the same ingredient listed twice with the same component. Give one a different component name, merge them, or remove one before saving.';
      return;
}
    if (rows.length === 0) {
      errorMessage = 'A recipe needs at least one ingredient.';
      return;
    }

    saving = true;

    const { error: recipeError } = await supabase
      .from('recipes')
      .update({
        name,
        servings: Number(servings),
        serving_size_g: Number(servingSizeG),
        notes: notes || null
      })
      .eq('id', recipeId);

    if (recipeError) {
      errorMessage = recipeError.message;
      saving = false;
      return;
    }

    // Convert display quantities to canonical grams/ml before saving
    let conversionError = null;
    const preparedRows = rows.map((row) => {
      const ingredient = allIngredients.find((i) => i.id === row.ingredient_id);
      try {
        const quantity_g = toBaseUnit(Number(row.display_qty), row.display_unit, ingredient.is_liquid);
        return { ...row, quantity_g };
      } catch (err) {
        conversionError = err.message;
        return null;
      }
    });

    if (conversionError) {
      errorMessage = conversionError;
      saving = false;
      return;
    }

    // Rows that still have an id get updated; rows without one are new inserts
    const toUpdate = preparedRows.filter((r) => r.id);
    const toInsert = preparedRows.filter((r) => !r.id);

    for (const row of toUpdate) {
      const { error } = await supabase
        .from('recipe_ingredients')
        .update({
          ingredient_id: row.ingredient_id,
          component: row.component || '',
          quantity_g: row.quantity_g,
          display_qty: Number(row.display_qty),
          display_unit: row.display_unit
        })
        .eq('id', row.id);

      if (error) {
        errorMessage = error.message;
        saving = false;
        return;
      }
    }

    if (toInsert.length > 0) {
      const { error } = await supabase.from('recipe_ingredients').insert(
        toInsert.map((row) => ({
          recipe_id: recipeId,
          ingredient_id: row.ingredient_id,
          component: row.component || '',
          quantity_g: row.quantity_g,
          display_qty: Number(row.display_qty),
          display_unit: row.display_unit
        }))
      );

      if (error) {
        errorMessage = error.message;
        saving = false;
        return;
      }
    }

    // Any originally-loaded row id that's no longer present in `rows`
    // means the user removed it — delete those from the database.
    const currentIds = rows.map((r) => r.id).filter(Boolean);
    const deletedIds = originalRowIds.filter((id) => !currentIds.includes(id));

    if (deletedIds.length > 0) {
      const { error } = await supabase
        .from('recipe_ingredients')
        .delete()
        .in('id', deletedIds);

      if (error) {
        errorMessage = error.message;
        saving = false;
        return;
      }
    }

    saving = false;
    goto(`/recipes/${recipeId}`);
  }
</script>

<h1>Edit Recipe</h1>

{#if loading}
  <p>Loading...</p>
{:else}
  <form onsubmit={(e) => { e.preventDefault(); handleSave(); }}>

    <label>Name <input type="text" bind:value={name} required /></label>
    <label>Servings <input type="number" bind:value={servings} required /></label>
    <label>Serving size (grams) <input type="number" step="any" bind:value={servingSizeG} required /></label>
    <label>Notes <textarea bind:value={notes}></textarea></label>

    <h2>Ingredients</h2>

    {#each rows as row, i}
      <fieldset class:duplicate-warning={duplicateRowIndexes.has(i)}>
  {#each duplicateGroups as group}
    {#if group.includes(i)}
      <p class="warning">
        This ingredient already appears elsewhere in this recipe with the same component.
        Change the component name to tell them apart, or
        <button type="button" onclick={() => handleMerge(group)}>merge these into one</button>.
      </p>
    {/if}
  {/each}
        <label>
          Ingredient
          <select bind:value={row.ingredient_id} required>
            <option value="" disabled>Select an ingredient</option>
            {#each allIngredients as ingredient}
              <option value={ingredient.id}>{ingredient.name}</option>
            {/each}
          </select>
        </label>

        <label>
          Component (optional)
          <input type="text" bind:value={row.component} />
        </label>

        <label>
          Quantity
          <input type="number" step="any" bind:value={row.display_qty} required />
        </label>

        <label>
          Unit
          <select bind:value={row.display_unit} required>
            <option value="" disabled>Select unit</option>
            {#each unitsFor(row.ingredient_id) as unit}
              <option value={unit}>{unit}</option>
            {/each}
          </select>
        </label>

        <button type="button" onclick={() => removeRow(i)}>Remove</button>
      </fieldset>
    {/each}

    <button type="button" onclick={addRow}>+ Add Ingredient</button>

    {#if errorMessage}
      <p class="error">{errorMessage}</p>
    {/if}

    <button type="submit" disabled={saving}>
      {saving ? 'Saving...' : 'Save Changes'}
    </button>
  </form>
{/if}