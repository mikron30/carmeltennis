"use strict";

const {VideoRequestError} = require("./errors");

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
    throw new VideoRequestError(
        "reservation_not_found",
        "There is no active reservation for this court and time",
        {httpStatus: 404},
    );
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

async function lookupActiveReservation(db, slot) {
  const snapshot = await db.collection("reservations")
      .where("date", "==", slot.date)
      .get();
  return findActiveReservation(snapshot.docs, slot);
}

module.exports = {
  coerceInteger,
  findActiveReservation,
  lookupActiveReservation,
  normalizedName,
  normalizedText,
};
