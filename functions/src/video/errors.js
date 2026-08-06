"use strict";

/**
 * An error whose code is safe to return to a caller.  Internal exception
 * messages (for example, from Firestore or Cloud Tasks) must never be sent to
 * an ESP32 or a callable client.
 */
class VideoRequestError extends Error {
  constructor(code, message, {httpStatus = 400, cause} = {}) {
    super(message, cause ? {cause} : undefined);
    this.name = "VideoRequestError";
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

class VideoConfigurationError extends VideoRequestError {
  constructor(message, options = {}) {
    super("video_configuration_error", message, {
      httpStatus: 503,
      ...options,
    });
    this.name = "VideoConfigurationError";
  }
}

class VideoTaskEnqueueError extends VideoRequestError {
  constructor(message, options = {}) {
    super("video_queue_unavailable", message, {
      httpStatus: 503,
      ...options,
    });
    this.name = "VideoTaskEnqueueError";
  }
}

function isVideoRequestError(error) {
  return error instanceof VideoRequestError;
}

module.exports = {
  VideoConfigurationError,
  VideoRequestError,
  VideoTaskEnqueueError,
  isVideoRequestError,
};
