"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {findActiveReservation} = require("../src/video/reservations");

const slot = {date: "2026-08-04", courtNumber: 2, hour: 18};

function doc(id, data) {
  return {id, data: () => data};
}

test("reservation lookup accepts legacy numeric strings and collapses identical duplicates", () => {
  const reservation = findActiveReservation([
    doc("new-id", {
      date: "2026-08-04",
      courtNumber: 2,
      hour: 18,
      isReserved: true,
      userName: "  Player One ",
      partner: "Player   Two",
    }),
    doc("legacy-id", {
      date: "2026-08-04",
      courtNumber: "2",
      hour: "18",
      userName: "Player One",
      partner: "Player Two",
    }),
  ], slot);

  assert.deepEqual(reservation, {
    id: "new-id",
    userName: "Player One",
    partner: "Player Two",
    documentIds: ["legacy-id", "new-id"],
  });
});

test("reservation lookup rejects conflicting records for one logical cell", () => {
  assert.throws(
      () => findActiveReservation([
        doc("a", {
          date: slot.date, courtNumber: 2, hour: 18,
          userName: "First Player", partner: "Partner A",
        }),
        doc("b", {
          date: slot.date, courtNumber: 2, hour: 18,
          userName: "Second Player", partner: "Partner B",
        }),
      ], slot),
      (error) => error.code === "reservation_ambiguous",
  );
});

test("reservation lookup ignores explicitly cancelled records and reports no active cell", () => {
  assert.throws(
      () => findActiveReservation([
        doc("cancelled", {
          date: slot.date, courtNumber: 2, hour: 18,
          isReserved: false, userName: "First", partner: "Second",
        }),
      ], slot),
      (error) => error.code === "reservation_not_found",
  );
});

test("reservation lookup requires both player names", () => {
  assert.throws(
      () => findActiveReservation([
        doc("bad", {
          date: slot.date, courtNumber: 2, hour: 18, userName: "Player",
        }),
      ], slot),
      (error) => error.code === "reservation_invalid",
  );
});
