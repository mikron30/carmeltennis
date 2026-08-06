"""Cloud Run HTTP entry point.

Cloud Run IAM is the authentication boundary: only the Cloud Tasks caller
service account receives run.invoker. The task header check below is defence in
depth, not a substitute for that IAM binding.
"""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Callable

from flask import Flask, jsonify, request

from .config import ConfigurationError, Settings
from .errors import JobValidationError, TransientProcessingError, VideoProcessingError
from .jobs import validate_request_id
from .processor import VideoProcessor, build_processor


LOGGER = logging.getLogger(__name__)
ProcessorFactory = Callable[[Settings], VideoProcessor]
SettingsFactory = Callable[[], Settings]


def create_app(
    *,
    processor_factory: ProcessorFactory | None = None,
    settings_factory: SettingsFactory = Settings.from_env,
) -> Flask:
    app = Flask(__name__)
    app.config["MAX_CONTENT_LENGTH"] = 4 * 1024
    factory = processor_factory or build_processor

    @lru_cache(maxsize=1)
    def settings() -> Settings:
        return settings_factory()

    @lru_cache(maxsize=1)
    def processor() -> VideoProcessor:
        return factory(settings())

    @app.get("/healthz")
    def healthz() -> tuple[object, int]:
        try:
            settings()
        except ConfigurationError as error:
            LOGGER.error("video_processor_configuration_invalid error=%s", error)
            return jsonify({"ok": False, "reason": "configuration_invalid"}), 503
        return jsonify({"ok": True}), 200

    @app.post("/tasks/process-video")
    def process_video_task() -> tuple[object, int]:
        try:
            runtime_settings = settings()
        except ConfigurationError as error:
            LOGGER.error("video_processor_configuration_invalid error=%s", error)
            # A configuration correction should allow the existing Cloud Task to
            # retry; don't silently acknowledge it as a successful clip request.
            return jsonify({"error": "configuration_invalid"}), 503

        task_name = request.headers.get("X-CloudTasks-TaskName", "")
        if runtime_settings.require_cloud_tasks_header and not task_name:
            LOGGER.warning("video_processor_non_task_request_rejected")
            return jsonify({"error": "cloud_tasks_header_required"}), 403

        payload = request.get_json(silent=True)
        request_id = payload.get("requestId") if isinstance(payload, dict) else None
        try:
            request_id = validate_request_id(request_id)
        except JobValidationError:
            # Cloud Tasks retries non-2xx responses. A malformed trusted task
            # cannot be fixed by retrying, so acknowledge it without echoing data.
            LOGGER.warning("video_processor_malformed_task")
            return jsonify({"outcome": "rejected"}), 200

        try:
            result = processor().process(request_id)
        except TransientProcessingError as error:
            LOGGER.warning("video_processor_task_retry request_id=%s code=%s", request_id, error.code)
            return jsonify({"requestId": request_id, "outcome": "retry"}), 503
        except VideoProcessingError as error:
            # Permanent errors are normally recorded by VideoProcessor. Avoid a
            # retry loop for a malformed/terminal job if one escapes that layer.
            LOGGER.warning("video_processor_task_rejected request_id=%s code=%s", request_id, error.code)
            return jsonify({"requestId": request_id, "outcome": "failed"}), 200
        except Exception as error:  # pragma: no cover - last-resort task retry
            LOGGER.error(
                "video_processor_task_unexpected_error request_id=%s exception_type=%s",
                request_id,
                type(error).__name__,
            )
            return jsonify({"requestId": request_id, "outcome": "retry"}), 503

        return jsonify({"requestId": request_id, "outcome": result.outcome}), 200

    return app


app = create_app()
