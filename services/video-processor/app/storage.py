"""Private Cloud Storage upload and short-lived V4 download URL creation."""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

from .config import Settings
from .errors import StorageOperationError
from .jobs import validate_request_id


@dataclass(frozen=True)
class StoredClip:
    object_name: str
    bytes_written: int


@dataclass(frozen=True)
class SignedDownload:
    url: str
    expires_at: datetime


class CloudStorageClipStore:
    """Stores only private objects; callers keep signed URLs in memory only."""

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
        return StoredClip(object_name=object_name, bytes_written=local_path.stat().st_size)

    def create_download(self, object_name: str) -> SignedDownload:
        if not object_name.startswith("video-clips/") or not object_name.endswith(".mp4"):
            raise StorageOperationError("The requested Cloud Storage object is invalid.")
        blob = self._bucket.blob(object_name)
        expires_at = datetime.now(UTC) + timedelta(seconds=self._settings.signed_url_ttl_seconds)
        try:
            url = blob.generate_signed_url(
                version="v4",
                expiration=expires_at,
                method="GET",
                response_type="video/mp4",
                response_disposition="attachment; filename=tennis-court-video.mp4",
            )
        except Exception as error:  # Includes missing IAM signBlob permission.
            raise StorageOperationError("A secure video download URL could not be created.") from error
        return SignedDownload(url=url, expires_at=expires_at)
