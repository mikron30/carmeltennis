"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  findActiveReservation,
  findReservationWithFallback,
  lookupReservationForPress,
  reservationCandidatesForPress,
} = require("../src/video/reservations");

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

test("fallback lookup prefers the current reservation", () => {
  const reservation = findReservationWithFallback([
    doc("previous", {
      date: slot.date, courtNumber: 2, hour: 17,
      userName: "Previous One", partner: "Previous Two",
    }),
    doc("current", {
      date: slot.date, courtNumber: 2, hour: 18,
      userName: "Current One", partner: "Current Two",
    }),
    doc("next", {
      date: slot.date, courtNumber: 2, hour: 19,
      userName: "Next One", partner: "Next Two",
    }),
  ], {
    date: slot.date,
    courtNumber: 2,
    candidates: [
      {hour: 18, selectionSource: "current"},
      {hour: 17, selectionSource: "previous"},
      {hour: 19, selectionSource: "next"},
    ],
  });

  assert.equal(reservation.id, "current");
  assert.equal(reservation.slotDate, slot.date);
  assert.equal(reservation.slotHour, 18);
  assert.equal(reservation.selectionSource, "current");
});

test("fallback lookup uses the previous reservation when current is empty", () => {
  const reservation = findReservationWithFallback([
    doc("previous", {
      date: slot.date, courtNumber: 2, hour: 17,
      userName: "Previous One", partner: "Previous Two",
    }),
    doc("next", {
      date: slot.date, courtNumber: 2, hour: 19,
      userName: "Next One", partner: "Next Two",
    }),
  ], {
    date: slot.date,
    courtNumber: 2,
    candidates: [
      {hour: 18, selectionSource: "current"},
      {hour: 17, selectionSource: "previous"},
      {hour: 19, selectionSource: "next"},
    ],
  });

  assert.equal(reservation.id, "previous");
  assert.equal(reservation.slotHour, 17);
  assert.equal(reservation.selectionSource, "previous");
});

test("fallback lookup uses next only when current and previous are empty", () => {
  const reservation = findReservationWithFallback([
    doc("next", {
      date: slot.date, courtNumber: 2, hour: 19,
      userName: "Next One", partner: "Next Two",
    }),
  ], {
    date: slot.date,
    courtNumber: 2,
    candidates: [
      {hour: 18, selectionSource: "current"},
      {hour: 17, selectionSource: "previous"},
      {hour: 19, selectionSource: "next"},
    ],
  });

  assert.equal(reservation.id, "next");
  assert.equal(reservation.slotHour, 19);
  assert.equal(reservation.selectionSource, "next");
});

test("fallback lookup fails closed on an ambiguous earlier candidate", () => {
  assert.throws(
      () => findReservationWithFallback([
        doc("current-a", {
          date: slot.date, courtNumber: 2, hour: 18,
          userName: "Current One", partner: "Current Two",
        }),
        doc("current-b", {
          date: slot.date, courtNumber: 2, hour: 18,
          userName: "Other One", partner: "Other Two",
        }),
        doc("previous", {
          date: slot.date, courtNumber: 2, hour: 17,
          userName: "Previous One", partner: "Previous Two",
        }),
      ], {
        date: slot.date,
        courtNumber: 2,
        candidates: [
          {hour: 18, selectionSource: "current"},
          {hour: 17, selectionSource: "previous"},
        ],
      }),
      (error) => error.code === "reservation_ambiguous",
  );
});

test("normal candidate planning stays within booking hours", () => {
  // August is UTC+3 in Israel.
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T16:15:00.000Z")),
      [
        {hour: 19, selectionSource: "current"},
        {hour: 18, selectionSource: "previous"},
        {hour: 20, selectionSource: "next"},
      ],
  );
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T04:15:00.000Z")),
      [
        {hour: 7, selectionSource: "current"},
        {hour: 8, selectionSource: "next"},
      ],
  );
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T18:15:00.000Z")),
      [
        {hour: 21, selectionSource: "current"},
        {hour: 20, selectionSource: "previous"},
      ],
  );
});

test("candidate planning rejects presses before opening and after closing", () => {
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T03:59:59.999Z")),
      [],
  );
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T20:00:00.000Z")),
      [],
  );
});

test("closing extension selects hour 21 through 22:29:59 Israel time", () => {
  const expected = [
    {hour: 21, selectionSource: "closing_extension"},
  ];
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T19:00:00.000Z")),
      expected,
  );
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T19:29:59.999Z")),
      expected,
  );
  assert.deepEqual(
      reservationCandidatesForPress(new Date("2026-08-04T19:30:00.000Z")),
      [],
  );
});

test("press lookup reads the Israel date once and returns closing metadata", async () => {
  const queries = [];
  const documents = [doc("hour-21", {
    date: "2026-08-04",
    courtNumber: 2,
    hour: 21,
    userName: "Player One",
    partner: "Player Two",
  })];
  const db = {
    collection(name) {
      assert.equal(name, "reservations");
      return {
        where(field, operator, value) {
          queries.push({field, operator, value});
          return {get: async () => ({docs: documents})};
        },
      };
    },
  };

  const reservation = await lookupReservationForPress(db, {
    // 22:15 Israel extends the reservation that ended at 22:00.
    pressedAt: new Date("2026-08-04T19:15:00.000Z"),
    courtNumber: 2,
  });

  assert.deepEqual(queries, [{
    field: "date",
    operator: "==",
    value: "2026-08-04",
  }]);
  assert.equal(reservation.slotDate, "2026-08-04");
  assert.equal(reservation.slotHour, 21);
  assert.equal(reservation.selectionSource, "closing_extension");
});

test("closing extension does not fall back to players who ended at 21:00", async () => {
  const db = {
    collection() {
      return {
        where() {
          return {get: async () => ({docs: [doc("hour-20", {
            date: "2026-08-04",
            courtNumber: 2,
            hour: 20,
            userName: "Earlier One",
            partner: "Earlier Two",
          })]})};
        },
      };
    },
  };

  await assert.rejects(
      lookupReservationForPress(db, {
        pressedAt: new Date("2026-08-04T19:15:00.000Z"),
        courtNumber: 2,
      }),
      (error) => error.code === "reservation_not_found",
  );
});

test("press lookup rejects an out-of-hours press without querying Firestore", async () => {
  const db = {
    collection() {
      throw new Error("Firestore should not be queried");
    },
  };

  await assert.rejects(
      lookupReservationForPress(db, {
        pressedAt: new Date("2026-08-04T19:30:00.000Z"),
        courtNumber: 2,
      }),
      (error) => error.code === "reservation_not_found" &&
        error.httpStatus === 404,
  );
});
