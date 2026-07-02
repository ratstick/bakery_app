<script>
  import { goto } from '$app/navigation';
  import { supabase } from '$lib/supabase.js';

  // --- Shared ingredient fields ---
  let name = $state('');
  let brand = $state('');
  let category = $state('');
  let barcode = $state('');
  let isLiquid = $state(false);
  let packageQty = $state('');
  let packageUnit = $state('g');
  let labelServingG = $state('');

  // --- Nutrition, per 100g/100ml ---
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
  let gramsPerCup = $state('');
  let gramsPerEach = $state('');

  // --- Your price (private) ---
  let purchasePrice = $state('');
  // Only asked for if no shared package size is being entered above
  let purchaseQty = $state('');
  let purchaseUnit = $state('g');

  let errorMessage = $state('');
  let saving = $state(false);

  

  // Convert empty strings to null so optional numeric fields
  // don't get stored as invalid numbers in Postgres.
  function numOrNull(value) {
    return value === '' ? null : Number(value);
  }
  function per100g(value, servingG) {
  if (value === '' || !servingG) return null;
  return (Number(value) / Number(servingG)) * 100;
}

  async function handleSubmit() {
    saving = true;
    errorMessage = '';

    const { data: ingredient, error: ingredientError } = await supabase
      .from('ingredients')
      .insert({
        name,
        brand: brand || null,
        category: category || null,
        barcode: barcode || null,
        is_liquid: isLiquid,
        package_qty: numOrNull(packageQty),
        package_unit: packageQty ? packageUnit : null,
        label_serving_g: numOrNull(labelServingG),

        energy_kcal: per100g(energyKcal, labelServingG),
        fat_g: per100g(fatG, labelServingG),
        saturated_fat_g: per100g(saturatedFatG, labelServingG),
        trans_fat_g: per100g(transFatG, labelServingG),
        carbohydrate_g: per100g(carbohydrateG, labelServingG),
        fibre_g: per100g(fibreG, labelServingG),
        sugars_g: per100g(sugarsG, labelServingG),
        protein_g: per100g(proteinG, labelServingG),
        sodium_mg: per100g(sodiumMg, labelServingG),
        vitamin_d_mcg: per100g(vitaminDMcg, labelServingG),
        calcium_mg: per100g(calciumMg, labelServingG),
        iron_mg: per100g(ironMg, labelServingG),
        potassium_mg: per100g(potassiumMg, labelServingG),
        grams_per_cup: numOrNull(gramsPerCup),
        grams_per_each: numOrNull(gramsPerEach),
      })
      .select()
      .single();

    if (ingredientError) {
      errorMessage = ingredientError.message;
      saving = false;
      return;
    }

    // Only insert a cost row if a price was entered
    if (purchasePrice) {
      const { error: costError } = await supabase
        .from('user_ingredient_costs')
        .insert({
          ingredient_id: ingredient.id,
          purchase_price: Number(purchasePrice),
          // Only stored if there's no shared package size to rely on
          purchase_qty: packageQty ? null : numOrNull(purchaseQty),
          purchase_unit: packageQty ? null : purchaseUnit
        });

      if (costError) {
        errorMessage = costError.message;
        saving = false;
        return;
      }
    }

    saving = false;
    goto('/ingredients');
  }
</script>

<h1>Add Ingredient</h1>

<form onsubmit={(e) => { e.preventDefault(); handleSubmit(); }}>

  <fieldset>
    <legend>Basics</legend>

    <label>
      Name
      <input type="text" bind:value={name} required />
    </label>

    <label>
      Brand
      <input type="text" bind:value={brand} />
    </label>

    <label>
      Category
      <input type="text" bind:value={category} placeholder="e.g. Spices, Condiments" />
    </label>

    <label>
      Barcode
      <input type="text" bind:value={barcode} placeholder="optional, for future scanning" />
    </label>

    <label>
      <input type="checkbox" bind:checked={isLiquid} />
      This ingredient is a liquid
    </label>
  </fieldset>

  <fieldset>
    <legend>Package Size</legend>
    <p>If this product always comes in a fixed size (e.g. a 200g jar), enter it here so future users don't have to.</p>

    <label>
      Quantity
      <input type="number" step="any" bind:value={packageQty} />
    </label>

    <label>
      Unit
      <select bind:value={packageUnit}>
        <option value="g">grams</option>
        <option value="ml">milliliters</option>
      </select>
    </label>
    <label>
  Grams per cup <em>(optional — lets this be measured in cups/tbsp/tsp, e.g. flour)</em>
  <input type="number" step="any" bind:value={gramsPerCup} />
</label>
<label>
  Average grams per each <em>(optional — for count-based ingredients like eggs)</em>
  <input type="number" step="any" bind:value={gramsPerEach} />
</label>
  </fieldset>

  <fieldset>
    <legend>Nutrition (as shown on the label, per {labelServingG || '...'}g serving)</legend>

    <label>Serving size on label (grams)<input type="number" step="any" bind:value={labelServingG} required /></label>
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

    <label>
      What you paid
      <input type="number" step="any" bind:value={purchasePrice} placeholder="e.g. 4.99" />
    </label>

    {#if !packageQty}
      <p>No package size was entered above, so tell us how much that price covers:</p>
      <label>
        Quantity
        <input type="number" step="any" bind:value={purchaseQty} />
      </label>
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
    {saving ? 'Saving...' : 'Save Ingredient'}
  </button>
</form>