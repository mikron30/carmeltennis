"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {getIngressSettings} = require("../src/video/config");
const {
  assertPhysicalClipInReservationSlot,
  managerClipWindow,
  physicalClipWindow,
} = require("../src/video/ingress");

test("physical button selects exactly forty seconds immediately before press", () => {
  // 18:06:17 UTC is 21:06:17 Asia/Jerusalem on 2026-08-17.
  const pressedAt = new Date("2026-08-17T18:06:17.000Z");
  const settings = getIngressSettings({});

  const {clipStart, clipEnd} = physicalClipWindow(pressedAt, settings);

  assert.equal(clipStart.toISOString(), "2026-08-17T18:05:37.000Z");
  assert.equal(clipEnd.toISOString(), "2026-08-17T18:06:17.000Z");
  assert.equal(clipEnd, pressedAt);
  assert.equal((clipEnd.getTime() - clipStart.getTime()) / 1000, 40);
});

test("manager interval remains the selected preceding ten seconds", () => {
  const pressedAt = new Date("2026-08-12T19:00:40.000Z");
  const settings = getIngressSettings({VIDEO_CLIP_LEAD_SECONDS: "10"});

  const {clipStart, clipEnd} = managerClipWindow(pressedAt, settings);

  assert.equal(settings.clipLeadSeconds, 10);
  assert.equal(clipStart.toISOString(), "2026-08-12T19:00:30.000Z");
  assert.equal(clipEnd.toISOString(), pressedAt.toISOString());
});

test("current or next reservation rejects footage crossing an hour", () => {
  const settings = getIngressSettings({});
  const pressedAt = new Date("2026-08-12T19:00:39.999Z");
  const {clipStart} = physicalClipWindow(pressedAt, settings);

  for (const source of ["current", "next"]) {
    assert.throws(
        () => assertPhysicalClipInReservationSlot(
            pressedAt,
            clipStart,
            source,
        ),
        (error) => error.code === "reservation_boundary" &&
          error.httpStatus === 409,
    );
  }
});

test("physical button allows the exact forty-second reservation boundary", () => {
  const settings = getIngressSettings({});
  const pressedAt = new Date("2026-08-12T19:00:40.000Z");
  const {clipStart} = physicalClipWindow(pressedAt, settings);

  assert.doesNotThrow(
      () => assertPhysicalClipInReservationSlot(pressedAt, clipStart),
  );
});

test("previous reservation and closing extension may cross the hour", () => {
  const settings = getIngressSettings({});
  const pressedAt = new Date("2026-08-12T19:00:05.000Z");
  const {clipStart} = physicalClipWindow(pressedAt, settings);

  for (const source of ["previous", "closing_extension"]) {
    assert.doesNotThrow(
        () => assertPhysicalClipInReservationSlot(
            pressedAt,
            clipStart,
            source,
        ),
    );
  }
});
