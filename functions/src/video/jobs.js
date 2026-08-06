"use strict";

const crypto = require("node:crypto");

const {VideoRequestError} = require("./errors");

const VIDEO_REQUESTS_COLLECTION = "video_clip_requests";
const VIDEO_RATE_LIMITS_COLLECTION = "video_button_rate_limits";

function digest(parts) {
  return crypto.createHash("sha256")
      .update(parts.join("\n"), "utf8")
      .digest("hex");
}

function espRequestId({deviceId, nonce}) {
  return `esp_${digest(["v1", "esp32", deviceId, nonce])}`;
}

function managerRequestId({uid, courtNumber, date, time, recipientEmail}) {
  return `manager_${digest([
    "v1",
    "manager",
    uid,
    String(courtNumber),
    date,
    time,
    recipientEmail.toLocaleLowerCase("en-US"),
  ])}`;
}

function nonceHash(nonce) {
  return digest(["v1", "nonce", nonce]);
}

function buildQueuedJob({
  requestKind,
  courtNumber,
  cameraChannel,
  pressedAt,
  clipStart,
  clipEnd,
  recipients,
  now,
  deviceId,
  nonce,
  reservation,
  requestedByUid,
}) {
  const job = {
    status: "queued",
    requestKind,
    courtNumber,
    cameraChannel,
    pressedAt,
    clipStart,
    clipEnd,
    recipients,
    createdAt: now,
    updatedAt: now,
    attempts: 0,
    failureCode: null,
    failureMessage: null,
    storageObject: null,
    linkExpiresAt: null,
  };

  if (requestKind === "esp32") {
    job.deviceId = deviceId;
    job.nonceHash = nonceHash(nonce);
    job.reservation = {
      documentIds: reservation.documentIds,
      userName: reservation.userName,
      partner: reservation.partner,
    };
  }
  if (requestKind === "manager") {
    job.requestedByUid = requestedByUid;
  }
  return job;
}

function timestampMilliseconds(value) {
  if (value instanceof Date) return value.getTime();
  if (value && typeof value.toMillis === "function") return value.toMillis();
  if (typeof value === "number") return value;
  return null;
}

async function createOrReuseVideoJob({
  db,
  requestId,
  job,
  now,
  rateLimit = null,
}) {
  const requestRef = db.collection(VIDEO_REQUESTS_COLLECTION).doc(requestId);
  const rateLimitRef = rateLimit ? db.collection(VIDEO_RATE_LIMITS_COLLECTION)
      .doc(`court_${rateLimit.courtNumber}`) : null;

  return db.runTransaction(async (transaction) => {
    const existingRequest = await transaction.get(requestRef);
    let existingRateLimit = null;
    if (!existingRequest.exists && rateLimitRef) {
      existingRateLimit = await transaction.get(rateLimitRef);
    }

    if (existingRequest.exists) {
      const existing = existingRequest.data() || {};
      return {
        requestId,
        status: typeof existing.status === "string" ? existing.status : "queued",
        deduplicated: true,
      };
    }

    if (existingRateLimit?.exists) {
      const lastAcceptedAt = timestampMilliseconds(
          existingRateLimit.data()?.lastAcceptedAt,
      );
      if (lastAcceptedAt !== null &&
          now.getTime() - lastAcceptedAt < rateLimit.windowMilliseconds) {
        throw new VideoRequestError(
            "button_rate_limited",
            "This court button was pressed too recently",
            {httpStatus: 429},
        );
      }
    }

    transaction.set(requestRef, job);
    if (rateLimitRef) {
      transaction.set(rateLimitRef, {
        lastAcceptedAt: now,
        lastRequestId: requestId,
        updatedAt: now,
      }, {merge: true});
    }
    return {requestId, status: "queued", deduplicated: false};
  });
}

module.exports = {
  VIDEO_RATE_LIMITS_COLLECTION,
  VIDEO_REQUESTS_COLLECTION,
  buildQueuedJob,
  createOrReuseVideoJob,
  espRequestId,
  managerRequestId,
  nonceHash,
  timestampMilliseconds,
};
