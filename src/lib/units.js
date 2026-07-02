// Converts common kitchen units to the app's canonical base units:
// grams for solids, milliliters for liquids.

const VOLUME_TO_ML = {
  ml: 1,
  l: 1000,
  tsp: 4.929,
  tbsp: 14.787,
  cup: 236.588,
  "fl oz": 29.574,
};

const WEIGHT_TO_G = {
  g: 1,
  kg: 1000,
  oz: 28.3495,
  lb: 453.592,
};

export const VOLUME_UNITS = Object.keys(VOLUME_TO_ML);
export const WEIGHT_UNITS = Object.keys(WEIGHT_TO_G);
export const EACH_UNIT = "each";

// Original simple version — still used internally, and still fine
// for any code that only cares about plain weight/volume conversion.
export function toBaseUnit(quantity, unit, isLiquid) {
  const table = isLiquid ? VOLUME_TO_ML : WEIGHT_TO_G;
  const factor = table[unit];
  if (!factor)
    throw new Error(
      `Unknown unit "${unit}" for ${isLiquid ? "liquid" : "solid"}`,
    );
  return quantity * factor;
}

// Every unit this specific ingredient can be measured in, given
// what conversion data it has on file. Base weight/volume units are
// always available; cup-style volume units for a solid, and "each,"
// only show up if the ingredient has the matching conversion factor set.
export function unitsForIngredient(ingredient) {
  const units = ingredient.is_liquid ? [...VOLUME_UNITS] : [...WEIGHT_UNITS];

  if (!ingredient.is_liquid && ingredient.grams_per_cup) {
    units.push(...VOLUME_UNITS);
  }
  if (ingredient.grams_per_each) {
    units.push(EACH_UNIT);
  }

  return units;
}

// Converts a quantity in ANY unit this ingredient supports (weight,
// volume, or "each") into canonical grams/ml. Needs the full
// ingredient record, not just is_liquid, since cup/each conversions
// depend on that ingredient's specific conversion factors.
export function toBaseUnitForIngredient(quantity, unit, ingredient) {
  if (unit === EACH_UNIT) {
    if (!ingredient.grams_per_each) {
      throw new Error(
        `${ingredient.name} doesn't have an average weight set for "each" yet — add one on its ingredient page.`,
      );
    }
    return quantity * ingredient.grams_per_each;
  }

  if (ingredient.is_liquid) {
    return toBaseUnit(quantity, unit, true);
  }

  if (WEIGHT_UNITS.includes(unit)) {
    return toBaseUnit(quantity, unit, false);
  }

  if (VOLUME_UNITS.includes(unit)) {
    if (!ingredient.grams_per_cup) {
      throw new Error(
        `${ingredient.name} doesn't have a grams-per-cup value set — add one on its ingredient page to measure it by volume.`,
      );
    }
    const ml = toBaseUnit(quantity, unit, true);
    const gramsPerMl = ingredient.grams_per_cup / VOLUME_TO_ML.cup;
    return ml * gramsPerMl;
  }

  throw new Error(`Unknown unit "${unit}" for ${ingredient.name}`);
}
