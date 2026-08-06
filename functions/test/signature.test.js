"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  canonicalEspMessage,
  signEspPayload,
  verifyEspPayload,
} = require("../src/video/signature");

const secret = "test-only-device-secret-at-least-16";
const now = new Date("2026-08-04T10:00:00.000Z");

function signedPayload(overrides = {}) {
  const payload = {
    courtNumber: 1,
    deviceId: "court-one-button",
    timestamp: Math.floor(now.getTime() / 1000),
    nonce: "nonce_for_test_0001",
    ...overrides,
  };
  return {...payload, signature: signEspPayload(payload, secret)};
}

const keys = JSON.stringify({
  "court-one-button": {secret, courts: [1]},
});

test("canonical ESP32 payload has an unambiguous v1 form", () => {
  assert.equal(
      canonicalEspMessage(signedPayload()),
      "v1\ncourt-one-button\n1\n1785837600\nnonce_for_test_0001",
  );
});

test("valid signature is accepted with a timing-safe comparison", () => {
  const payload = signedPayload();
  const verified = verifyEspPayload(payload, keys, {
    now,
    timestampToleranceSeconds: 90,
  });
  assert.deepEqual(verified, {
    courtNumber: 1,
    deviceId: "court-one-button",
    timestamp: 1785837600,
    nonce: "nonce_for_test_0001",
    signature: payload.signature,
  });
});

test("a signed field cannot be altered after signing", () => {
  const payload = signedPayload({courtNumber: 2});
  // The signature above deliberately uses the court-two data with the court
  // one key configuration, so court authorization fails before acceptance.
  assert.throws(
      () => verifyEspPayload(payload, keys, {now}),
      (error) => error.code === "unauthorized",
  );

  const tampered = signedPayload();
  tampered.nonce = "nonce_for_test_0002";
  assert.throws(
      () => verifyEspPayload(tampered, keys, {now}),
      (error) => error.code === "unauthorized",
  );
});

test("stale timestamps are rejected before a Firestore write", () => {
  const payload = signedPayload({timestamp: 1785837000});
  payload.signature = signEspPayload(payload, secret);
  assert.throws(
      () => verifyEspPayload(payload, keys, {
        now,
        timestampToleranceSeconds: 90,
      }),
      (error) => error.code === "stale_request",
  );
});
