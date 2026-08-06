"""End-to-end orchestration for one video_clip_requests Firestore document."""

from __future__ import annotations

import logging
import tempfile
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Mapping, Protocol

from .config import CourtCamera, Settings
from .errors import (
    JobNotFoundError,
    JobValidationError,
    TransientProcessingError,
    VideoProcessingError,
)
from .hikvision import HikvisionClient
from .jobs import (
    FirestoreVideoJobRepository,
    as_utc_datetime,
    normalize_recipients,
    recipient_delivery_key,
)
from .mailer import MailServiceClient
from .media import MediaProcessor
from .storage import CloudStorageClipStore


LOGGER = logging.getLogger(__name__)


class JobRepository(Protocol):
    def claim(self, request_id: str, *, max_attempts: int, lease_seconds: int) -> Any: ...

    def delivered_recipient_keys(self, job: Mapping[str, Any]) -> set[str]: ...

    def record_artifact(self, request_id: str, **kwargs: Any) -> None: ...

    def mark_recipient_sent(self, request_id: str, recipient_key: str) -> None: ...

    def mark_sent(self, request_id: str) -> None: ...

    def fail_permanently(self, request_id: str, *, code: str, message: str) -> None: ...

    def release_for_retry(self, request_id: str, *, code: str, message: str) -> None: ...


@dataclass(frozen=True)
class VideoJob:
    court_number: int
    camera: CourtCamera
    clip_start: datetime
    clip_end: datetime
    recipients: tuple[str, ...]


@dataclass(frozen=True)
class ProcessResult:
    request_id: str
    outcome: str
    detail: str


class VideoProcessor:
    def __init__(
        self,
        settings: Settings,
        *,
        repository: JobRepository,
        hikvision: HikvisionClient,
        media: MediaProcessor,
        storage: CloudStorageClipStore,
        mailer: MailServiceClient,
    ) -> None:
        self._settings = settings
        self._repository = repository
        self._hikvision = hikvision
        self._media = media
        self._storage = storage
        self._mailer = mailer

    def process(self, request_id: str) -> ProcessResult:
        try:
            claim = self._repository.claim(
                request_id,
                max_attempts=self._settings.max_processing_attempts,
                lease_seconds=self._settings.processing_lease_seconds,
            )
        except JobNotFoundError:
            # A deleted job has no work to retry; acknowledge the Cloud Task.
            LOGGER.warning("video_job_missing request_id=%s", request_id)
            return ProcessResult(request_id, "noop", "job_not_found")

        if not claim.should_process:
            LOGGER.info("video_job_not_claimed request_id=%s reason=%s", request_id, claim.reason)
            return ProcessResult(request_id, "noop", claim.reason)
        if not isinstance(claim.job, Mapping):
            self._repository.fail_permanently(
                request_id,
                code="invalid_job",
                message="The request document does not contain job data.",
            )
            return ProcessResult(request_id, "failed", "invalid_job")

        try:
            job = self._parse_job(claim.job)
            with tempfile.TemporaryDirectory(prefix="carmel-video-") as temp_directory:
                temporary_path = Path(temp_directory)
                recording = self._hikvision.download_recording(
                    camera_channel=job.camera.channel,
                    clip_start=job.clip_start,
                    clip_end=job.clip_end,
                    destination=temporary_path / "recording.bin",
                )
                mp4 = self._media.transcode_browser_mp4(
                    recording,
                    clip_start=job.clip_start,
                    clip_end=job.clip_end,
                    destination=temporary_path / "court-video.mp4",
                )
                stored_clip = self._storage.upload(request_id, mp4.path)
                signed_download = self._storage.create_download(stored_clip.object_name)
                self._repository.record_artifact(
                    request_id,
                    object_name=stored_clip.object_name,
                    clip_bytes=mp4.bytes_written,
                    clip_duration_seconds=mp4.duration_seconds,
                    camera_channel=job.camera.channel,
                    url_expires_at=signed_download.expires_at,
                )
                delivered = self._repository.delivered_recipient_keys(claim.job)
                for recipient in job.recipients:
                    delivery_key = recipient_delivery_key(recipient)
                    if delivery_key in delivered:
                        continue
                    self._mailer.send_clip_link(
                        recipient=recipient,
                        request_id=request_id,
                        court_number=job.court_number,
                        court_label=job.camera.label,
                        clip_end=job.clip_end,
                        download_url=signed_download.url,
                    )
                    # Persist after every recipient so a retry does not resend to
                    # someone who was already successfully accepted by the mail API.
                    self._repository.mark_recipient_sent(request_id, delivery_key)
                    delivered.add(delivery_key)
                self._repository.mark_sent(request_id)
        except VideoProcessingError as error:
            if error.retryable:
                self._repository.release_for_retry(
                    request_id,
                    code=error.code,
                    message=error.safe_message,
                )
                LOGGER.warning("video_job_retry request_id=%s code=%s", request_id, error.code)
                raise
            self._repository.fail_permanently(
                request_id,
                code=error.code,
                message=error.safe_message,
            )
            LOGGER.warning("video_job_failed request_id=%s code=%s", request_id, error.code)
            return ProcessResult(request_id, "failed", error.code)
        except Exception as error:
            # Do not log `str(error)`: libraries can include URLs or upstream
            # bodies. The traceback class is enough for operators to correlate a
            # Cloud Run error with this job without exposing bearer credentials.
            self._repository.release_for_retry(
                request_id,
                code="unexpected_processor_error",
                message="The video processor encountered an unexpected temporary error.",
            )
            LOGGER.error(
                "video_job_unexpected_error request_id=%s exception_type=%s",
                request_id,
                type(error).__name__,
            )
            raise TransientProcessingError("The video processor encountered a temporary error.") from error

        LOGGER.info("video_job_sent request_id=%s", request_id)
        return ProcessResult(request_id, "sent", "sent")

    def _parse_job(self, data: Mapping[str, Any]) -> VideoJob:
        if data.get("requestKind") not in {"esp32", "manager"}:
            raise JobValidationError("The job request kind is not supported.")
        court_number = _positive_integer(data.get("courtNumber"), "courtNumber")
        try:
            camera = self._settings.camera_for_court(court_number)
        except ValueError as error:
            raise JobValidationError("The job court has no configured camera.") from error

        camera_channel = data.get("cameraChannel")
        if camera_channel is not None and _positive_integer(camera_channel, "cameraChannel") != camera.channel:
            raise JobValidationError("The job camera channel does not match the configured court mapping.")

        clip_end_value = data.get("clipEnd", data.get("pressedAt"))
        clip_end = as_utc_datetime(clip_end_value, "clipEnd")
        clip_start_value = data.get("clipStart")
        clip_start = (
            as_utc_datetime(clip_start_value, "clipStart")
            if clip_start_value is not None
            else clip_end - timedelta(seconds=10)
        )
        duration = (clip_end - clip_start).total_seconds()
        if duration <= 0 or duration > self._settings.max_clip_seconds:
            raise JobValidationError("The job clip interval is outside the allowed duration.")
        return VideoJob(
            court_number=court_number,
            camera=camera,
            clip_start=clip_start,
            clip_end=clip_end,
            recipients=normalize_recipients(data.get("recipients")),
        )


def build_processor(settings: Settings) -> VideoProcessor:
    """Construct production dependencies using Cloud Run Application Default Credentials."""

    try:
        from google.cloud import firestore
    except ImportError as error:  # pragma: no cover - deployment dependency
        raise RuntimeError("google-cloud-firestore must be installed") from error
    firestore_client = firestore.Client(project=settings.project_id)
    return VideoProcessor(
        settings,
        repository=FirestoreVideoJobRepository(firestore_client),
        hikvision=HikvisionClient(settings),
        media=MediaProcessor(settings),
        storage=CloudStorageClipStore(settings),
        mailer=MailServiceClient(settings),
    )


def _positive_integer(value: object, field_name: str) -> int:
    if isinstance(value, bool):
        raise JobValidationError(f"job {field_name} must be a positive integer")
    if isinstance(value, int):
        result = value
    elif isinstance(value, float) and value.is_integer():
        result = int(value)
    elif isinstance(value, str) and value.strip().isdigit():
        result = int(value.strip())
    else:
        raise JobValidationError(f"job {field_name} must be a positive integer")
    if result < 1:
        raise JobValidationError(f"job {field_name} must be a positive integer")
    return result
