"use strict";

const {VideoConfigurationError} = require("./errors");

const COURTS = Object.freeze({
  1: Object.freeze({cameraChannel: 4, cameraName: "Left Court"}),
  2: Object.freeze({cameraChannel: 6, cameraName: "Right Court"}),
  3: Object.freeze({cameraChannel: 7, cameraName: "Back Court"}),
});

const DEFAULTS = Object.freeze({
  taskDelaySeconds: 15,
  taskLocation: "europe-west3",
  taskQueue: "video-clip-processor",
  rateLimitSeconds: 30,
  timestampToleranceSeconds: 90,
  clipLeadSeconds: 10,
});

function requireCourt(courtNumber) {
  const court = COURTS[courtNumber];
  if (!court) {
    throw new VideoConfigurationError("Court camera mapping is not configured");
  }
  return court;
}

function positiveInteger(value, fallback, name) {
  if (value === undefined || value === null || String(value).trim() === "") {
    return fallback;
  }
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) {
    throw new VideoConfigurationError(`${name} must be a positive integer`);
  }
  return parsed;
}

function getProjectId(env) {
  const directProjectId = String(
      env.GCLOUD_PROJECT || env.GCP_PROJECT || env.GOOGLE_CLOUD_PROJECT || "",
  ).trim();
  if (directProjectId) return directProjectId;

  const firebaseConfig = String(env.FIREBASE_CONFIG || "").trim();
  if (firebaseConfig.startsWith("{")) {
    try {
      const parsed = JSON.parse(firebaseConfig);
      if (typeof parsed.projectId === "string" && parsed.projectId.trim()) {
        return parsed.projectId.trim();
      }
    } catch (_) {
      // Fall through to the intentionally generic configuration error below.
    }
  }
  throw new VideoConfigurationError("Google Cloud project ID is not configured");
}

/**
 * Reads only non-secret processor settings.  Secrets are deliberately read in
 * the function entrypoint through Firebase Functions secret bindings.
 */
function getTaskConfig(env = process.env) {
  const processorUrl = String(env.VIDEO_PROCESSOR_URL || "")
      .trim()
      .replace(/\/+$/, "");
  const serviceAccountEmail = String(
      env.VIDEO_TASK_SERVICE_ACCOUNT_EMAIL || "",
  ).trim();

  if (!processorUrl || !/^https:\/\//i.test(processorUrl)) {
    throw new VideoConfigurationError(
        "VIDEO_PROCESSOR_URL must be an HTTPS URL",
    );
  }
  if (!serviceAccountEmail || !serviceAccountEmail.includes("@")) {
    throw new VideoConfigurationError(
        "VIDEO_TASK_SERVICE_ACCOUNT_EMAIL must be configured",
    );
  }

  return {
    projectId: getProjectId(env),
    location: String(env.VIDEO_TASK_LOCATION || DEFAULTS.taskLocation).trim(),
    queue: String(env.VIDEO_TASK_QUEUE || DEFAULTS.taskQueue).trim(),
    processorUrl,
    serviceAccountEmail,
    taskDelaySeconds: positiveInteger(
        env.VIDEO_TASK_DELAY_SECONDS,
        DEFAULTS.taskDelaySeconds,
        "VIDEO_TASK_DELAY_SECONDS",
    ),
  };
}

function getIngressSettings(env = process.env) {
  return {
    clipLeadSeconds: positiveInteger(
        env.VIDEO_CLIP_LEAD_SECONDS,
        DEFAULTS.clipLeadSeconds,
        "VIDEO_CLIP_LEAD_SECONDS",
    ),
    rateLimitSeconds: positiveInteger(
        env.VIDEO_BUTTON_RATE_LIMIT_SECONDS,
        DEFAULTS.rateLimitSeconds,
        "VIDEO_BUTTON_RATE_LIMIT_SECONDS",
    ),
    timestampToleranceSeconds: positiveInteger(
        env.VIDEO_TIMESTAMP_TOLERANCE_SECONDS,
        DEFAULTS.timestampToleranceSeconds,
        "VIDEO_TIMESTAMP_TOLERANCE_SECONDS",
    ),
  };
}

module.exports = {
  COURTS,
  DEFAULTS,
  getIngressSettings,
  getProjectId,
  getTaskConfig,
  requireCourt,
};
