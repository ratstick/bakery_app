<script>
  import { onMount } from 'svelte';
  import { supabase } from '$lib/supabase.js';
  import { toBaseUnitForIngredient, unitsForIngredient } from '$lib/units.js';

  let rows = $state([]); // { ingredient, inventoryId, currentStockG, inputQty, inputUnit }
  let loading = $state(true);
  let errorMessage = $state('');

  onMount(async () => {
    const { data: ingredients } = await supabase
      .from('ingredients')
      .select('*')
      .eq('archived', false)
      .order('name');

    // RLS already scopes this to the current user — everyone else's stock is invisible here.
    const { data: inventoryData } = await supabase.from('inventory').select('*');

    rows = (ingredients ?? []).map((ingredient) => {
      const existing = inventoryData?.find((inv) => inv.ingredient_id === ingredient.id);
      const units = unitsForIngredient(ingredient);
      return {
        ingredient,
        inventoryId: existing?.id ?? null,
        currentStockG: existing?.quantity_g ?? 0,
        inputQty: '',
        inputUnit: units[0] ?? ''
      };
    });

    loading = false;
  });

  // Shows stock in a friendlier unit than raw grams/ml once it gets large.
  // This is purely display formatting — always g/ml/kg/L, regardless of
  // whether the ingredient also supports cup/each entry.
  function formatStock(quantityG, isLiquid) {
    if (isLiquid) {
      return quantityG >= 1000 ? `${(quantityG / 1000).toFixed(2)} L` : `${quantityG.toFixed(0)} ml`;
    }
    return quantityG >= 1000 ? `${(quantityG / 1000).toFixed(2)} kg` : `${quantityG.toFixed(0)} g`;
  }

  async function handleUpdateStock(row) {
    errorMessage = '';

    if (row.inputQty === '' || !row.inputUnit) {
      errorMessage = 'Enter a quantity and unit first.';
      return;
    }

    let quantityG;
    try {
      quantityG = toBaseUnitForIngredient(Number(row.inputQty), row.inputUnit, row.ingredient);
    } catch (err) {
      errorMessage = err.message;
      return;
    }

    const { error } = await supabase
      .from('inventory')
      .upsert(
        {
          ingredient_id: row.ingredient.id,
          quantity_g: quantityG,
          last_updated: new Date().toISOString()
        },
        { onConflict: 'user_id,ingredient_id' }
      );

    if (error) {
      errorMessage = error.message;
      return;
    }

    row.currentStockG = quantityG;
    row.inputQty = '';
  }
</script>

<h1>Inventory</h1>

{#if loading}
  <p>Loading...</p>
{:else}
  {#if errorMessage}<p class="error">{errorMessage}</p>{/if}

  <table>
    <thead>
      <tr>
        <th>Ingredient</th>
        <th>Current Stock</th>
        <th>Set Stock To</th>
        <th></th>
      </tr>
    </thead>
    <tbody>
      {#each rows as row}
        <tr>
          <td>{row.ingredient.name}</td>
          <td>{formatStock(row.currentStockG, row.ingredient.is_liquid)}</td>
          <td>
            <input type="number" step="any" bind:value={row.inputQty} style="width: 5em;" />
            <select bind:value={row.inputUnit}>
              {#each unitsForIngredient(row.ingredient) as unit}
                <option value={unit}>{unit}</option>
              {/each}
            </select>
          </td>
          <td><button onclick={() => handleUpdateStock(row)}>Update</button></td>
        </tr>
      {/each}
    </tbody>
  </table>
{/if}