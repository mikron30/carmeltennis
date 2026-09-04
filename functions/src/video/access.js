"use strict";

const crypto = require("node:crypto");

const {HttpsError} = require("firebase-functions/v2/https");

const VIDEO_REQUESTS_COLLECTION = "video_clip_requests";
const ACCESS_TOKEN_BYTES = 32;
const ACCESS_TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;
const ACCESS_TOKEN_HASH_PATTERN = /^[a-f0-9]{64}$/;
const REQUEST_ID_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$/;
const STORAGE_OBJECT_PATTERN = /^video-clips\/[a-f0-9]{64}\.mp4$/;
const ACCESS_LIFETIME_MILLISECONDS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_SIGNED_URL_TTL_SECONDS = 15 * 60;
const MAX_ACCESS_TOKEN_HASHES = 32;

// Keeping the token in the fragment prevents it from reaching Cloud Run's
// automatically generated request URL logs. This script immediately removes
// the fragment and submits the token in a POST body instead.
const LANDING_SCRIPT = `(() => {
  const query = new URLSearchParams(window.location.search);
  const fragment = new URLSearchParams(window.location.hash.slice(1));
  const requestId = fragment.get("requestId") || query.get("requestId") || "";
  const token = fragment.get("token") || "";
  window.history.replaceState(null, "", window.location.pathname + window.location.search);
  const status = document.getElementById("status");
  if (!requestId || !token) {
    status.textContent = "The video link is invalid.";
    return;
  }
  const form = document.createElement("form");
  form.method = "post";
  form.action = window.location.origin + window.location.pathname;
  for (const [name, value] of [["requestId", requestId], ["token", token]]) {
    const input = document.createElement("input");
    input.type = "hidden";
    input.name = name;
    input.value = value;
    form.appendChild(input);
  }
  document.body.appendChild(form);
  form.submit();
})();`;
const LANDING_SCRIPT_HASH = crypto.createHash("sha256")
    .update(LANDING_SCRIPT, "utf8")
    .digest("base64");

function issueAccessToken({randomBytes = crypto.randomBytes} = {}) {
  const entropy = randomBytes(ACCESS_TOKEN_BYTES);
  if (!Buffer.isBuffer(entropy) || entropy.length !== ACCESS_TOKEN_BYTES) {
    throw new Error("Access-token entropy source must return exactly 32 bytes");
  }
  const token = entropy.toString("base64url");
  return {
    token,
    tokenHash: hashAccessToken(token),
  };
}

function hashAccessToken(token) {
  return crypto.createHash("sha256").update(token, "utf8").digest("hex");
}

function storedAccessTokenHashes(job) {
  const candidates = [];
  if (Array.isArray(job?.accessTokenHashes)) {
    candidates.push(...job.accessTokenHashes);
  }
  // Accept an early/singular deployment shape without weakening validation.
  if (typeof job?.accessTokenHash === "string") {
    candidates.push(job.accessTokenHash);
  }
  return [...new Set(candidates.filter((value) =>
    typeof value === "string" && ACCESS_TOKEN_HASH_PATTERN.test(value),
  ))];
}

function accessTokenMatches(token, storedHashes) {
  if (typeof token !== "string" || !ACCESS_TOKEN_PATTERN.test(token)) {
    return false;
  }
  const actual = Buffer.from(hashAccessToken(token), "hex");
  let matched = false;
  // Evaluate every candidate instead of returning at the first match. Besides
  // timingSafeEqual itself, this avoids exposing the matching array position.
  for (const storedHash of storedHashes) {
    if (typeof storedHash !== "string" ||
        !ACCESS_TOKEN_HASH_PATTERN.test(storedHash)) {
      continue;
    }
    const expected = Buffer.from(storedHash, "hex");
    matched = crypto.timingSafeEqual(actual, expected) || matched;
  }
  return matched;
}

function buildVideoAccessUrl(publicBaseUrl, requestId, token) {
  const url = validatedPublicBaseUrl(publicBaseUrl);
  if (!REQUEST_ID_PATTERN.test(requestId)) {
    throw new Error("requestId is invalid");
  }
  if (!ACCESS_TOKEN_PATTERN.test(token)) {
    throw new Error("access token is invalid");
  }
  url.hash = new URLSearchParams({requestId, token}).toString();
  return url.toString();
}

function validatedPublicBaseUrl(value) {
  let url;
  try {
    url = new URL(String(value || "").trim());
  } catch (_) {
    throw new Error("VIDEO_PUBLIC_BASE_URL must be an absolute HTTPS URL");
  }
  if (url.protocol !== "https:" || url.username || url.password ||
      url.search || url.hash) {
    throw new Error(
        "VIDEO_PUBLIC_BASE_URL must be an HTTPS URL without credentials, query, or fragment",
    );
  }
  return url;
}

function landingPage() {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="referrer" content="no-referrer">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Carmel Tennis video</title>
  </head>
  <body>
    <p id="status">Opening your Carmel Tennis video…</p>
    <noscript>JavaScript is required to open this private video link.</noscript>
    <script>${LANDING_SCRIPT}</script>
  </body>
</html>`;
}

function noStoreHeaders(response) {
  response.set({
    "Cache-Control": "private, no-store, max-age=0",
    "Pragma": "no-cache",
    "Referrer-Policy": "no-referrer",
    "X-Content-Type-Options": "nosniff",
  });
}

function createOpenVideoClipHandler({
  db,
  bucket,
  clock = () => new Date(),
  signedUrlTtlSeconds = DEFAULT_SIGNED_URL_TTL_SECONDS,
  logger = console,
} = {}) {
  if (!db || typeof db.collection !== "function") {
    throw new Error("A Firestore client is required");
  }
  if (!bucket || typeof bucket.file !== "function") {
    throw new Error("A Cloud Storage bucket is required");
  }
  if (!Number.isInteger(signedUrlTtlSeconds) ||
      signedUrlTtlSeconds < 60 || signedUrlTtlSeconds > 3600) {
    throw new Error("Signed URL TTL must be between 60 and 3600 seconds");
  }

  return async (request, response) => {
    noStoreHeaders(response);
    if (request.method === "GET") {
      response.set({
        "Content-Security-Policy":
          `default-src 'none'; base-uri 'none'; form-action 'self'; ` +
          `frame-ancestors 'none'; ` +
          `script-src 'sha256-${LANDING_SCRIPT_HASH}'`,
        "Content-Type": "text/html; charset=utf-8",
      });
      response.status(200).send(landingPage());
      return;
    }
    if (request.method !== "POST") {
      response.set("Allow", "GET, POST");
      response.status(405).send("Method not allowed.");
      return;
    }

    const input = accessPostBody(request);
    const requestId = input.requestId;
    const token = input.token;
    if (!REQUEST_ID_PATTERN.test(requestId) ||
        !ACCESS_TOKEN_PATTERN.test(token)) {
      response.status(404).send("Video link not found.");
      return;
    }

    let snapshot;
    try {
      snapshot = await db.collection(VIDEO_REQUESTS_COLLECTION)
          .doc(requestId)
          .get();
    } catch (error) {
      safeLog(logger, "error", "Video access Firestore read failed", {
        requestId,
        stage: "firestore_read",
        exceptionType: exceptionType(error),
      });
      response.status(503).send("Video access is temporarily unavailable.");
      return;
    }
    if (!snapshot?.exists) {
      response.status(404).send("Video link not found.");
      return;
    }

    const job = snapshot.data() || {};
    if (!accessTokenMatches(token, storedAccessTokenHashes(job))) {
      response.status(404).send("Video link not found.");
      return;
    }

    const now = clock();
    const nowMilliseconds = validDateMilliseconds(now);
    const accessExpiresAt = timestampMilliseconds(job.accessExpiresAt);
    if (accessExpiresAt === null || accessExpiresAt <= nowMilliseconds) {
      response.status(410).send("This video has expired.");
      return;
    }

    const objectName = typeof job.storageObject === "string" ?
      job.storageObject : "";
    if (!STORAGE_OBJECT_PATTERN.test(objectName)) {
      response.status(404).send("Video file not found.");
      return;
    }
    const file = bucket.file(objectName);
    let exists;
    try {
      [exists] = await file.exists();
    } catch (error) {
      safeLog(logger, "error", "Video access Storage check failed", {
        requestId,
        objectName,
        stage: "storage_exists",
        exceptionType: exceptionType(error),
      });
      response.status(503).send("Video access is temporarily unavailable.");
      return;
    }
    if (!exists) {
      response.status(404).send("Video file not found.");
      return;
    }

    const signedUrlExpiresAt = Math.min(
        nowMilliseconds + (signedUrlTtlSeconds * 1000),
        accessExpiresAt,
    );
    let signedUrl;
    try {
      [signedUrl] = await file.getSignedUrl({
        version: "v4",
        action: "read",
        expires: new Date(signedUrlExpiresAt),
        responseType: "video/mp4",
        responseDisposition: "attachment; filename=tennis-court-video.mp4",
      });
    } catch (error) {
      safeLog(logger, "error", "Video access URL signing failed", {
        requestId,
        objectName,
        stage: "signed_url",
        exceptionType: exceptionType(error),
      });
      response.status(503).send("Video access is temporarily unavailable.");
      return;
    }
    if (typeof signedUrl !== "string" || !signedUrl.startsWith("https://")) {
      safeLog(logger, "error", "Video access URL signing returned no URL", {
        requestId,
        objectName,
        stage: "signed_url",
      });
      response.status(503).send("Video access is temporarily unavailable.");
      return;
    }

    safeLog(logger, "info", "Video access granted", {
      requestId,
      objectName,
      stage: "redirect",
    });
    response.redirect(303, signedUrl);
  };
}

function createManagerVideoAccessReissuer({
  db,
  bucket,
  assertManager,
  publicBaseUrl,
  accessTtlSeconds = ACCESS_LIFETIME_MILLISECONDS / 1000,
  clock = () => new Date(),
  randomBytes = crypto.randomBytes,
  arrayUnion = defaultArrayUnion,
  logger = console,
} = {}) {
  if (!db || typeof db.collection !== "function") {
    throw new Error("A Firestore client is required");
  }
  if (!bucket || typeof bucket.file !== "function") {
    throw new Error("A Cloud Storage bucket is required");
  }
  if (typeof assertManager !== "function") {
    throw new Error("A server-side manager assertion is required");
  }
  if (!Number.isInteger(accessTtlSeconds) || accessTtlSeconds < 60 ||
      accessTtlSeconds > ACCESS_LIFETIME_MILLISECONDS / 1000) {
    throw new Error("Video access TTL must be between 60 seconds and 7 days");
  }
  const normalizedPublicBaseUrl = validatedPublicBaseUrl(publicBaseUrl).toString();

  return async (request) => {
    await assertManager(request, db);
    const requestId = typeof request.data?.requestId === "string" ?
      request.data.requestId.trim() : "";
    if (!REQUEST_ID_PATTERN.test(requestId)) {
      throw new HttpsError("invalid-argument", "requestId is invalid");
    }

    const reference = db.collection(VIDEO_REQUESTS_COLLECTION).doc(requestId);
    let snapshot;
    try {
      snapshot = await reference.get();
    } catch (error) {
      safeLog(logger, "error", "Video access reissue Firestore read failed", {
        requestId,
        stage: "firestore_read",
        exceptionType: exceptionType(error),
      });
      throw new HttpsError("unavailable", "Video access is temporarily unavailable");
    }
    if (!snapshot?.exists) {
      throw new HttpsError("not-found", "Video request not found");
    }
    const job = snapshot.data() || {};
    const objectName = typeof job.storageObject === "string" ?
      job.storageObject : "";
    if (!STORAGE_OBJECT_PATTERN.test(objectName)) {
      throw new HttpsError("not-found", "Video file not found");
    }

    let metadata;
    try {
      [metadata] = await bucket.file(objectName).getMetadata();
    } catch (error) {
      if (isNotFoundError(error)) {
        throw new HttpsError("not-found", "Video file not found");
      }
      safeLog(logger, "error", "Video access reissue Storage check failed", {
        requestId,
        objectName,
        stage: "storage_metadata",
        exceptionType: exceptionType(error),
      });
      throw new HttpsError("unavailable", "Video access is temporarily unavailable");
    }

    const now = clock();
    const nowMilliseconds = validDateMilliseconds(now);
    const objectCreatedAt = dateStringMilliseconds(metadata?.timeCreated);
    const storedExpiry = timestampMilliseconds(job.accessExpiresAt);
    const expiryCandidates = [];
    if (storedExpiry !== null) {
      expiryCandidates.push(storedExpiry);
    } else {
      // A restored soft-deleted object receives a new Storage creation time.
      // For a legacy job with no access expiry, retain the original request
      // lifetime instead of granting another seven days after restoration.
      const originalJobCreatedAt = timestampMilliseconds(job.createdAt) ??
        timestampMilliseconds(snapshot.createTime);
      if (originalJobCreatedAt !== null) {
        expiryCandidates.push(
            originalJobCreatedAt + (accessTtlSeconds * 1000),
        );
      }
    }
    if (objectCreatedAt !== null) {
      expiryCandidates.push(objectCreatedAt + (accessTtlSeconds * 1000));
    }
    if (expiryCandidates.length === 0) {
      throw new HttpsError(
          "failed-precondition",
          "Video retention time could not be determined",
      );
    }
    const accessExpiresAt = Math.min(...expiryCandidates);
    if (accessExpiresAt <= nowMilliseconds) {
      throw new HttpsError("failed-precondition", "This video has expired");
    }

    const existingHashes = storedAccessTokenHashes(job);
    if (existingHashes.length >= MAX_ACCESS_TOKEN_HASHES) {
      throw new HttpsError(
          "resource-exhausted",
          "This video has reached its access-link reissue limit",
      );
    }
    const access = issueAccessToken({randomBytes});
    const update = {
      accessTokenHashes: arrayUnion(access.tokenHash),
      accessExpiresAt: new Date(accessExpiresAt),
      accessReissuedAt: now,
      updatedAt: now,
    };
    if (typeof request.auth?.uid === "string" && request.auth.uid) {
      update.accessReissuedByUid = request.auth.uid;
    }
    try {
      await reference.update(update);
    } catch (error) {
      safeLog(logger, "error", "Video access reissue Firestore update failed", {
        requestId,
        objectName,
        stage: "firestore_update",
        exceptionType: exceptionType(error),
      });
      throw new HttpsError("unavailable", "Video access is temporarily unavailable");
    }

    const accessUrl = buildVideoAccessUrl(
        normalizedPublicBaseUrl,
        requestId,
        access.token,
    );
    safeLog(logger, "info", "Video access link reissued", {
      requestId,
      objectName,
      stage: "reissue",
    });
    return {
      requestId,
      accessUrl,
      accessExpiresAt: new Date(accessExpiresAt).toISOString(),
    };
  };
}

function accessPostBody(request) {
  const body = request.body;
  if (body && typeof body === "object" && !Buffer.isBuffer(body) &&
      !Array.isArray(body)) {
    return {
      requestId: scalarBodyValue(body.requestId),
      token: scalarBodyValue(body.token),
    };
  }
  let raw = "";
  if (Buffer.isBuffer(request.rawBody) && request.rawBody.length <= 4096) {
    raw = request.rawBody.toString("utf8");
  } else if (typeof body === "string" && Buffer.byteLength(body) <= 4096) {
    raw = body;
  }
  const parameters = new URLSearchParams(raw);
  return {
    requestId: parameters.get("requestId") || "",
    token: parameters.get("token") || "",
  };
}

function scalarBodyValue(value) {
  return typeof value === "string" ? value : "";
}

function timestampMilliseconds(value) {
  if (value instanceof Date) return validDateMillisecondsOrNull(value);
  if (value && typeof value.toMillis === "function") {
    const milliseconds = value.toMillis();
    return Number.isFinite(milliseconds) ? milliseconds : null;
  }
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") return dateStringMilliseconds(value);
  return null;
}

function dateStringMilliseconds(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  const milliseconds = Date.parse(value);
  return Number.isFinite(milliseconds) ? milliseconds : null;
}

function validDateMilliseconds(value) {
  const milliseconds = validDateMillisecondsOrNull(value);
  if (milliseconds === null) throw new Error("Clock returned an invalid date");
  return milliseconds;
}

function validDateMillisecondsOrNull(value) {
  if (!(value instanceof Date)) return null;
  const milliseconds = value.getTime();
  return Number.isFinite(milliseconds) ? milliseconds : null;
}

function defaultArrayUnion(value) {
  const {FieldValue} = require("firebase-admin/firestore");
  return FieldValue.arrayUnion(value);
}

function isNotFoundError(error) {
  return error?.code === 404 || error?.code === "404" ||
    error?.code === 5 || error?.code === "5" ||
    error?.code === "NOT_FOUND";
}

function exceptionType(error) {
  return typeof error?.name === "string" && error.name ?
    error.name.slice(0, 80) : "Error";
}

function safeLog(logger, level, message, fields) {
  const writer = logger && typeof logger[level] === "function" ?
    logger[level].bind(logger) : null;
  if (writer) writer(message, fields);
}

module.exports = {
  ACCESS_LIFETIME_MILLISECONDS,
  ACCESS_TOKEN_BYTES,
  DEFAULT_SIGNED_URL_TTL_SECONDS,
  MAX_ACCESS_TOKEN_HASHES,
  accessTokenMatches,
  buildVideoAccessUrl,
  createManagerVideoAccessReissuer,
  createOpenVideoClipHandler,
  hashAccessToken,
  issueAccessToken,
  landingPage,
  storedAccessTokenHashes,
  timestampMilliseconds,
};
