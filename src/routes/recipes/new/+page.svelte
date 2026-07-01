<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import { toBaseUnit, VOLUME_UNITS, WEIGHT_UNITS } from '$lib/units.js';
  import { findDuplicateGroups } from '$lib/duplicateCheck.js';

  let name = $state('');
  let servings = $state('');
  let servingSizeG = $state('');
  let notes = $state('');

  let allIngredients = $state([]);
  let rows = $state([]); // { ingredient_id, component, display_qty, display_unit }

  let errorMessage = $state('');
  let saving = $state(false);

  let duplicateGroups = $derived(findDuplicateGroups(rows));
  let duplicateRowIndexes = $derived(new Set(duplicateGroups.flat()));

  onMount(async () => {
    const { data } = await supabase
      .from('ingredients')
      .select('id, name, is_liquid')
      .order('name');
    allIngredients = data ?? [];
  });

  function addRow() {
    rows = [...rows, { ingredient_id: '', component: '', display_qty: '', display_unit: '' }];
  }

  function removeRow(index) {
    rows = rows.filter((_, i) => i !== index);
  }

  function unitsFor(ingredientId) {
    const ingredient = allIngredients.find((i) => i.id === ingredientId);
    if (!ingredient) return [];
    return ingredient.is_liquid ? VOLUME_UNITS : WEIGHT_UNITS;
  }

  async function handleSubmit() {
    errorMessage = '';
    if (duplicateGroups.length > 0) {
    errorMessage = 'You have the same ingredient listed twice with the same component. Give one a different component name (e.g. "Base" vs "Topping"), or remove one, before saving.';
    return;
}
    if (rows.length === 0) {
      errorMessage = 'Add at least one ingredient.';
      return;
    }

    saving = true;

    const { data: recipe, error: recipeError } = await supabase
      .from('recipes')
      .insert({
        name,
        servings: Number(servings),
        serving_size_g: Number(servingSizeG),
        notes: notes || null
      })
      .select()
      .single();

    if (recipeError) {
      errorMessage = recipeError.message;
      saving = false;
      return;
    }

    // Convert each row's display quantity into the canonical base unit
    // before saving, keeping display_qty/display_unit for showing it
    // back the way the user typed it.
    let conversionError = null;
    const ingredientRows = rows.map((row) => {
      const ingredient = allIngredients.find((i) => i.id === row.ingredient_id);
      try {
        const quantity_g = toBaseUnit(Number(row.display_qty), row.display_unit, ingredient.is_liquid);
        return {
          recipe_id: recipe.id,
          ingredient_id: row.ingredient_id,
          component: row.component || '',
          quantity_g,
          display_qty: Number(row.display_qty),
          display_unit: row.display_unit
        };
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

    const { error: ingredientsError } = await supabase
      .from('recipe_ingredients')
      .insert(ingredientRows);

    if (ingredientsError) {
      errorMessage = ingredientsError.message;
      saving = false;
      return;
    }

    saving = false;
    goto('/recipes');
  }
</script>

<h1>New Recipe</h1>

<form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>

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
        Component (optional, e.g. "Base" or "Frosting")
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
    {saving ? 'Saving...' : 'Save Recipe'}
  </button>
</form>