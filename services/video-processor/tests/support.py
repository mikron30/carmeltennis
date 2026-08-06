from __future__ import annotations

from app.config import Settings


def settings_env(**overrides: str) -> dict[str, str]:
    values = {
        "VIDEO_CLIP_BUCKET": "unit-test-video-bucket",
        "GOOGLE_CLOUD_PROJECT": "unit-test-project",
        "NVR_BASE_URL": "https://nvr.example.invalid:8443",
        "NVR_USERNAME": "test-user",
        "NVR_PASSWORD": "test-password",
        "MAIL_SERVICE_URL": "https://mail.example.invalid/sendMail",
        "COURT_CAMERA_MAP": "1:4:Left Court,2:6:Right Court,3:7:Back Court",
        # The local Windows interpreter used by repository tests may not have an
        # IANA tzdata database installed. The production image pins `tzdata`.
        "NVR_TIME_ZONE": "UTC",
    }
    values.update(overrides)
    return values


def settings(**overrides: str) -> Settings:
    return Settings.from_env(settings_env(**overrides))
