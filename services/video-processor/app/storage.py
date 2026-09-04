"""Private Cloud Storage upload and direct V4 download URL creation."""

from __future__ import annotations

import hashlib
import logging
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from .config import Settings
from .errors import StorageOperationError, VideoAccessExpiredError
from .jobs import validate_request_id


LOGGER = logging.getLogger(__name__)


@dataclass(frozen=True)
class StoredClip:
    object_name: str
    bytes_written: int
    created_at: datetime


@dataclass(frozen=True)
class SignedDownload:
    url: str = field(repr=False)
    expires_at: datetime


class CloudStorageClipStore:
    """Stores private, opaque MP4 objects and creates in-memory download URLs."""

    def __init__(self, settings: Settings, client: Any | None = None) -> None:
        self._settings = settings
        if client is None:
            try:
                from google.cloud import storage
            except ImportError as error:  # pragma: no cover - deployment dependency
                raise RuntimeError("google-cloud-storage must be installed") from error
            client = storage.Client(project=settings.project_id)
        self._bucket = client.bucket(settings.video_clip_bucket)

    def object_name_for(self, request_id: str) -> str:
        validate_request_id(request_id)
        # Request IDs may reveal device or booking metadata. A stable hash keeps
        # Cloud Storage object names opaque while remaining retry-idempotent.
        object_id = hashlib.sha256(request_id.encode("utf-8")).hexdigest()
        return f"video-clips/{object_id}.mp4"

    def upload(self, request_id: str, local_path: Path) -> StoredClip:
        if not local_path.is_file() or local_path.stat().st_size <= 0:
            raise StorageOperationError("The MP4 file is unavailable for upload.")
        object_name = self.object_name_for(request_id)
        blob = self._bucket.blob(object_name)
        try:
            if not blob.exists():
                # if_generation_match=0 prevents a retry from replacing an object
                # created by another invocation of the same request.
                blob.cache_control = "private, no-store"
                blob.upload_from_filename(
                    str(local_path),
                    content_type="video/mp4",
                    if_generation_match=0,
                    timeout=300,
                )
        except Exception as error:  # Provider exceptions vary by transport/version.
            # A precondition race is benign only when the expected object now exists.
            try:
                already_exists = blob.exists()
            except Exception:
                already_exists = False
            if not already_exists:
                raise StorageOperationError("The MP4 could not be uploaded to Cloud Storage.") from error

        try:
            # Always reload, including on retries, so access expiry is anchored
            # to the authoritative creation time of the existing live object.
            blob.reload()
        except Exception as error:
            raise StorageOperationError(
                "The uploaded MP4 metadata could not be read from Cloud Storage.",
            ) from error
        created_at = blob.time_created
        if not isinstance(created_at, datetime) or created_at.tzinfo is None:
            raise StorageOperationError(
                "The uploaded MP4 has no valid Cloud Storage creation timestamp.",
            )
        return StoredClip(
            object_name=object_name,
            bytes_written=local_path.stat().st_size,
            created_at=created_at.astimezone(UTC),
        )

    def create_download(self, stored_clip: StoredClip) -> SignedDownload:
        """Create the old-style direct Storage link without persisting it."""

        object_name = stored_clip.object_name
        if not object_name.startswith("video-clips/") or not object_name.endswith(".mp4"):
            raise StorageOperationError("The requested Cloud Storage object is invalid.")

        now = datetime.now(UTC)
        retention_expiry = stored_clip.created_at.astimezone(UTC) + timedelta(
            seconds=self._settings.signed_url_ttl_seconds,
        )
        if retention_expiry <= now:
            raise VideoAccessExpiredError(
                "The stored video has reached the end of its access period.",
            )
        # V4 URLs may not exceed seven days from signing. Capping also protects
        # against small clock differences between Cloud Storage and this worker.
        expires_at = min(
            retention_expiry,
            now + timedelta(seconds=self._settings.signed_url_ttl_seconds),
        )
        blob = self._bucket.blob(object_name)
        try:
            options: dict[str, Any] = {
                "version": "v4",
                "expiration": expires_at,
                "method": "GET",
                "response_type": "video/mp4",
                "response_disposition": "attachment; filename=tennis-court-video.mp4",
            }
            if self._settings.signed_url_service_account_email:
                # Cloud Run metadata credentials have no local private key.
                # IAM Credentials signs the URL without storing a key file.
                from google.auth import default
                from google.auth.transport.requests import Request

                credentials, _ = default(
                    scopes=["https://www.googleapis.com/auth/cloud-platform"],
                )
                credentials.refresh(Request())
                options["service_account_email"] = self._settings.signed_url_service_account_email
                options["access_token"] = credentials.token
            url = blob.generate_signed_url(**options)
        except Exception as error:  # Includes missing IAM signBlob permission.
            LOGGER.warning("video_signed_url_failed exception_type=%s", type(error).__name__)
            raise StorageOperationError(
                "A secure video download URL could not be created.",
            ) from error
        if not isinstance(url, str) or not url.startswith("https://"):
            raise StorageOperationError("A secure video download URL could not be created.")
        return SignedDownload(url=url, expires_at=expires_at)
