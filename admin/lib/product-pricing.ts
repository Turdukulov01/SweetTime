export interface FinalPriceSize {
  priceDelta: number;
}

/**
 * Admin drafts keep size values as final prices because that is what an
 * operator enters. The API keeps a base + delta contract for Flutter and
 * server-side order calculation, so conversion happens once on Save.
 */
export function normalizeProductPricing<T extends FinalPriceSize>(
  priceText: string,
  sizes: T[]
): { basePrice: number; hasPrice: boolean; sizes: T[] } {
  const trimmed = priceText.trim();
  const explicitPrice = trimmed
    ? Math.max(0, Math.round(Number(trimmed)) || 0)
    : null;
  const finalPrices = sizes.map((size) => size.priceDelta);
  const basePrice =
    explicitPrice ?? (finalPrices.length > 0 ? Math.min(...finalPrices) : 0);

  return {
    basePrice,
    hasPrice:
      explicitPrice !== null || finalPrices.some((finalPrice) => finalPrice > 0),
    sizes: sizes.map((size) => ({
      ...size,
      priceDelta: size.priceDelta - basePrice
    }))
  };
}
