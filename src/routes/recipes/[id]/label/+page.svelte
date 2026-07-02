<script>
  import { onMount } from 'svelte';
  import { page } from '$app/stores';
  import { supabase } from '$lib/supabase.js';
  import { computeTotals, perServing } from '$lib/nutritionCalc.js';
  import NutritionLabel from '$lib/NutritionLabel.svelte';

  const recipeId = $page.params.id;

  let recipe = $state(null);
  let displayNutrition = $state(null); // what's shown/printed — starts as calculated, may be edited
  let loading = $state(true);
  let errorMessage = $state('');
  let isEditing = $state(false);
  let printing = $state(false);

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

    const { data: riData, error: riError } = await supabase
      .from('recipe_ingredients')
      .select('quantity_g, ingredients(*)')
      .eq('recipe_id', recipeId);

    if (riError) {
      errorMessage = riError.message;
      loading = false;
      return;
    }

    const items = riData.map((r) => ({ ingredient: r.ingredients, quantityG: r.quantity_g }));
    const totals = computeTotals(items);
    displayNutrition = perServing(totals, recipe.servings);

    loading = false;
  });

  // Logs what was actually printed, then opens the browser print dialog.
  // Runs for both the plain "print as calculated" path and the
  // "looks good, let's print" path after editing.
  async function handlePrint(wasAdjusted) {
    errorMessage = '';
    printing = true;

    const { error } = await supabase.from('label_overrides').insert({
      recipe_id: recipeId,
      recipe_name_snapshot: recipe.name,
      serving_size_g_snapshot: recipe.serving_size_g,
      nutrition_snapshot: displayNutrition,
      was_manually_adjusted: wasAdjusted
    });

    printing = false;

    if (error) {
      errorMessage = error.message;
      return;
    }

    window.print();
  }

  function confirmAndPrint() {
    isEditing = false;
    handlePrint(true);
  }
</script>

{#if loading}
  <p>Loading...</p>
{:else if errorMessage && !recipe}
  <p class="error">{errorMessage}</p>
{:else}
  <div class="no-print">
    <a href="/recipes/{recipe.id}">&larr; Back to recipe</a>

    {#if !isEditing}
      <button onclick={() => (isEditing = true)}>Edit values before printing</button>
      <button onclick={() => handlePrint(false)} disabled={printing}>
        {printing ? 'Preparing...' : 'Print as calculated'}
      </button>
    {:else}
      <p><em>Editing values — these will be shown on the printed label exactly as typed. % Daily Value updates automatically based on what you enter.</em></p>
      <button onclick={confirmAndPrint} disabled={printing}>
        {printing ? 'Preparing...' : "Looks good, let's print"}
      </button>
      <button onclick={() => (isEditing = false)}>Cancel editing</button>
    {/if}

    {#if errorMessage}<p class="error">{errorMessage}</p>{/if}
  </div>
<div class="no-print">
  <h1>{recipe.name}</h1>
  </div>
  <NutritionLabel bind:nutrition={displayNutrition} servingSizeG={recipe.serving_size_g} editable={isEditing} />
{/if}