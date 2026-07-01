// Converts common kitchen units to the app's canonical base units:
// grams for solids, milliliters for liquids.
// Users can enter quantities however they think in the kitchen —
// this is what makes that possible without every calculation
// downstream needing to know about cups or tablespoons.
//
// Limitation: this only converts within the same kind of unit
// (volume-to-volume or weight-to-weight). Converting "1 cup of flour"
// to grams requires ingredient density, which isn't tracked yet.

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

export function toBaseUnit(quantity, unit, isLiquid) {
  const table = isLiquid ? VOLUME_TO_ML : WEIGHT_TO_G;
  const factor = table[unit];
  if (!factor)
    throw new Error(
      `Unknown unit "${unit}" for ${isLiquid ? "liquid" : "solid"}`,
    );
  return quantity * factor;
}
