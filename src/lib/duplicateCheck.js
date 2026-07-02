import { toBaseUnitForIngredient } from "./units.js";

// Finds rows that share the same ingredient + component combination.
// Returns an array of arrays, where each inner array is a group of
// row *indexes* that collide with each other.
export function findDuplicateGroups(rows) {
  const seen = new Map(); // key: "ingredientId|component" -> array of row indexes

  rows.forEach((row, index) => {
    if (!row.ingredient_id) return; // not filled in yet, nothing to check
    const key = `${row.ingredient_id}|${row.component || ""}`;
    if (!seen.has(key)) seen.set(key, []);
    seen.get(key).push(index);
  });

  return [...seen.values()].filter((group) => group.length > 1);
}

// Combines two duplicate rows into one, summing their quantities.
// Converts both to the canonical base unit first (grams or ml) so
// mismatched display units (e.g. one in grams, one in ounces) still
// add up correctly, then re-expresses the result in the first row's
// display unit for consistency.
export function mergeRows(rowA, rowB, ingredient) {
  const totalBase =
    toBaseUnitForIngredient(Number(rowA.display_qty), rowA.display_unit, ingredient) +
    toBaseUnitForIngredient(Number(rowB.display_qty), rowB.display_unit, ingredient);

  const factor = toBaseUnitForIngredient(1, rowA.display_unit, ingredient);
  const mergedQty = totalBase / factor;

  return {
    ...rowA,
    display_qty: Math.round(mergedQty * 1000) / 1000,
  };
}
