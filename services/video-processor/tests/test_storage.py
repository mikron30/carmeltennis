from __future__ import annotations

from datetime import UTC, datetime, timedelta
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from app.errors import StorageOperationError
from app.storage import CloudStorageClipStore, StoredClip

from tests.support import settings


class FakeBlob:
    def __init__(self, *, exists: bool, created_at: datetime) -> None:
        self._exists = exists
        self.time_created = created_at
        self.cache_control: str | None = None
        self.uploaded = False
        self.reloaded = False
        self.signed_options: dict | None = None
        self.signed_url = "https://storage.googleapis.test/object?signature=secret"

    def exists(self) -> bool:
        return self._exists

    def upload_from_filename(self, *_: object, **__: object) -> None:
        self.uploaded = True
        self._exists = True

    def reload(self) -> None:
        self.reloaded = True

    def generate_signed_url(self, **options: object) -> str:
        self.signed_options = dict(options)
        return self.signed_url


class FakeBucket:
    def __init__(self, blob: FakeBlob) -> None:
        self._blob = blob
        self.object_name: str | None = None

    def blob(self, object_name: str) -> FakeBlob:
        self.object_name = object_name
        return self._blob


class FakeStorageClient:
    def __init__(self, bucket: FakeBucket) -> None:
        self._bucket = bucket

    def bucket(self, _: str) -> FakeBucket:
        return self._bucket


class CloudStorageClipStoreTest(unittest.TestCase):
    def test_upload_returns_authoritative_object_creation_time(self) -> None:
        created_at = datetime(2026, 8, 20, 9, 0, tzinfo=UTC)
        blob = FakeBlob(exists=False, created_at=created_at)
        bucket = FakeBucket(blob)
        store = CloudStorageClipStore(
            settings(),
            client=FakeStorageClient(bucket),
        )

        with tempfile.TemporaryDirectory() as directory:
            clip = Path(directory) / "clip.mp4"
            clip.write_bytes(b"mp4")
            result = store.upload("request-1", clip)

        self.assertTrue(blob.uploaded)
        self.assertTrue(blob.reloaded)
        self.assertEqual(result.created_at, created_at)
        self.assertEqual(result.bytes_written, 3)
        self.assertRegex(result.object_name, r"^video-clips/[a-f0-9]{64}\.mp4$")

    def test_create_download_returns_direct_v4_url_for_remaining_retention(self) -> None:
        created_at = datetime.now(UTC) - timedelta(minutes=1)
        blob = FakeBlob(exists=True, created_at=created_at)
        store = CloudStorageClipStore(
            settings(SIGNED_URL_SERVICE_ACCOUNT_EMAIL=""),
            client=FakeStorageClient(FakeBucket(blob)),
        )

        result = store.create_download(
            StoredClip("video-clips/" + ("a" * 64) + ".mp4", 123, created_at),
        )

        self.assertEqual(result.url, blob.signed_url)
        self.assertNotIn(result.url, repr(result))
        self.assertIsNotNone(blob.signed_options)
        options = blob.signed_options or {}
        self.assertEqual(options["version"], "v4")
        self.assertEqual(options["method"], "GET")
        self.assertEqual(options["response_type"], "video/mp4")
        self.assertEqual(
            options["response_disposition"],
            "attachment; filename=tennis-court-video.mp4",
        )
        self.assertEqual(options["expiration"], created_at + timedelta(days=7))

    def test_create_download_delegates_signing_to_configured_service_account(self) -> None:
        created_at = datetime.now(UTC) - timedelta(minutes=1)
        blob = FakeBlob(exists=True, created_at=created_at)
        store = CloudStorageClipStore(
            settings(),
            client=FakeStorageClient(FakeBucket(blob)),
        )
        credentials = Mock(token="access-token")

        with patch("google.auth.default", return_value=(credentials, "project")):
            store.create_download(
                StoredClip("video-clips/" + ("b" * 64) + ".mp4", 123, created_at),
            )

        credentials.refresh.assert_called_once()
        options = blob.signed_options or {}
        self.assertEqual(
            options["service_account_email"],
            "video-processor-runtime@unit-test-project.iam.gserviceaccount.com",
        )
        self.assertEqual(options["access_token"], "access-token")

    def test_create_download_rejects_invalid_object_name(self) -> None:
        created_at = datetime.now(UTC)
        store = CloudStorageClipStore(
            settings(SIGNED_URL_SERVICE_ACCOUNT_EMAIL=""),
            client=FakeStorageClient(FakeBucket(FakeBlob(exists=True, created_at=created_at))),
        )

        with self.assertRaises(StorageOperationError):
            store.create_download(StoredClip("other/object.mp4", 123, created_at))


if __name__ == "__main__":
    unittest.main()
