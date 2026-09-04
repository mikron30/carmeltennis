const {setGlobalOptions} = require("firebase-functions/v2");
const {HttpsError, onCall, onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");
const {
  createManagerVideoAccessReissuer,
  createOpenVideoClipHandler,
} = require("./src/video/access");
const {getVideoAccessSettings} = require("./src/video/config");
const {
  createEspHttpHandler,
  processManagerVideoRequest,
} = require("./src/video/ingress");
const {isVideoRequestError} = require("./src/video/errors");

initializeApp();
setGlobalOptions({region: "europe-west3", maxInstances: 10});

const USERS_COLLECTION = "users_2024";
const esp32VideoDeviceKeys = defineSecret("ESP32_VIDEO_DEVICE_KEYS");
const VIDEO_ACCESS_SERVICE_ACCOUNT =
  "video-access-runtime@potent-howl-228108.iam.gserviceaccount.com";
const MANAGER_NAMES = new Set([
  "אודי אש",
  "רני לפלר",
  "עפר בן ישי",
  "מיקי זילברשטיין",
  "מועדון כרמל",
]);

function normalizedName(data) {
  const firstName = String(data["שם פרטי"] || "").trim();
  const lastName = String(data["שם משפחה"] || "").trim();
  return `${firstName} ${lastName}`.trim().replace(/\s+/g, " ");
}

async function assertManager(request, db) {
  const callerEmail = request.auth && request.auth.token.email;
  if (!callerEmail) {
    throw new HttpsError("unauthenticated", "נדרשת התחברות");
  }

  const callerDocuments = await db
      .collection(USERS_COLLECTION)
      .where("מייל", "==", callerEmail)
      .limit(5)
      .get();
  const isManager = callerDocuments.docs.some((document) =>
    MANAGER_NAMES.has(normalizedName(document.data())),
  );

  if (!isManager) {
    throw new HttpsError("permission-denied", "רק מנהל יכול למחוק משתמשים");
  }
}

exports.deleteUserAccount = onCall(async (request) => {
  const email = typeof request.data?.email === "string" ?
    request.data.email.trim() : "";
  if (!email || !email.includes("@")) {
    throw new HttpsError("invalid-argument", "כתובת המייל אינה תקינה");
  }

  const db = getFirestore();
  await assertManager(request, db);

  const targetDocuments = await db
      .collection(USERS_COLLECTION)
      .where("מייל", "==", email)
      .limit(2)
      .get();
  if (targetDocuments.size > 1) {
    throw new HttpsError(
        "failed-precondition",
        "נמצאו כמה רשומות משתמש עם אותו מייל",
    );
  }

  let authenticationUser;
  try {
    authenticationUser = await getAuth().getUserByEmail(email);
  } catch (error) {
    if (error.code === "auth/user-not-found") {
      throw new HttpsError(
          "not-found",
          "המשתמש לא נמצא ב-Firebase Authentication",
      );
    }
    console.error("Failed to find Authentication user", error);
    throw new HttpsError("internal", "חיפוש המשתמש ב-Authentication נכשל");
  }

  try {
    await getAuth().deleteUser(authenticationUser.uid);
    if (!targetDocuments.empty) {
      await targetDocuments.docs[0].ref.delete();
    }
  } catch (error) {
    console.error("Failed to delete user", {
      uid: authenticationUser.uid,
      error,
    });
    throw new HttpsError("internal", "מחיקת המשתמש נכשלה");
  }

  return {
    deleted: true,
    firestoreRecordDeleted: !targetDocuments.empty,
  };
});

function callableVideoError(error) {
  if (error instanceof HttpsError) return error;
  if (!isVideoRequestError(error)) {
    return new HttpsError("internal", "Video request failed");
  }
  if (error.code === "invalid_request") {
    return new HttpsError("invalid-argument", error.message);
  }
  if (error.code === "button_rate_limited") {
    return new HttpsError("resource-exhausted", error.message);
  }
  if (error.code === "video_queue_unavailable") {
    return new HttpsError("unavailable", "Video processing is temporarily unavailable");
  }
  if (error.code === "video_configuration_error") {
    return new HttpsError("failed-precondition", "Video service is not configured");
  }
  if (error.code === "reservation_not_found" || error.code === "player_not_found") {
    return new HttpsError("not-found", error.message);
  }
  return new HttpsError("failed-precondition", error.message);
}

const requestVideoClipHandler = createEspHttpHandler({
  db: getFirestore(),
  getDeviceKeyConfiguration: () => esp32VideoDeviceKeys.value(),
});

/**
 * Public HTTPS endpoint for the physical court buttons.  Every accepted
 * request is authenticated with its device HMAC before any reservation data is
 * read, and the secret binding keeps device keys out of source control.
 */
exports.requestVideoClip = onRequest({
  region: "europe-west3",
  cors: false,
  timeoutSeconds: 60,
  secrets: [esp32VideoDeviceKeys],
}, requestVideoClipHandler);

/**
 * Manager-only path used by the web app to test or manually request a clip.
 * `processManagerVideoRequest` invokes assertManager server-side; the client
 * manager menu is only a convenience and is not an authorization boundary.
 */
exports.requestVideoClipForManager = onCall({
  region: "europe-west3",
  timeoutSeconds: 60,
}, async (request) => {
  try {
    const result = await processManagerVideoRequest(request, {
      db: getFirestore(),
      assertManager,
    });
    // Do not log the manager's email or supplied recipient address.
    console.info("Manager video request accepted", {
      requestId: result.requestId,
      status: result.status,
      deduplicated: result.deduplicated,
      courtNumber: request.data?.courtNumber,
    });
    return result;
  } catch (error) {
    const code = isVideoRequestError(error) ? error.code : "internal_error";
    console.error("Manager video request failed", {code});
    throw callableVideoError(error);
  }
});

let cachedVideoAccessHandlers;

function getVideoAccessHandlers() {
  if (cachedVideoAccessHandlers) return cachedVideoAccessHandlers;
  const settings = getVideoAccessSettings();
  const bucket = getStorage().bucket(settings.videoClipBucket);
  cachedVideoAccessHandlers = {
    open: createOpenVideoClipHandler({
      db: getFirestore(),
      bucket,
      signedUrlTtlSeconds: settings.signedUrlTtlSeconds,
    }),
    reissue: createManagerVideoAccessReissuer({
      db: getFirestore(),
      bucket,
      assertManager,
      publicBaseUrl: settings.publicBaseUrl,
      accessTtlSeconds: settings.accessTtlSeconds,
    }),
  };
  return cachedVideoAccessHandlers;
}

async function openVideoClipEntrypoint(request, response) {
  try {
    return await getVideoAccessHandlers().open(request, response);
  } catch (error) {
    const code = isVideoRequestError(error) ? error.code : "internal_error";
    console.error("Video access initialization failed", {code});
    if (!response.headersSent) {
      response.status(503).send("Video access is temporarily unavailable.");
    }
  }
}

async function regenerateVideoClipAccessEntrypoint(request) {
  try {
    return await getVideoAccessHandlers().reissue(request);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    const code = isVideoRequestError(error) ? error.code : "internal_error";
    console.error("Manager video access initialization failed", {code});
    if (isVideoRequestError(error)) {
      throw new HttpsError(
          "failed-precondition",
          "Video access is not configured",
      );
    }
    throw new HttpsError("internal", "Video access request failed");
  }
}

/**
 * Public bearer-token resolver. The emailed raw token remains in the browser
 * fragment and reaches this handler only in a POST body, keeping it out of
 * automatic request-URL logs. The bucket itself remains private.
 */
exports.openVideoClip = onRequest({
  region: "europe-west3",
  cors: false,
  timeoutSeconds: 30,
  invoker: "public",
  serviceAccount: VIDEO_ACCESS_SERVICE_ACCOUNT,
}, openVideoClipEntrypoint);

/**
 * Manager-only recovery for an already stored MP4. It creates another stable
 * token hash without enqueuing Cloud Tasks or contacting the NVR.
 */
exports.regenerateVideoClipAccessForManager = onCall({
  region: "europe-west3",
  timeoutSeconds: 30,
  serviceAccount: VIDEO_ACCESS_SERVICE_ACCOUNT,
}, regenerateVideoClipAccessEntrypoint);
