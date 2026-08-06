from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path
import unittest

from app.errors import RecordingNotReadyError
from app.hikvision import RecordingDownload
from app.jobs import JobClaim
from app.media import ProcessedClip
from app.processor import VideoProcessor
from app.storage import SignedDownload, StoredClip

from tests.support import settings


@dataclass
class FakeRepository:
    job: dict
    released: list[str]
    sent: bool = False
    artifact: dict | None = None
    delivery_keys: set[str] | None = None

    def __post_init__(self) -> None:
        self.delivery_keys = self.delivery_keys or set()

    def claim(self, request_id: str, **_: object) -> JobClaim:
        return JobClaim(request_id, self.job, True, "claimed")

    def delivered_recipient_keys(self, _: dict) -> set[str]:
        return set(self.delivery_keys or set())

    def record_artifact(self, _: str, **kwargs: object) -> None:
        self.artifact = dict(kwargs)

    def mark_recipient_sent(self, _: str, recipient_key: str) -> None:
        assert self.delivery_keys is not None
        self.delivery_keys.add(recipient_key)

    def mark_sent(self, _: str) -> None:
        self.sent = True

    def fail_permanently(self, _: str, **kwargs: object) -> None:
        self.released.append(f"permanent:{kwargs['code']}")

    def release_for_retry(self, _: str, **kwargs: object) -> None:
        self.released.append(f"retry:{kwargs['code']}")


class FakeHikvision:
    def download_recording(self, *, destination: Path, **_: object) -> RecordingDownload:
        destination.write_bytes(b"raw")
        now = datetime.now(UTC)
        return RecordingDownload(destination, now, now + timedelta(seconds=30), 3)


class NotReadyHikvision:
    def download_recording(self, **_: object) -> RecordingDownload:
        raise RecordingNotReadyError("not ready")


class FakeMedia:
    def transcode_browser_mp4(self, _: RecordingDownload, *, destination: Path, **__: object) -> ProcessedClip:
        destination.write_bytes(b"mp4")
        return ProcessedClip(destination, 3, 10.0)


class FakeStorage:
    def upload(self, _: str, local_path: Path) -> StoredClip:
        return StoredClip("video-clips/test.mp4", local_path.stat().st_size)

    def create_download(self, _: str) -> SignedDownload:
        return SignedDownload("https://signed.example.invalid/clip", datetime.now(UTC) + timedelta(hours=1))


class FakeMailer:
    def __init__(self) -> None:
        self.recipients: list[str] = []

    def send_clip_link(self, *, recipient: str, **_: object) -> None:
        self.recipients.append(recipient)


class VideoProcessorTest(unittest.TestCase):
    def _job(self) -> dict:
        end = datetime(2026, 8, 4, 9, 0, tzinfo=UTC)
        return {
            "status": "queued",
            "requestKind": "esp32",
            "courtNumber": 1,
            "cameraChannel": 4,
            "clipStart": end - timedelta(seconds=10),
            "clipEnd": end,
            "recipients": ["player@example.com", "partner@example.com"],
        }

    def test_marks_job_sent_after_each_recipient_is_accepted(self) -> None:
        repository = FakeRepository(self._job(), [])
        mailer = FakeMailer()
        processor = VideoProcessor(
            settings(),
            repository=repository,
            hikvision=FakeHikvision(),
            media=FakeMedia(),
            storage=FakeStorage(),
            mailer=mailer,
        )

        result = processor.process("request-1")

        self.assertEqual(result.outcome, "sent")
        self.assertTrue(repository.sent)
        self.assertEqual(mailer.recipients, ["player@example.com", "partner@example.com"])
        self.assertIsNotNone(repository.artifact)
        self.assertNotIn("url", repository.artifact or {})

    def test_nvr_not_ready_releases_job_for_task_retry(self) -> None:
        repository = FakeRepository(self._job(), [])
        processor = VideoProcessor(
            settings(),
            repository=repository,
            hikvision=NotReadyHikvision(),
            media=FakeMedia(),
            storage=FakeStorage(),
            mailer=FakeMailer(),
        )

        with self.assertRaises(RecordingNotReadyError):
            processor.process("request-2")
        self.assertEqual(repository.released, ["retry:recording_not_ready"])


if __name__ == "__main__":
    unittest.main()
