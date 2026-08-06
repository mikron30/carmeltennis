"use strict";

const {VideoRequestError} = require("./errors");
const {normalizedName, normalizedText} = require("./reservations");

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const USER_FIELDS = Object.freeze({
  email: "\u05de\u05d9\u05d9\u05dc",
  firstName: "\u05e9\u05dd \u05e4\u05e8\u05d8\u05d9",
  lastName: "\u05e9\u05dd \u05de\u05e9\u05e4\u05d7\u05d4",
});

function validEmail(value) {
  const email = typeof value === "string" ? value.trim() : "";
  return EMAIL_PATTERN.test(email) ? email : null;
}

function userFullName(data) {
  return normalizedText(
      `${normalizedText(data?.[USER_FIELDS.firstName])} ` +
      `${normalizedText(data?.[USER_FIELDS.lastName])}`,
  );
}

function userDocumentData(document) {
  if (typeof document?.data === "function") return document.data() || {};
  return document?.data || {};
}

function validatePlayerName(value) {
  const name = normalizedText(value);
  if (!name || name.startsWith("!")) {
    throw new VideoRequestError(
        "player_not_resolvable",
        "The reservation does not contain a registered player",
        {httpStatus: 409},
    );
  }
  return name;
}

function resolvePlayerEmails(userDocuments, playerNames) {
  const requestedPlayers = playerNames.map(validatePlayerName);
  const matchesByName = new Map(requestedPlayers.map((name) => [
    normalizedName(name),
    new Set(),
  ]));
  const malformedNames = new Set();

  for (const document of userDocuments) {
    const data = userDocumentData(document);
    const userName = normalizedName(userFullName(data));
    if (!matchesByName.has(userName)) continue;
    const email = validEmail(data?.[USER_FIELDS.email]);
    if (email) {
      matchesByName.get(userName).add(email.toLocaleLowerCase("en-US"));
    } else {
      malformedNames.add(userName);
    }
  }

  const recipients = [];
  for (const player of requestedPlayers) {
    const key = normalizedName(player);
    const emails = matchesByName.get(key);
    if (!emails || emails.size === 0) {
      throw new VideoRequestError(
          malformedNames.has(key) ? "player_email_invalid" : "player_not_found",
          `No usable email address was found for ${player}`,
          {httpStatus: 404},
      );
    }
    if (emails.size > 1) {
      throw new VideoRequestError(
          "player_ambiguous",
          `More than one email address was found for ${player}`,
          {httpStatus: 409},
      );
    }
    recipients.push([...emails][0]);
  }

  return [...new Set(recipients)];
}

async function lookupPlayerEmails(db, playerNames) {
  const snapshot = await db.collection("users_2024").get();
  return resolvePlayerEmails(snapshot.docs, playerNames);
}

module.exports = {
  EMAIL_PATTERN,
  USER_FIELDS,
  lookupPlayerEmails,
  resolvePlayerEmails,
  userFullName,
  validEmail,
  validatePlayerName,
};
