<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';

  const ingredientId = $page.params.id;

  let loading = $state(true);
  let saving = $state(false);
  let errorMessage = $state('');
  let archived = $state(false);

  // Ingredient fields
  let name = $state('');
  let brand = $state('');
  let category = $state('');
  let barcode = $state('');
  let isLiquid = $state(false);
  let packageQty = $state('');
  let packageUnit = $state('g');

  // The serving size the label values below are based on.
  // Stored alongside the ingredient so we can convert back to
  // "per serving" for display every time this page is opened,
  // instead of forcing per-100g math by hand.
  let labelServingG = $state('');

  let energyKcal = $state('');
  let fatG = $state('');
  let saturatedFatG = $state('');
  let transFatG = $state('');
  let carbohydrateG = $state('');
  let fibreG = $state('');
  let sugarsG = $state('');
  let proteinG = $state('');
  let sodiumMg = $state('');
  let vitaminDMcg = $state('');
  let calciumMg = $state('');
  let ironMg = $state('');
  let potassiumMg = $state('');

  // Your cost entry (may not exist yet)
  let costId = $state(null);
  let purchasePrice = $state('');
  let purchaseQty = $state('');
  let purchaseUnit = $state('g');

  function numOrNull(value) {
    return value === '' ? null : Number(value);
  }
  function valOrEmpty(value) {
    return value === null || value === undefined ? '' : value;
  }

  // Stored value is always per 100g/ml. Convert to "per label serving" for display.
  function fromPer100g(value, servingG) {
    if (value === null || value === undefined || !servingG) return '';
    return Math.round((value * servingG) / 100 * 100) / 100;
  }

  // Convert "per label serving" back to per-100g for storage.
  function toPer100g(value, servingG) {
    if (value === '' || !servingG) return null;
    return (Number(value) / Number(servingG)) * 100;
  }

  onMount(async () => {
    const { data: ingredient, error: ingredientError } = await supabase
      .from('ingredients')
      .select('*')
      .eq('id', ingredientId)
      .single();

    if (ingredientError) {
      errorMessage = ingredientError.message;
      loading = false;
      return;
    }

    name = ingredient.name;
    brand = valOrEmpty(ingredient.brand);
    category = valOrEmpty(ingredient.category);
    barcode = valOrEmpty(ingredient.barcode);
    isLiquid = ingredient.is_liquid;
    packageQty = valOrEmpty(ingredient.package_qty);
    packageUnit = ingredient.package_unit || 'g';
    archived = ingredient.archived;

    labelServingG = valOrEmpty(ingredient.label_serving_g);

    energyKcal = fromPer100g(ingredient.energy_kcal, labelServingG);
    fatG = fromPer100g(ingredient.fat_g, labelServingG);
    saturatedFatG = fromPer100g(ingredient.saturated_fat_g, labelServingG);
    transFatG = fromPer100g(ingredient.trans_fat_g, labelServingG);
    carbohydrateG = fromPer100g(ingredient.carbohydrate_g, labelServingG);
    fibreG = fromPer100g(ingredient.fibre_g, labelServingG);
    sugarsG = fromPer100g(ingredient.sugars_g, labelServingG);
    proteinG = fromPer100g(ingredient.protein_g, labelServingG);
    sodiumMg = fromPer100g(ingredient.sodium_mg, labelServingG);
    vitaminDMcg = fromPer100g(ingredient.vitamin_d_mcg, labelServingG);
    calciumMg = fromPer100g(ingredient.calcium_mg, labelServingG);
    ironMg = fromPer100g(ingredient.iron_mg, labelServingG);
    potassiumMg = fromPer100g(ingredient.potassium_mg, labelServingG);

    // RLS already scopes this to the current user — no manual filter needed.
    const { data: cost } = await supabase
      .from('user_ingredient_costs')
      .select('*')
      .eq('ingredient_id', ingredientId)
      .maybeSingle();

    if (cost) {
      costId = cost.id;
      purchasePrice = valOrEmpty(cost.purchase_price);
      purchaseQty = valOrEmpty(cost.purchase_qty);
      purchaseUnit = cost.purchase_unit || 'g';
    }

    loading = false;
  });

  async function handleSave() {
    saving = true;
    errorMessage = '';

    const { error: ingredientError } = await supabase
      .from('ingredients')
      .update({
        name,
        brand: brand || null,
        category: category || null,
        barcode: barcode || null,
        is_liquid: isLiquid,
        package_qty: numOrNull(packageQty),
        package_unit: packageQty ? packageUnit : null,

        label_serving_g: numOrNull(labelServingG),

        energy_kcal: toPer100g(energyKcal, labelServingG),
        fat_g: toPer100g(fatG, labelServingG),
        saturated_fat_g: toPer100g(saturatedFatG, labelServingG),
        trans_fat_g: toPer100g(transFatG, labelServingG),
        carbohydrate_g: toPer100g(carbohydrateG, labelServingG),
        fibre_g: toPer100g(fibreG, labelServingG),
        sugars_g: toPer100g(sugarsG, labelServingG),
        protein_g: toPer100g(proteinG, labelServingG),
        sodium_mg: toPer100g(sodiumMg, labelServingG),
        vitamin_d_mcg: toPer100g(vitaminDMcg, labelServingG),
        calcium_mg: toPer100g(calciumMg, labelServingG),
        iron_mg: toPer100g(ironMg, labelServingG),
        potassium_mg: toPer100g(potassiumMg, labelServingG)
      })
      .eq('id', ingredientId);

    if (ingredientError) {
      errorMessage = ingredientError.message;
      saving = false;
      return;
    }

    // Save cost: update if it exists, insert if it doesn't, skip if no price entered
    if (purchasePrice) {
      const costPayload = {
        ingredient_id: ingredientId,
        purchase_price: Number(purchasePrice),
        purchase_qty: packageQty ? null : numOrNull(purchaseQty),
        purchase_unit: packageQty ? null : purchaseUnit,
        cost_last_updated: new Date().toISOString()
      };

      const { error: costError } = costId
        ? await supabase.from('user_ingredient_costs').update(costPayload).eq('id', costId)
        : await supabase.from('user_ingredient_costs').insert(costPayload);

      if (costError) {
        errorMessage = costError.message;
        saving = false;
        return;
      }
    }

    saving = false;
    goto('/ingredients');
  }
  async function handleToggleArchive() {
  const { error } = await supabase
    .from('ingredients')
    .update({ archived: !archived })
    .eq('id', ingredientId);

  if (error) {
    errorMessage = error.message;
    return;
  }

  archived = !archived;
}
</script>

<h1>Edit Ingredient</h1>

{#if loading}
  <p>Loading...</p>
{:else}
  <form onsubmit={(e) => { e.preventDefault(); handleSave(); }}>

    <fieldset>
      <legend>Basics</legend>

      <label>Name <input type="text" bind:value={name} required /></label>
      <label>Brand <input type="text" bind:value={brand} /></label>
      <label>Category <input type="text" bind:value={category} /></label>
      <label>Barcode <input type="text" bind:value={barcode} /></label>
      <label><input type="checkbox" bind:checked={isLiquid} /> This ingredient is a liquid</label>
    </fieldset>

    <fieldset>
      <legend>Package Size</legend>
      <label>Quantity <input type="number" step="any" bind:value={packageQty} /></label>
      <label>
        Unit
        <select bind:value={packageUnit}>
          <option value="g">grams</option>
          <option value="ml">milliliters</option>
        </select>
      </label>
    </fieldset>

    <fieldset>
      <legend>Nutrition (as shown on the label, per {labelServingG || '...'}g serving)</legend>

      <label>
        Serving size on label (grams)
        <input type="number" step="any" bind:value={labelServingG} required />
      </label>

      <label>Energy (kcal) <input type="number" step="any" bind:value={energyKcal} /></label>
      <label>Fat (g) <input type="number" step="any" bind:value={fatG} /></label>
      <label>Saturated Fat (g) <input type="number" step="any" bind:value={saturatedFatG} /></label>
      <label>Trans Fat (g) <input type="number" step="any" bind:value={transFatG} /></label>
      <label>Carbohydrate (g) <input type="number" step="any" bind:value={carbohydrateG} /></label>
      <label>Fibre (g) <input type="number" step="any" bind:value={fibreG} /></label>
      <label>Sugars (g) <input type="number" step="any" bind:value={sugarsG} /></label>
      <label>Protein (g) <input type="number" step="any" bind:value={proteinG} /></label>
      <label>Sodium (mg) <input type="number" step="any" bind:value={sodiumMg} /></label>
      <label>Vitamin D (mcg) <input type="number" step="any" bind:value={vitaminDMcg} /></label>
      <label>Calcium (mg) <input type="number" step="any" bind:value={calciumMg} /></label>
      <label>Iron (mg) <input type="number" step="any" bind:value={ironMg} /></label>
      <label>Potassium (mg) <input type="number" step="any" bind:value={potassiumMg} /></label>
    </fieldset>

    <fieldset>
      <legend>Your Price (private to you)</legend>

      <label>What you paid <input type="number" step="any" bind:value={purchasePrice} /></label>

      {#if !packageQty}
        <label>Quantity <input type="number" step="any" bind:value={purchaseQty} /></label>
        <label>
          Unit
          <select bind:value={purchaseUnit}>
            <option value="g">grams</option>
            <option value="ml">milliliters</option>
          </select>
        </label>
      {:else}
        <p>Using the package size entered above ({packageQty}{packageUnit}).</p>
      {/if}
    </fieldset>

    {#if errorMessage}
      <p class="error">{errorMessage}</p>
    {/if}

<button type="submit" disabled={saving}>
  {saving ? 'Saving...' : 'Save Changes'}
</button>

<button type="button" onclick={handleToggleArchive}>
  {archived ? 'Unarchive this ingredient' : 'Archive this ingredient'}
</button>
  </form>
{/if}