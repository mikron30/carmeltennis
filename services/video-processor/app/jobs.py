"""Firestore persistence and idempotent state transitions for clip jobs."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Any, Mapping, Protocol

from .errors import JobNotFoundError, JobValidationError


VIDEO_REQUESTS_COLLECTION = "video_clip_requests"
REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,199}$")
EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


class Clock(Protocol):
    def now(self) -> datetime: ...


class UtcClock:
    def now(self) -> datetime:
        return datetime.now(UTC)


@dataclass(frozen=True)
class JobClaim:
    request_id: str
    job: Mapping[str, Any] | None
    should_process: bool
    reason: str


def validate_request_id(request_id: object) -> str:
    if not isinstance(request_id, str) or not REQUEST_ID_PATTERN.fullmatch(request_id):
        raise JobValidationError("requestId is invalid")
    return request_id


def recipient_delivery_key(email: str) -> str:
    """Use a stable non-PII Firestore map key rather than an email address."""

    return hashlib.sha256(email.encode("utf-8")).hexdigest()


def normalize_recipients(value: object) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise JobValidationError("job recipients must be an array")

    recipients: list[str] = []
    seen: set[str] = set()
    for candidate in value:
        if not isinstance(candidate, str):
            raise JobValidationError("job recipients must contain email strings")
        email = candidate.strip().lower()
        if not EMAIL_PATTERN.fullmatch(email):
            raise JobValidationError("job contains an invalid recipient email")
        if email not in seen:
            recipients.append(email)
            seen.add(email)
    if not recipients:
        raise JobValidationError("job has no recipients")
    return tuple(recipients)


def as_utc_datetime(value: object, field_name: str) -> datetime:
    """Accept Firestore timestamp values plus ISO-8601 values for local tests."""

    if hasattr(value, "to_datetime"):
        value = value.to_datetime()  # Firestore Timestamp
    if isinstance(value, str):
        normalized = value.replace("Z", "+00:00")
        try:
            value = datetime.fromisoformat(normalized)
        except ValueError as error:
            raise JobValidationError(f"job {field_name} is not a valid timestamp") from error
    if not isinstance(value, datetime):
        raise JobValidationError(f"job {field_name} is not a timestamp")
    if value.tzinfo is None:
        raise JobValidationError(f"job {field_name} must include a timezone")
    return value.astimezone(UTC)


def has_active_lease(job: Mapping[str, Any], now: datetime) -> bool:
    value = job.get("processingLeaseExpiresAt")
    if value is None:
        return False
    try:
        return as_utc_datetime(value, "processingLeaseExpiresAt") > now
    except JobValidationError:
        return False


def should_claim_job(job: Mapping[str, Any], now: datetime, max_attempts: int) -> tuple[bool, str]:
    """Pure claim policy, kept independent from the Firestore client for tests."""

    status = job.get("status")
    if status == "sent":
        return False, "already_sent"
    if status == "processing" and has_active_lease(job, now):
        return False, "active_lease"
    if status == "failed" and not bool(job.get("retryable", False)):
        return False, "terminal_failure"
    if status not in {"queued", "processing", "failed"}:
        return False, "invalid_status"
    attempts = _coerce_attempts(job.get("attempts", 0))
    if attempts >= max_attempts:
        return False, "attempts_exhausted"
    return True, "claimed"


class FirestoreVideoJobRepository:
    """Owns all Firestore state mutations made by the private worker."""

    def __init__(
        self,
        client: Any,
        *,
        clock: Clock | None = None,
        collection_name: str = VIDEO_REQUESTS_COLLECTION,
    ) -> None:
        self._client = client
        self._clock = clock or UtcClock()
        self._collection = client.collection(collection_name)

    def claim(self, request_id: str, *, max_attempts: int, lease_seconds: int) -> JobClaim:
        validate_request_id(request_id)
        firestore = _firestore_module()
        reference = self._collection.document(request_id)
        now = self._clock.now()

        @firestore.transactional
        def claim_in_transaction(transaction: Any) -> JobClaim:
            snapshot = reference.get(transaction=transaction)
            if not snapshot.exists:
                raise JobNotFoundError("video request does not exist")
            job = dict(snapshot.to_dict() or {})
            should_process, reason = should_claim_job(job, now, max_attempts)
            if not should_process:
                if reason == "attempts_exhausted":
                    transaction.update(
                        reference,
                        {
                            "status": "failed",
                            "retryable": False,
                            "failureCode": "attempts_exhausted",
                            "failureMessage": "The video processor exhausted its retry budget.",
                            "failedAt": now,
                            "updatedAt": now,
                        },
                    )
                elif reason == "invalid_status":
                    transaction.update(
                        reference,
                        {
                            "status": "failed",
                            "retryable": False,
                            "failureCode": "invalid_job_state",
                            "failureMessage": "The request has an unsupported processing state.",
                            "failedAt": now,
                            "updatedAt": now,
                        },
                    )
                return JobClaim(request_id, job, False, reason)

            attempts = _coerce_attempts(job.get("attempts", 0)) + 1
            updates = {
                "status": "processing",
                "retryable": False,
                "attempts": attempts,
                "processingStartedAt": now,
                "processingLeaseExpiresAt": now + timedelta(seconds=lease_seconds),
                "updatedAt": now,
            }
            transaction.update(reference, updates)
            return JobClaim(request_id, {**job, **updates}, True, "claimed")

        return claim_in_transaction(self._client.transaction())

    def record_artifact(
        self,
        request_id: str,
        *,
        object_name: str,
        clip_bytes: int,
        clip_duration_seconds: float,
        camera_channel: int,
        url_expires_at: datetime,
    ) -> None:
        self._update(
            request_id,
            {
                "storageObject": object_name,
                "clipBytes": clip_bytes,
                "clipDurationSeconds": round(clip_duration_seconds, 3),
                "cameraChannel": camera_channel,
                # Deliberately save expiry metadata only. A signed URL is a bearer
                # credential and must never be put in Firestore or application logs.
                "linkExpiresAt": url_expires_at,
                "updatedAt": self._clock.now(),
            },
        )

    def delivered_recipient_keys(self, job: Mapping[str, Any]) -> set[str]:
        deliveries = job.get("recipientDeliveries")
        if not isinstance(deliveries, Mapping):
            return set()
        return {
            str(key)
            for key, value in deliveries.items()
            if isinstance(value, Mapping) and value.get("status") == "sent"
        }

    def mark_recipient_sent(self, request_id: str, recipient_key: str) -> None:
        if not re.fullmatch(r"[a-f0-9]{64}", recipient_key):
            raise JobValidationError("recipient delivery key is invalid")
        now = self._clock.now()
        self._update(
            request_id,
            {
                f"recipientDeliveries.{recipient_key}": {
                    "status": "sent",
                    "sentAt": now,
                },
                "updatedAt": now,
            },
        )

    def mark_sent(self, request_id: str) -> None:
        now = self._clock.now()
        self._update(
            request_id,
            {
                "status": "sent",
                "retryable": False,
                "sentAt": now,
                "processingLeaseExpiresAt": None,
                "failureCode": None,
                "failureMessage": None,
                "updatedAt": now,
            },
        )

    def fail_permanently(self, request_id: str, *, code: str, message: str) -> None:
        now = self._clock.now()
        self._update(
            request_id,
            {
                "status": "failed",
                "retryable": False,
                "failureCode": _safe_code(code),
                "failureMessage": _safe_message(message),
                "failedAt": now,
                "processingLeaseExpiresAt": None,
                "updatedAt": now,
            },
        )

    def release_for_retry(self, request_id: str, *, code: str, message: str) -> None:
        now = self._clock.now()
        self._update(
            request_id,
            {
                "status": "queued",
                "retryable": True,
                "lastErrorCode": _safe_code(code),
                "lastErrorMessage": _safe_message(message),
                "lastErrorAt": now,
                "processingLeaseExpiresAt": None,
                "updatedAt": now,
            },
        )

    def _update(self, request_id: str, updates: Mapping[str, Any]) -> None:
        validate_request_id(request_id)
        self._collection.document(request_id).update(dict(updates))


def _firestore_module() -> Any:
    try:
        from google.cloud import firestore
    except ImportError as error:  # pragma: no cover - deployment dependency
        raise RuntimeError("google-cloud-firestore must be installed") from error
    return firestore


def _coerce_attempts(value: object) -> int:
    if isinstance(value, bool):
        return 0
    if isinstance(value, int) and value >= 0:
        return value
    if isinstance(value, float) and value.is_integer() and value >= 0:
        return int(value)
    return 0


def _safe_code(value: str) -> str:
    sanitized = re.sub(r"[^a-z0-9_-]", "_", value.lower())
    return sanitized[:80] or "video_processing_failed"


def _safe_message(value: str) -> str:
    # Job messages must not accidentally include an NVR URI, credentials, a
    # signed URL, or verbose upstream response body. Error types supply terse
    # messages; this is an additional size guard.
    redacted = re.sub(r"(?:https?|rtsp)://\S+", "[redacted-url]", value, flags=re.IGNORECASE)
    return re.sub(r"\s+", " ", redacted).strip()[:300] or "Video processing failed."
