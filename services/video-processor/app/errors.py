"""Errors with safe, stable codes for Firestore job state and task retries."""

from __future__ import annotations


class VideoProcessingError(Exception):
    """Base error; subclasses choose whether Cloud Tasks should retry."""

    code = "video_processing_failed"
    retryable = False

    def __init__(self, message: str | None = None) -> None:
        self.safe_message = message or self.code
        super().__init__(self.safe_message)


class PermanentProcessingError(VideoProcessingError):
    """A job cannot succeed without a human/data correction."""


class TransientProcessingError(VideoProcessingError):
    """A temporary infrastructure or upstream error."""

    retryable = True


class JobNotFoundError(PermanentProcessingError):
    code = "job_not_found"


class JobValidationError(PermanentProcessingError):
    code = "invalid_job"


class JobStateError(PermanentProcessingError):
    code = "invalid_job_state"


class RecordingNotReadyError(TransientProcessingError):
    code = "recording_not_ready"


class NvrAuthenticationError(PermanentProcessingError):
    code = "nvr_authentication_failed"


class NvrProtocolError(PermanentProcessingError):
    code = "nvr_protocol_failed"


class NvrUnavailableError(TransientProcessingError):
    code = "nvr_unavailable"


class MediaProcessingError(PermanentProcessingError):
    code = "media_processing_failed"


class StorageOperationError(TransientProcessingError):
    code = "storage_operation_failed"


class VideoAccessExpiredError(PermanentProcessingError):
    code = "video_access_expired"


class MailDeliveryError(TransientProcessingError):
    code = "mail_delivery_failed"


class MailConfigurationError(PermanentProcessingError):
    code = "mail_configuration_failed"
