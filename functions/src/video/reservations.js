"use strict";

const {VideoRequestError} = require("./errors");
const {israelParts, israelReservationSlot} = require("./israel-time");

const FIRST_BOOKING_HOUR = 7;
const LAST_BOOKING_HOUR = 21;

function normalizedText(value) {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

function normalizedName(value) {
  return normalizedText(value).toLocaleLowerCase("he-IL");
}

function coerceInteger(value) {
  if (typeof value === "number" && Number.isInteger(value)) return value;
  if (typeof value === "string" && /^-?\d+$/.test(value.trim())) {
    return Number(value.trim());
  }
  return null;
}

function documentData(document) {
  if (typeof document?.data === "function") return document.data() || {};
  return document?.data || {};
}

function documentId(document, fallback) {
  return typeof document?.id === "string" ? document.id : String(fallback);
}

function reservationNotFound() {
  return new VideoRequestError(
      "reservation_not_found",
      "There is no active reservation for this court and time",
      {httpStatus: 404},
  );
}

/**
 * Returns the reservation hours that may own a physical-button press.
 *
 * Normal play is limited to the app's 07:00-22:00 booking grid. An explicit
 * closing extension lets the 21:00 booking keep ownership until 22:30. The
 * source label is retained with the queued job so a fallback remains
 * operationally auditable.
 */
function reservationCandidatesForPress(pressedAt) {
  const local = israelParts(pressedAt);
  if (local.hour === 22 && local.minute < 30) {
    return [
      {hour: 21, selectionSource: "closing_extension"},
    ];
  }
  if (local.hour < FIRST_BOOKING_HOUR || local.hour > LAST_BOOKING_HOUR) {
    return [];
  }

  const candidates = [
    {hour: local.hour, selectionSource: "current"},
  ];
  if (local.hour > FIRST_BOOKING_HOUR) {
    candidates.push({hour: local.hour - 1, selectionSource: "previous"});
  }
  if (local.hour < LAST_BOOKING_HOUR) {
    candidates.push({hour: local.hour + 1, selectionSource: "next"});
  }
  return candidates;
}

/**
 * Finds one logical reservation cell.  Older data can have duplicate document
 * ids for one cell, so identical player pairs are collapsed but conflicting
 * duplicates are rejected rather than sending video to an arbitrary pair.
 */
function findActiveReservation(documents, {date, courtNumber, hour}) {
  const candidates = [];
  for (const [index, document] of [...documents].entries()) {
    const data = documentData(document);
    if (data.isReserved === false ||
        normalizedText(data.date) !== date ||
        coerceInteger(data.courtNumber) !== courtNumber ||
        coerceInteger(data.hour) !== hour) {
      continue;
    }
    const userName = normalizedText(data.userName);
    const partner = normalizedText(data.partner);
    if (!userName || !partner) {
      throw new VideoRequestError(
          "reservation_invalid",
          "The active reservation does not identify both players",
          {httpStatus: 409},
      );
    }
    candidates.push({
      id: documentId(document, index),
      userName,
      partner,
    });
  }

  if (candidates.length === 0) {
    throw reservationNotFound();
  }

  const playerPairs = new Map();
  for (const candidate of candidates) {
    const pairKey = [
      normalizedName(candidate.userName),
      normalizedName(candidate.partner),
    ].sort().join("\u0000");
    const samePair = playerPairs.get(pairKey) || [];
    samePair.push(candidate);
    playerPairs.set(pairKey, samePair);
  }
  if (playerPairs.size !== 1) {
    throw new VideoRequestError(
        "reservation_ambiguous",
        "Conflicting reservations exist for this court and time",
        {httpStatus: 409},
    );
  }

  const matchingReservations = [...playerPairs.values()][0];
  const first = matchingReservations[0];
  return {
    ...first,
    documentIds: matchingReservations.map((reservation) => reservation.id).sort(),
  };
}

/**
 * Selects the first non-empty reservation candidate. Only a genuinely empty
 * cell falls through; malformed or conflicting cells fail closed.
 */
function findReservationWithFallback(
    documents,
    {date, courtNumber, candidates},
) {
  const availableDocuments = [...documents];
  for (const candidate of candidates) {
    try {
      const reservation = findActiveReservation(availableDocuments, {
        date,
        courtNumber,
        hour: candidate.hour,
      });
      return {
        ...reservation,
        slotDate: date,
        slotHour: candidate.hour,
        selectionSource: candidate.selectionSource,
      };
    } catch (error) {
      if (error?.code !== "reservation_not_found") throw error;
    }
  }
  throw reservationNotFound();
}

async function lookupActiveReservation(db, slot) {
  const snapshot = await db.collection("reservations")
      .where("date", "==", slot.date)
      .get();
  return findActiveReservation(snapshot.docs, slot);
}

async function lookupReservationForPress(db, {pressedAt, courtNumber}) {
  const candidates = reservationCandidatesForPress(pressedAt);
  const {date} = israelReservationSlot(pressedAt);
  if (candidates.length === 0) {
    throw reservationNotFound();
  }
  const snapshot = await db.collection("reservations")
      .where("date", "==", date)
      .get();
  return findReservationWithFallback(snapshot.docs, {
    date,
    courtNumber,
    candidates,
  });
}

module.exports = {
  coerceInteger,
  findActiveReservation,
  findReservationWithFallback,
  lookupActiveReservation,
  lookupReservationForPress,
  normalizedName,
  normalizedText,
  reservationCandidatesForPress,
};
