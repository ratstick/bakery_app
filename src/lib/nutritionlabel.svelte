<script>
  import { DAILY_VALUES, percentDV } from './nutritionCalc.js';

  let { nutrition = $bindable(), servingSizeG, editable = false } = $props();

  const satTransTotal = $derived((nutrition.saturated_fat_g ?? 0) + (nutrition.trans_fat_g ?? 0));
  const satTransDV = $derived(percentDV(satTransTotal, 20));
  const kJ = $derived(nutrition.energy_kcal !== null ? Math.round(nutrition.energy_kcal * 4.184) : null);

  function fmt(value, decimals = 1) {
    return value === null || value === undefined ? '—' : Number(value).toFixed(decimals);
  }
  function fmtDV(value) {
    return value === null || value === undefined ? '—' : `${value}%`;
  }
</script>

<div class="nutrition-label">
  <h2>Nutrition Facts</h2>
  <p class="serving">Per {servingSizeG} g</p>

  <hr class="thick" />

  <p class="calories">
    Calories
    {#if editable}
      <input type="number" step="any" bind:value={nutrition.energy_kcal} class="inline-input" />
    {:else}
      {fmt(nutrition.energy_kcal, 0)}
    {/if}
    <span class="kj">{kJ ?? '—'} kJ</span>
  </p>

  <hr class="thick" />

  <p class="dv-header">% Daily Value*</p>

  <table>
    <tbody>
      <tr>
        <td>
          Fat
          {#if editable}<input type="number" step="any" bind:value={nutrition.fat_g} class="inline-input" />{:else}{fmt(nutrition.fat_g)}{/if}
          g
        </td>
        <td>{fmtDV(percentDV(nutrition.fat_g, DAILY_VALUES.fat_g))}</td>
      </tr>
      <tr>
        <td class="indent">
          Saturated {#if editable}<input type="number" step="any" bind:value={nutrition.saturated_fat_g} class="inline-input" />{:else}{fmt(nutrition.saturated_fat_g)}{/if} g
          + Trans {#if editable}<input type="number" step="any" bind:value={nutrition.trans_fat_g} class="inline-input" />{:else}{fmt(nutrition.trans_fat_g)}{/if} g
        </td>
        <td>{fmtDV(satTransDV)}</td>
      </tr>
      <tr>
        <td>
          Carbohydrate
          {#if editable}<input type="number" step="any" bind:value={nutrition.carbohydrate_g} class="inline-input" />{:else}{fmt(nutrition.carbohydrate_g)}{/if}
          g
        </td>
        <td></td>
      </tr>
      <tr>
        <td class="indent">
          Fibre {#if editable}<input type="number" step="any" bind:value={nutrition.fibre_g} class="inline-input" />{:else}{fmt(nutrition.fibre_g)}{/if} g
        </td>
        <td>{fmtDV(percentDV(nutrition.fibre_g, DAILY_VALUES.fibre_g))}</td>
      </tr>
      <tr>
        <td class="indent">
          Sugars {#if editable}<input type="number" step="any" bind:value={nutrition.sugars_g} class="inline-input" />{:else}{fmt(nutrition.sugars_g)}{/if} g
        </td>
        <td>{fmtDV(percentDV(nutrition.sugars_g, DAILY_VALUES.sugars_g))}</td>
      </tr>
      <tr>
        <td>
          Protein {#if editable}<input type="number" step="any" bind:value={nutrition.protein_g} class="inline-input" />{:else}{fmt(nutrition.protein_g)}{/if} g
        </td>
        <td></td>
      </tr>
      <tr class="section-break"><td colspan="2"></td></tr>
      <tr>
        <td>
          Sodium {#if editable}<input type="number" step="any" bind:value={nutrition.sodium_mg} class="inline-input" />{:else}{fmt(nutrition.sodium_mg, 0)}{/if} mg
        </td>
        <td>{fmtDV(percentDV(nutrition.sodium_mg, DAILY_VALUES.sodium_mg))}</td>
      </tr>
      <tr>
        <td>
          Potassium {#if editable}<input type="number" step="any" bind:value={nutrition.potassium_mg} class="inline-input" />{:else}{fmt(nutrition.potassium_mg, 0)}{/if} mg
        </td>
        <td>{fmtDV(percentDV(nutrition.potassium_mg, DAILY_VALUES.potassium_mg))}</td>
      </tr>
      <tr>
        <td>
          Calcium {#if editable}<input type="number" step="any" bind:value={nutrition.calcium_mg} class="inline-input" />{:else}{fmt(nutrition.calcium_mg, 0)}{/if} mg
        </td>
        <td>{fmtDV(percentDV(nutrition.calcium_mg, DAILY_VALUES.calcium_mg))}</td>
      </tr>
      <tr>
        <td>
          Iron {#if editable}<input type="number" step="any" bind:value={nutrition.iron_mg} class="inline-input" />{:else}{fmt(nutrition.iron_mg)}{/if} mg
        </td>
        <td>{fmtDV(percentDV(nutrition.iron_mg, DAILY_VALUES.iron_mg))}</td>
      </tr>
      <tr>
        <td>
          Vitamin D {#if editable}<input type="number" step="any" bind:value={nutrition.vitamin_d_mcg} class="inline-input" />{:else}{fmt(nutrition.vitamin_d_mcg)}{/if} mcg
        </td>
        <td>{fmtDV(percentDV(nutrition.vitamin_d_mcg, DAILY_VALUES.vitamin_d_mcg))}</td>
      </tr>
    </tbody>
  </table>

  <hr class="thin" />

  <p class="footnote">*5% or less is a little, 15% or more is a lot</p>

  <p class="disclaimer">
    This label is generated for reference using standard Health Canada daily
    values. It has not been verified against official CFIA rounding rules and
    should be reviewed before use on products offered for sale.
  </p>
</div>

<style>
  .nutrition-label {
    border: 2px solid black;
    padding: 0.5rem;
    max-width: 300px;
    font-family: Arial, sans-serif;
    color: black;
    background: white;
  }
  h2 { margin: 0; font-size: 1.5rem; }
  .serving { margin: 0.25rem 0; }
  hr.thick { border: none; border-top: 8px solid black; margin: 0.25rem 0; }
  hr.thin { border: none; border-top: 1px solid black; margin: 0.25rem 0; }
  .calories { font-size: 1.5rem; font-weight: bold; margin: 0.25rem 0; display: flex; align-items: center; gap: 0.5rem; }
  .kj { font-size: 1rem; font-weight: normal; margin-left: auto; }
  .dv-header { text-align: right; font-weight: bold; margin: 0.25rem 0; font-size: 0.85rem; }
  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  td { padding: 0.15rem 0; border-top: 1px solid #ccc; }
  td:last-child { text-align: right; font-weight: bold; }
  .indent { padding-left: 1rem; font-weight: normal; }
  .section-break td { border-top: 4px solid black; padding: 0; }
  .footnote { font-size: 0.75rem; margin-top: 0.25rem; }
  .disclaimer { font-size: 0.7rem; color: #444; margin-top: 0.5rem; font-style: italic; }
  .inline-input {
    width: 3.5em;
    font: inherit;
    text-align: right;
    border: 1px solid #999;
    background: #fffbe6;
    color: black;
  }
  @media print {
    .inline-input {
      border: none;
      background: none;
    }
  }
</style>