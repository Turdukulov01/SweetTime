import test from "node:test";
import assert from "node:assert/strict";

import { normalizeProductPricing } from "./product-pricing.ts";

test("derives an omitted base from the lowest final size price", () => {
  const result = normalizeProductPricing("", [
    { id: "s", priceDelta: 300 },
    { id: "m", priceDelta: 350 },
    { id: "l", priceDelta: 400 }
  ]);

  assert.equal(result.basePrice, 300);
  assert.equal(result.hasPrice, true);
  assert.deepEqual(
    result.sizes.map((size) => size.priceDelta),
    [0, 50, 100]
  );
});

test("keeps an explicit base and converts final prices into deltas", () => {
  const result = normalizeProductPricing("4000", [
    { id: "s", priceDelta: 3000 },
    { id: "l", priceDelta: 4000 }
  ]);

  assert.equal(result.basePrice, 4000);
  assert.deepEqual(
    result.sizes.map((size) => size.priceDelta),
    [-1000, 0]
  );
});

test("rejects an implicit free product with neither base nor sizes", () => {
  const result = normalizeProductPricing("", []);
  assert.equal(result.basePrice, 0);
  assert.equal(result.hasPrice, false);
});
