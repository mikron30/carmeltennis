from __future__ import annotations

from datetime import UTC, datetime, timedelta
import unittest

from app.errors import JobValidationError
from app.jobs import (
    FirestoreVideoJobRepository,
    normalize_recipients,
    recipient_delivery_key,
    should_claim_job,
    validate_request_id,
)


class FixedClock:
    def __init__(self, value: datetime) -> None:
        self.value = value

    def now(self) -> datetime:
        return self.value


class FakeDocument:
    def __init__(self) -> None:
        self.updates: list[dict] = []

    def update(self, updates: dict) -> None:
        self.updates.append(updates)


class FakeCollection:
    def __init__(self, document: FakeDocument) -> None:
        self._document = document

    def document(self, _: str) -> FakeDocument:
        return self._document


class FakeClient:
    def __init__(self, document: FakeDocument) -> None:
        self._document = document

    def collection(self, _: str) -> FakeCollection:
        return FakeCollection(self._document)


class JobPolicyTest(unittest.TestCase):
    def test_recipient_normalization_deduplicates_case_insensitively(self) -> None:
        recipients = normalize_recipients([" Player@example.com ", "player@example.com", "partner@example.com"])

        self.assertEqual(recipients, ("player@example.com", "partner@example.com"))
        self.assertEqual(len(recipient_delivery_key(recipients[0])), 64)

    def test_active_lease_cannot_be_claimed(self) -> None:
        now = datetime(2026, 8, 4, 9, 0, tzinfo=UTC)
        should_process, reason = should_claim_job(
            {"status": "processing", "attempts": 1, "processingLeaseExpiresAt": now + timedelta(minutes=1)},
            now,
            5,
        )

        self.assertFalse(should_process)
        self.assertEqual(reason, "active_lease")

    def test_terminal_failed_job_cannot_be_claimed(self) -> None:
        should_process, reason = should_claim_job({"status": "failed", "retryable": False}, datetime.now(UTC), 5)

        self.assertFalse(should_process)
        self.assertEqual(reason, "terminal_failure")

    def test_invalid_request_id_is_rejected(self) -> None:
        with self.assertRaises(JobValidationError):
            validate_request_id("a/path")

    def test_artifact_persists_only_direct_link_expiry_not_bearer_url(self) -> None:
        now = datetime(2026, 8, 20, 9, 0, tzinfo=UTC)
        expires_at = now + timedelta(days=7)
        document = FakeDocument()
        repository = FirestoreVideoJobRepository(
            FakeClient(document),
            clock=FixedClock(now),
        )

        repository.record_artifact(
            "request-1",
            object_name="video-clips/object.mp4",
            clip_bytes=123,
            clip_duration_seconds=10.0,
            camera_channel=4,
            url_expires_at=expires_at,
        )

        updates = document.updates[0]
        self.assertEqual(updates["linkExpiresAt"], expires_at)
        self.assertFalse(any("url" in key.lower() for key in updates))


if __name__ == "__main__":
    unittest.main()
