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
    def __init__(self) -> None:
        self.requested_interval: tuple[datetime, datetime] | None = None

    def download_recording(
        self,
        *,
        destination: Path,
        clip_start: datetime,
        clip_end: datetime,
        **_: object,
    ) -> RecordingDownload:
        self.requested_interval = (clip_start, clip_end)
        destination.write_bytes(b"raw")
        now = datetime.now(UTC)
        return RecordingDownload(destination, now, now + timedelta(seconds=30), 3)


class NotReadyHikvision:
    def download_recording(self, **_: object) -> RecordingDownload:
        raise RecordingNotReadyError("not ready")


class FakeMedia:
    def __init__(self) -> None:
        self.requested_interval: tuple[datetime, datetime] | None = None

    def transcode_browser_mp4(
        self,
        _: RecordingDownload,
        *,
        destination: Path,
        clip_start: datetime,
        clip_end: datetime,
        **__: object,
    ) -> ProcessedClip:
        self.requested_interval = (clip_start, clip_end)
        destination.write_bytes(b"mp4")
        duration = (clip_end - clip_start).total_seconds()
        return ProcessedClip(destination, 3, duration)


class FakeStorage:
    def __init__(self) -> None:
        self.created_at: datetime | None = None

    def upload(self, _: str, local_path: Path) -> StoredClip:
        stored = StoredClip(
            "video-clips/test.mp4",
            local_path.stat().st_size,
            datetime(2026, 8, 4, 9, 0, tzinfo=UTC),
        )
        self.created_at = stored.created_at
        return stored

    def create_download(self, stored_clip: StoredClip) -> SignedDownload:
        self.created_at = stored_clip.created_at
        return SignedDownload(
            url="https://storage.googleapis.test/download?signature=secret",
            expires_at=stored_clip.created_at + timedelta(days=7),
        )


class FakeMailer:
    def __init__(self) -> None:
        self.recipients: list[str] = []
        self.download_urls: list[str] = []

    def send_clip_link(
        self,
        *,
        recipient: str,
        download_url: str,
        **_: object,
    ) -> None:
        self.recipients.append(recipient)
        self.download_urls.append(download_url)


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
        storage = FakeStorage()
        processor = VideoProcessor(
            settings(),
            repository=repository,
            hikvision=FakeHikvision(),
            media=FakeMedia(),
            storage=storage,
            mailer=mailer,
        )

        result = processor.process("request-1")

        self.assertEqual(result.outcome, "sent")
        self.assertTrue(repository.sent)
        self.assertEqual(mailer.recipients, ["player@example.com", "partner@example.com"])
        self.assertIsNotNone(repository.artifact)
        self.assertNotIn("url", repository.artifact or {})
        self.assertEqual(
            mailer.download_urls,
            [
                "https://storage.googleapis.test/download?signature=secret",
            ]
            * 2,
        )
        self.assertEqual(
            storage.created_at,
            datetime(2026, 8, 4, 9, 0, tzinfo=UTC),
        )
        self.assertEqual(
            (repository.artifact or {}).get("url_expires_at"),
            datetime(2026, 8, 11, 9, 0, tzinfo=UTC),
        )

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

    def test_passes_exact_pre_press_forty_second_interval_to_video_pipeline(self) -> None:
        job = self._job()
        # 18:06:17 UTC is 21:06:17 Asia/Jerusalem on 2026-08-17.
        pressed_at = datetime(2026, 8, 17, 18, 6, 17, tzinfo=UTC)
        job["pressedAt"] = pressed_at
        job["clipStart"] = pressed_at - timedelta(seconds=40)
        job["clipEnd"] = pressed_at
        repository = FakeRepository(job, [])
        hikvision = FakeHikvision()
        media = FakeMedia()
        processor = VideoProcessor(
            settings(),
            repository=repository,
            hikvision=hikvision,
            media=media,
            storage=FakeStorage(),
            mailer=FakeMailer(),
        )

        result = processor.process("request-40-seconds")

        expected = (
            pressed_at - timedelta(seconds=40),
            pressed_at,
        )
        self.assertEqual(result.outcome, "sent")
        self.assertEqual(hikvision.requested_interval, expected)
        self.assertEqual(media.requested_interval, expected)


if __name__ == "__main__":
    unittest.main()
