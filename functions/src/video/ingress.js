"use strict";

const {getIngressSettings, getTaskConfig, requireCourt} = require("./config");
const {VideoRequestError, isVideoRequestError} = require("./errors");
const {israelLocalDateTimeToUtc, israelReservationSlot} = require("./israel-time");
const {
  buildQueuedJob,
  createOrReuseVideoJob,
  espRequestId,
  managerRequestId,
} = require("./jobs");
const {lookupActiveReservation} = require("./reservations");
const {verifyEspPayload} = require("./signature");
const {enqueueVideoProcessing} = require("./tasks");
const {lookupPlayerEmails, validEmail} = require("./users");

function invalidRequest(message) {
  return new VideoRequestError("invalid_request", message, {httpStatus: 400});
}

function parseCourtNumber(value) {
  if (!Number.isInteger(value) || value < 1 || value > 3) {
    throw invalidRequest("courtNumber must be an integer from 1 through 3");
  }
  return value;
}

function parseManagerInput(data) {
  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw invalidRequest("A request object is required");
  }
  const courtNumber = parseCourtNumber(data.courtNumber);
  const date = typeof data.date === "string" ? data.date : "";
  const time = typeof data.time === "string" ? data.time : "";
  const recipientEmail = validEmail(data.recipientEmail);
  if (!recipientEmail) {
    throw invalidRequest("recipientEmail must be a valid email address");
  }
  return {
    courtNumber,
    date,
    time,
    recipientEmail: recipientEmail.toLocaleLowerCase("en-US"),
  };
}

function rejectFutureManagerRequest(pressedAt, now) {
  // A one-minute allowance prevents a UI clock a few seconds ahead from
  // creating a confusing rejection while still forbidding future recordings.
  if (pressedAt.getTime() > now.getTime() + (60 * 1000)) {
    throw invalidRequest("The requested recording time cannot be in the future");
  }
}

async function enqueueIfQueued(outcome, taskConfig, now, enqueue) {
  if (outcome.status === "queued") {
    await enqueue({requestId: outcome.requestId, taskConfig, now});
  }
  return outcome;
}

/**
 * Complete trusted ESP32 ingress.  The device timestamp only proves freshness;
 * the captured server clock is the source of both the reservation slot and the
 * video clip end time.
 */
async function processEspVideoRequest(rawPayload, {
  db,
  deviceKeyConfiguration,
  now = new Date(),
  ingressSettings,
  taskConfig,
  getSettings = getIngressSettings,
  getQueueConfig = getTaskConfig,
  enqueue = enqueueVideoProcessing,
} = {}) {
  const payload = verifyEspPayload(rawPayload, deviceKeyConfiguration, {
    now,
    timestampToleranceSeconds: (ingressSettings || getSettings())
        .timestampToleranceSeconds,
  });
  const resolvedIngressSettings = ingressSettings || getSettings();
  const resolvedTaskConfig = taskConfig || getQueueConfig();
  const court = requireCourt(payload.courtNumber);
  const slot = israelReservationSlot(now);
  const reservation = await lookupActiveReservation(db, {
    ...slot,
    courtNumber: payload.courtNumber,
  });
  const recipients = await lookupPlayerEmails(db, [
    reservation.userName,
    reservation.partner,
  ]);
  const clipStart = new Date(
      now.getTime() - (resolvedIngressSettings.clipLeadSeconds * 1000),
  );
  const requestId = espRequestId(payload);
  const job = buildQueuedJob({
    requestKind: "esp32",
    courtNumber: payload.courtNumber,
    cameraChannel: court.cameraChannel,
    pressedAt: now,
    clipStart,
    clipEnd: now,
    recipients,
    now,
    deviceId: payload.deviceId,
    nonce: payload.nonce,
    reservation,
  });
  const outcome = await createOrReuseVideoJob({
    db,
    requestId,
    job,
    now,
    rateLimit: {
      courtNumber: payload.courtNumber,
      windowMilliseconds: resolvedIngressSettings.rateLimitSeconds * 1000,
    },
  });
  return enqueueIfQueued(outcome, resolvedTaskConfig, now, enqueue);
}

/**
 * Manager-triggered test/recovery path.  It deliberately accepts one supplied
 * recipient and does not consult a reservation; authorization is injected from
 * the Firebase callable wrapper and must be performed before this function.
 */
async function processManagerVideoRequest(request, {
  db,
  assertManager,
  now = new Date(),
  ingressSettings,
  taskConfig,
  getSettings = getIngressSettings,
  getQueueConfig = getTaskConfig,
  enqueue = enqueueVideoProcessing,
} = {}) {
  if (typeof assertManager !== "function") {
    throw new Error("A server-side manager assertion is required");
  }
  await assertManager(request, db);
  const resolvedIngressSettings = ingressSettings || getSettings();
  const resolvedTaskConfig = taskConfig || getQueueConfig();
  const input = parseManagerInput(request.data);
  const pressedAt = israelLocalDateTimeToUtc(input.date, input.time);
  rejectFutureManagerRequest(pressedAt, now);
  const court = requireCourt(input.courtNumber);
  const requestId = managerRequestId({
    uid: request.auth?.uid || "",
    ...input,
  });
  const clipStart = new Date(
      pressedAt.getTime() - (resolvedIngressSettings.clipLeadSeconds * 1000),
  );
  const job = buildQueuedJob({
    requestKind: "manager",
    courtNumber: input.courtNumber,
    cameraChannel: court.cameraChannel,
    pressedAt,
    clipStart,
    clipEnd: pressedAt,
    recipients: [input.recipientEmail],
    now,
    requestedByUid: request.auth?.uid || "",
  });
  const outcome = await createOrReuseVideoJob({
    db,
    requestId,
    job,
    now,
  });
  return enqueueIfQueued(outcome, resolvedTaskConfig, now, enqueue);
}

function requestContentType(request) {
  if (typeof request.get === "function") {
    return request.get("content-type") || "";
  }
  return request.headers?.["content-type"] || "";
}

function publicHttpError(error) {
  if (isVideoRequestError(error)) {
    return {status: error.httpStatus, code: error.code};
  }
  return {status: 500, code: "internal_error"};
}

function logRequestError(logger, message, error, context = {}) {
  const details = {
    ...context,
    code: isVideoRequestError(error) ? error.code : "internal_error",
  };
  if (isVideoRequestError(error)) {
    logger.warn(message, details);
  } else {
    logger.error(message, details);
  }
}

function createEspHttpHandler({
  db,
  getDeviceKeyConfiguration,
  clock = () => new Date(),
  getSettings = () => getIngressSettings(),
  getQueueConfig = () => getTaskConfig(),
  enqueue = enqueueVideoProcessing,
  logger = console,
}) {
  if (typeof getDeviceKeyConfiguration !== "function") {
    throw new Error("A device key configuration provider is required");
  }
  return async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
      return;
    }
    if (!/^application\/json(?:;|$)/i.test(requestContentType(request))) {
      response.status(415).json({error: "unsupported_media_type"});
      return;
    }

    const now = clock();
    try {
      const result = await processEspVideoRequest(request.body, {
        db,
        deviceKeyConfiguration: getDeviceKeyConfiguration(),
        now,
        getSettings,
        getQueueConfig,
        enqueue,
      });
      // Keep operations traceable without logging a device secret, nonce,
      // signature, reservation names, or recipient email addresses.
      logger.info("Video button request accepted", {
        requestId: result.requestId,
        status: result.status,
        deduplicated: result.deduplicated,
        courtNumber: request.body.courtNumber,
      });
      response.status(202).json(result);
    } catch (error) {
      logRequestError(logger, "Video button request rejected", error);
      const publicError = publicHttpError(error);
      response.status(publicError.status).json({error: publicError.code});
    }
  };
}

module.exports = {
  createEspHttpHandler,
  parseManagerInput,
  processEspVideoRequest,
  processManagerVideoRequest,
  publicHttpError,
  rejectFutureManagerRequest,
};
