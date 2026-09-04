from __future__ import annotations

import unittest

from app.config import ConfigurationError, Settings

from tests.support import settings_env


class SettingsTest(unittest.TestCase):
    def test_default_mapping_matches_the_three_courts(self) -> None:
        result = Settings.from_env(settings_env(COURT_CAMERA_MAP=""))

        self.assertEqual((result.camera_for_court(1).channel, result.camera_for_court(1).label), (4, "Left Court"))
        self.assertEqual((result.camera_for_court(2).channel, result.camera_for_court(2).label), (6, "Right Court"))
        self.assertEqual((result.camera_for_court(3).channel, result.camera_for_court(3).label), (7, "Back Court"))

    def test_http_nvr_requires_explicit_opt_in(self) -> None:
        with self.assertRaisesRegex(ConfigurationError, "uses HTTP"):
            Settings.from_env(settings_env(NVR_BASE_URL="http://nvr.example.invalid:8080"))

        configured = Settings.from_env(
            settings_env(
                NVR_BASE_URL="http://nvr.example.invalid:8080",
                NVR_ALLOW_INSECURE_HTTP="true",
            ),
        )
        self.assertTrue(configured.nvr_allow_insecure_http)

    def test_duplicate_mapping_is_rejected(self) -> None:
        with self.assertRaisesRegex(ConfigurationError, "unique"):
            Settings.from_env(settings_env(COURT_CAMERA_MAP="1:4,2:4"))

    def test_direct_signed_links_default_to_seven_days(self) -> None:
        values = settings_env()
        values.pop("SIGNED_URL_TTL_SECONDS")

        configured = Settings.from_env(values)

        self.assertEqual(configured.signed_url_ttl_seconds, 604_800)
        self.assertEqual(
            configured.signed_url_service_account_email,
            "video-processor-runtime@unit-test-project.iam.gserviceaccount.com",
        )

    def test_direct_signed_link_ttl_cannot_exceed_seven_days(self) -> None:
        with self.assertRaisesRegex(ConfigurationError, "SIGNED_URL_TTL_SECONDS"):
            Settings.from_env(settings_env(SIGNED_URL_TTL_SECONDS="604801"))


if __name__ == "__main__":
    unittest.main()
