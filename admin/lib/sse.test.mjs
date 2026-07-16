import assert from "node:assert/strict";
import test from "node:test";

import { drainSseFrames, parseSseFrame } from "./sse.ts";

test("parses a tenant order event and ignores comments", () => {
  const frame = parseSseFrame(
    ': keepalive\nid: 12\nevent: order.created\ndata: {"orderId":"o-1"}'
  );
  assert.deepEqual(frame, {
    id: "12",
    event: "order.created",
    data: '{"orderId":"o-1"}',
    retry: undefined
  });
});

test("drains complete CRLF frames and keeps a partial tail", () => {
  const result = drainSseFrames(
    "retry: 1500\r\nevent: reconcile\r\ndata: {}\r\n\r\nevent: order.updated\ndata: {"
  );
  assert.equal(result.frames.length, 1);
  assert.equal(result.frames[0].event, "reconcile");
  assert.equal(result.frames[0].retry, 1500);
  assert.equal(result.rest, "event: order.updated\ndata: {");
});
