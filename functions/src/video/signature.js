"use strict";

const crypto = require("node:crypto");

const {VideoRequestError} = require("./errors");

const DEVICE_ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;
const NONCE_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const HEX_SIGNATURE_PATTERN = /^[a-fA-F0-9]{64}$/;

function validationError(message, code = "invalid_request", httpStatus = 400) {
  return new VideoRequestError(code, message, {httpStatus});
}

function requireObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw validationError("Request body must be a JSON object");
  }
  return value;
}

function parseEspPayload(value) {
  const payload = requireObject(value);
  const courtNumber = payload.courtNumber;
  const deviceId = typeof payload.deviceId === "string" ? payload.deviceId : "";
  const nonce = typeof payload.nonce === "string" ? payload.nonce : "";
  const signature = typeof payload.signature === "string" ? payload.signature : "";
  const timestamp = payload.timestamp;

  if (!Number.isInteger(courtNumber) || courtNumber < 1 || courtNumber > 3) {
    throw validationError("courtNumber must be an integer from 1 through 3");
  }
  if (!DEVICE_ID_PATTERN.test(deviceId)) {
    throw validationError("deviceId has an invalid format");
  }
  if (!Number.isSafeInteger(timestamp) || timestamp <= 0) {
    throw validationError("timestamp must be a Unix timestamp in seconds");
  }
  if (!NONCE_PATTERN.test(nonce)) {
    throw validationError("nonce must be 16-128 base64url characters");
  }
  if (!HEX_SIGNATURE_PATTERN.test(signature)) {
    throw validationError("signature must be a SHA-256 HMAC in hexadecimal");
  }

  return {
    courtNumber,
    deviceId,
    timestamp,
    nonce,
    signature: signature.toLowerCase(),
  };
}

/**
 * Versioned canonical form.  The version is a fixed protocol marker rather
 * than another device-controlled field, preventing future formats from being
 * confused with this one.
 */
function canonicalEspMessage({deviceId, courtNumber, timestamp, nonce}) {
  return `v1\n${deviceId}\n${courtNumber}\n${timestamp}\n${nonce}`;
}

function signEspPayload(payload, secret) {
  return crypto.createHmac("sha256", Buffer.from(secret, "utf8"))
      .update(canonicalEspMessage(payload), "utf8")
      .digest("hex");
}

function timingSafeSignatureEquals(received, expected) {
  if (!HEX_SIGNATURE_PATTERN.test(received) || !HEX_SIGNATURE_PATTERN.test(expected)) {
    return false;
  }
  const receivedBuffer = Buffer.from(received.toLowerCase(), "ascii");
  const expectedBuffer = Buffer.from(expected.toLowerCase(), "ascii");
  return receivedBuffer.length === expectedBuffer.length &&
    crypto.timingSafeEqual(receivedBuffer, expectedBuffer);
}

function parseDeviceKeyConfiguration(rawConfiguration) {
  let parsed;
  try {
    parsed = JSON.parse(String(rawConfiguration || ""));
  } catch (error) {
    throw new VideoRequestError(
        "video_configuration_error",
        "ESP32 device key configuration is invalid",
        {httpStatus: 503, cause: error},
    );
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new VideoRequestError(
        "video_configuration_error",
        "ESP32 device key configuration is invalid",
        {httpStatus: 503},
    );
  }
  return parsed;
}

function getDeviceCredential(configuration, deviceId, courtNumber) {
  const record = configuration[deviceId];
  if (!record || typeof record !== "object" || Array.isArray(record)) {
    return null;
  }
  if (typeof record.secret !== "string" || record.secret.length < 16) {
    return null;
  }
  // Binding every device key to its physical court ensures a compromised
  // court-one button cannot request camera footage from another court.
  if (!Array.isArray(record.courts) || !record.courts.includes(courtNumber)) {
    return null;
  }
  return {secret: record.secret};
}

function validateTimestamp(timestampSeconds, now = new Date(), toleranceSeconds = 90) {
  const ageMilliseconds = now.getTime() - (timestampSeconds * 1000);
  if (Math.abs(ageMilliseconds) > toleranceSeconds * 1000) {
    throw validationError(
        "Request timestamp is outside the permitted window",
        "stale_request",
        401,
    );
  }
}

function verifyEspPayload(rawPayload, rawDeviceKeyConfiguration, {
  now = new Date(),
  timestampToleranceSeconds = 90,
} = {}) {
  const payload = parseEspPayload(rawPayload);
  validateTimestamp(payload.timestamp, now, timestampToleranceSeconds);

  const configuration = parseDeviceKeyConfiguration(rawDeviceKeyConfiguration);
  const credential = getDeviceCredential(
      configuration,
      payload.deviceId,
      payload.courtNumber,
  );
  if (!credential) {
    throw validationError("Request authentication failed", "unauthorized", 401);
  }

  const expectedSignature = signEspPayload(payload, credential.secret);
  if (!timingSafeSignatureEquals(payload.signature, expectedSignature)) {
    throw validationError("Request authentication failed", "unauthorized", 401);
  }

  return payload;
}

module.exports = {
  canonicalEspMessage,
  getDeviceCredential,
  parseDeviceKeyConfiguration,
  parseEspPayload,
  signEspPayload,
  timingSafeSignatureEquals,
  validateTimestamp,
  verifyEspPayload,
};
