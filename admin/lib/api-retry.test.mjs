import assert from "node:assert/strict";
import test from "node:test";

import {
  isIdempotentRead,
  READ_RETRY_DELAYS_MS,
  shouldRetryRead
} from "./api-retry.ts";

test("retries only idempotent reads", () => {
  assert.equal(isIdempotentRead(undefined), true);
  assert.equal(isIdempotentRead("get"), true);
  assert.equal(isIdempotentRead("HEAD"), true);
  assert.equal(isIdempotentRead("POST"), false);
  assert.equal(shouldRetryRead("GET", 500), true);
  assert.equal(shouldRetryRead("GET", 504), true);
  assert.equal(shouldRetryRead("GET", 422), false);
  assert.equal(shouldRetryRead("PATCH", 500), false);
});

test("uses two short backoff delays", () => {
  assert.deepEqual(READ_RETRY_DELAYS_MS, [250, 750]);
});
