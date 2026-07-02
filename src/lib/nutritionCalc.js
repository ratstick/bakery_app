// Shared nutrition math, used anywhere we need to total up a recipe's
// ingredients — currently the CFIA label. Kept separate so this logic
// only exists in one place, rather than being copy-pasted per page.

export const NUTRITION_FIELDS = [
  "energy_kcal",
  "fat_g",
  "saturated_fat_g",
  "trans_fat_g",
  "carbohydrate_g",
  "fibre_g",
  "sugars_g",
  "protein_g",
  "sodium_mg",
  "vitamin_d_mcg",
  "calcium_mg",
  "iron_mg",
  "potassium_mg",
];

// items: array of { ingredient, quantityG }
export function computeTotals(items) {
  const result = {};
  for (const field of NUTRITION_FIELDS) {
    const values = items
      .map((item) => {
        const perHundred = item.ingredient[field];
        if (
          item.quantityG === null ||
          perHundred === null ||
          perHundred === undefined
        )
          return null;
        return (perHundred * item.quantityG) / 100;
      })
      .filter((v) => v !== null);
    result[field] = values.length ? values.reduce((a, b) => a + b, 0) : null;
  }
  return result;
}

export function perServing(totals, servings) {
  const result = {};
  for (const field of NUTRITION_FIELDS) {
    result[field] = totals[field] === null ? null : totals[field] / servings;
  }
  return result;
}

// Canada's %DV reference amounts (Health Canada, 2016 table).
// Carbohydrate and Protein have no %DV line on a CFIA label.
export const DAILY_VALUES = {
  fat_g: 75,
  fibre_g: 28,
  sugars_g: 100,
  sodium_mg: 2300,
  potassium_mg: 3400,
  calcium_mg: 1300,
  iron_mg: 18,
  vitamin_d_mcg: 20,
};

export function percentDV(amount, reference) {
  if (amount === null || amount === undefined) return null;
  return Math.round((amount / reference) * 100);
}
