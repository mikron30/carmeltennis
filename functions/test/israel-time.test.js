"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  israelLocalDateTimeToUtc,
  parseManagerTime,
} = require("../src/video/israel-time");

test("manager time accepts optional seconds", () => {
  assert.deepEqual(parseManagerTime("17:30"), {hour: 17, minute: 30, second: 0});
  assert.deepEqual(parseManagerTime("17:30:45"), {hour: 17, minute: 30, second: 45});
  assert.throws(() => parseManagerTime("17:30:60"));
});

test("manager Israel wall-clock time preserves the selected seconds", () => {
  const instant = israelLocalDateTimeToUtc("2026-08-06", "17:30:45");

  assert.equal(instant.toISOString(), "2026-08-06T14:30:45.000Z");
});
