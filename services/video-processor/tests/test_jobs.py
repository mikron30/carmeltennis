from __future__ import annotations

from datetime import UTC, datetime, timedelta
import unittest

from app.errors import JobValidationError
from app.jobs import normalize_recipients, recipient_delivery_key, should_claim_job, validate_request_id


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


if __name__ == "__main__":
    unittest.main()
