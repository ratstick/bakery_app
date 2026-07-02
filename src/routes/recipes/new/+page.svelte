<script>
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';
  import { toBaseUnitForIngredient, unitsForIngredient } from '$lib/units.js';
  import { findDuplicateGroups, mergeRows } from '$lib/duplicateCheck.js';

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
// Quick-add: lets a baker create a brand-new ingredient without leaving
// this page, for the "oh I forgot to add that" case. Only collects the
// bare minimum (name, brand, category, liquid/solid) — nutrition and
// pricing are intentionally left for later via the Ingredients page,
// since this is meant to be fast, not thorough.
let showQuickAdd = $state(false);
let quickAddName = $state('');
let quickAddBrand = $state('');
let quickAddCategory = $state('');
let quickAddIsLiquid = $state(false);
let quickAddSaving = $state(false);
let quickAddError = $state('');
  onMount(async () => {
    const { data } = await supabase
      .from('ingredients')
      .select('*')
      .order('name');
    allIngredients = data ?? [];
  });

  function addRow() {
    rows = [...rows, { ingredient_id: '', component: '', display_qty: '', display_unit: '' }];
  }

  function removeRow(index) {
    rows = rows.filter((_, i) => i !== index);
  }
function handleMerge(groupIndexes) {
  const [firstIndex, secondIndex] = groupIndexes;
  const ingredient = allIngredients.find((i) => i.id === rows[firstIndex].ingredient_id);

  const merged = mergeRows(rows[firstIndex], rows[secondIndex], ingredient);

  rows = rows.filter((_, i) => i !== firstIndex && i !== secondIndex);
  rows = [...rows, merged];
}
  function unitsFor(ingredientId) {
    const ingredient = allIngredients.find((i) => i.id === ingredientId);
    if (!ingredient) return [];
    return unitsForIngredient(ingredient);
  }
async function handleQuickAdd() {
  quickAddError = '';
  if (!quickAddName.trim()) {
    quickAddError = 'Name is required.';
    return;
  }

  quickAddSaving = true;

  const { data: newIngredient, error } = await supabase
    .from('ingredients')
    .insert({
      name: quickAddName,
      brand: quickAddBrand || null,
      category: quickAddCategory || null,
      is_liquid: quickAddIsLiquid
    })
    .select('*')
    .single();

  quickAddSaving = false;

  if (error) {
    quickAddError = error.message;
    return;
  }

  // Add it to the dropdown and immediately create a row for it,
  // so there's no extra step to actually use it in this recipe.
  allIngredients = [...allIngredients, newIngredient].sort((a, b) => a.name.localeCompare(b.name));
  rows = [...rows, { ingredient_id: newIngredient.id, component: '', display_qty: '', display_unit: '' }];

  quickAddName = '';
  quickAddBrand = '';
  quickAddCategory = '';
  quickAddIsLiquid = false;
  showQuickAdd = false;
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
        const quantity_g = toBaseUnitForIngredient(Number(row.display_qty), row.display_unit, ingredient);
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
  <button type="button" onclick={() => (showQuickAdd = !showQuickAdd)}>+ Add New Ingredient (not in list yet)</button>

  {#if showQuickAdd}
    <fieldset>
      <legend>Quick Add Ingredient</legend>
      <p>
        This just adds it to your ingredient list so you can use it right now.
        <a href="/ingredients" target="_blank">Add nutrition facts and pricing</a> for it later.
      </p>

      <label>Name <input type="text" bind:value={quickAddName} required /></label>
      <label>Brand <input type="text" bind:value={quickAddBrand} /></label>
      <label>Category <input type="text" bind:value={quickAddCategory} /></label>
      <label>
        <input type="checkbox" bind:checked={quickAddIsLiquid} />
        This ingredient is a liquid
      </label>

      {#if quickAddError}<p class="error">{quickAddError}</p>{/if}

      <button type="button" onclick={handleQuickAdd} disabled={quickAddSaving}>
        {quickAddSaving ? 'Adding...' : 'Add & Use in This Recipe'}
      </button>
      <button type="button" onclick={() => (showQuickAdd = false)}>Cancel</button>
    </fieldset>
  {/if}

  {#if errorMessage}
    <p class="error">{errorMessage}</p>
  {/if}

  <button type="submit" disabled={saving}>
    {saving ? 'Saving...' : 'Save Recipe'}
  </button>
</form>