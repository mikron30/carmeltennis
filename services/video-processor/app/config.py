"""Configuration for the video processor.

Secrets are intentionally read only from process environment variables.  In
Cloud Run those environment variables must be populated using Secret Manager
secret bindings, not a checked-in .env file or a service-account key.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from datetime import UTC, tzinfo
from typing import Mapping
from urllib.parse import urlparse
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


class ConfigurationError(ValueError):
    """Raised before a request is processed when deployment config is invalid."""


@dataclass(frozen=True)
class CourtCamera:
    court_number: int
    channel: int
    label: str


DEFAULT_COURTS: tuple[CourtCamera, ...] = (
    CourtCamera(1, 4, "Left Court"),
    CourtCamera(2, 6, "Right Court"),
    CourtCamera(3, 7, "Back Court"),
)


@dataclass(frozen=True)
class Settings:
    """Validated, non-mutating process configuration."""

    video_clip_bucket: str
    nvr_base_url: str
    nvr_username: str = field(repr=False)
    nvr_password: str = field(repr=False)
    mail_service_url: str
    court_cameras: tuple[CourtCamera, ...]
    nvr_time_zone: tzinfo
    nvr_search_results_are_local_time: bool
    nvr_allow_insecure_http: bool
    nvr_verify_tls: bool | str
    nvr_track_suffix: int
    nvr_search_path: str
    nvr_download_path: str
    nvr_connect_timeout_seconds: int
    nvr_read_timeout_seconds: int
    max_download_bytes: int
    max_output_bytes: int
    max_clip_seconds: int
    ffmpeg_timeout_seconds: int
    signed_url_ttl_seconds: int
    signed_url_service_account_email: str | None
    processing_lease_seconds: int
    max_processing_attempts: int
    require_cloud_tasks_header: bool
    mail_service_bearer_token: str | None = field(repr=False)
    mail_service_timeout_seconds: int
    project_id: str | None

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> "Settings":
        values = os.environ if env is None else env

        def required(name: str) -> str:
            value = str(values.get(name, "")).strip()
            if not value:
                raise ConfigurationError(f"Missing required environment variable: {name}")
            return value

        def optional(name: str, default: str) -> str:
            value = values.get(name)
            return default if value is None or not str(value).strip() else str(value).strip()

        def integer(name: str, default: int, *, minimum: int = 1, maximum: int | None = None) -> int:
            raw = optional(name, str(default))
            try:
                result = int(raw)
            except ValueError as error:
                raise ConfigurationError(f"{name} must be an integer") from error
            if result < minimum or (maximum is not None and result > maximum):
                upper = f" and at most {maximum}" if maximum is not None else ""
                raise ConfigurationError(f"{name} must be at least {minimum}{upper}")
            return result

        nvr_base_url = required("NVR_BASE_URL").rstrip("/")
        parsed = urlparse(nvr_base_url)
        if parsed.scheme not in {"https", "http"} or not parsed.netloc:
            raise ConfigurationError("NVR_BASE_URL must be an absolute HTTP(S) URL")

        allow_insecure_http = _boolean(values, "NVR_ALLOW_INSECURE_HTTP", False)
        if parsed.scheme == "http" and not allow_insecure_http:
            raise ConfigurationError(
                "NVR_BASE_URL uses HTTP. Use HTTPS, a private tunnel, or explicitly set "
                "NVR_ALLOW_INSECURE_HTTP=true after accepting the risk.",
            )

        verify_tls_raw = optional("NVR_VERIFY_TLS", "true")
        nvr_verify_tls: bool | str
        if verify_tls_raw.lower() in {"true", "false"}:
            nvr_verify_tls = verify_tls_raw.lower() == "true"
        else:
            # A path to a custom CA bundle is valid for requests. Do not accept an
            # empty value here because it would silently disable verification.
            nvr_verify_tls = verify_tls_raw

        timezone_name = optional("NVR_TIME_ZONE", "Asia/Jerusalem")
        if timezone_name.upper() == "UTC":
            # UTC is always available even in a minimal local Python install.
            nvr_time_zone: tzinfo = UTC
        else:
            try:
                nvr_time_zone = ZoneInfo(timezone_name)
            except ZoneInfoNotFoundError as error:
                raise ConfigurationError(f"NVR_TIME_ZONE is not a valid IANA zone: {timezone_name}") from error

        signed_url_ttl = integer(
            "SIGNED_URL_TTL_SECONDS",
            604_800,
            minimum=60,
            maximum=604_800,
        )
        lease = integer("PROCESSING_LEASE_SECONDS", 900, minimum=60, maximum=3_600)
        return cls(
            video_clip_bucket=required("VIDEO_CLIP_BUCKET"),
            nvr_base_url=nvr_base_url,
            nvr_username=required("NVR_USERNAME"),
            nvr_password=required("NVR_PASSWORD"),
            mail_service_url=required("MAIL_SERVICE_URL"),
            court_cameras=_parse_court_cameras(optional("COURT_CAMERA_MAP", "")),
            nvr_time_zone=nvr_time_zone,
            nvr_search_results_are_local_time=_boolean(
                values,
                "NVR_SEARCH_RESULTS_ARE_LOCAL_TIME",
                False,
            ),
            nvr_allow_insecure_http=allow_insecure_http,
            nvr_verify_tls=nvr_verify_tls,
            nvr_track_suffix=integer("NVR_TRACK_SUFFIX", 1, minimum=0, maximum=99),
            nvr_search_path=_path(optional("NVR_SEARCH_PATH", "/ISAPI/ContentMgmt/search")),
            nvr_download_path=_path(optional("NVR_DOWNLOAD_PATH", "/ISAPI/ContentMgmt/download")),
            nvr_connect_timeout_seconds=integer("NVR_CONNECT_TIMEOUT_SECONDS", 15, minimum=1, maximum=120),
            nvr_read_timeout_seconds=integer("NVR_READ_TIMEOUT_SECONDS", 300, minimum=10, maximum=1_800),
            max_download_bytes=integer("MAX_DOWNLOAD_BYTES", 500_000_000, minimum=1_000_000),
            max_output_bytes=integer("MAX_OUTPUT_BYTES", 250_000_000, minimum=1_000_000),
            max_clip_seconds=integer("MAX_CLIP_SECONDS", 60, minimum=1, maximum=600),
            ffmpeg_timeout_seconds=integer("FFMPEG_TIMEOUT_SECONDS", 600, minimum=30, maximum=1_800),
            signed_url_ttl_seconds=signed_url_ttl,
            signed_url_service_account_email=_optional_secret(
                values.get("SIGNED_URL_SERVICE_ACCOUNT_EMAIL"),
            ),
            processing_lease_seconds=lease,
            max_processing_attempts=integer("MAX_PROCESSING_ATTEMPTS", 5, minimum=1, maximum=20),
            require_cloud_tasks_header=_boolean(values, "REQUIRE_CLOUD_TASKS_HEADER", True),
            mail_service_bearer_token=_optional_secret(values.get("MAIL_SERVICE_BEARER_TOKEN")),
            mail_service_timeout_seconds=integer("MAIL_SERVICE_TIMEOUT_SECONDS", 30, minimum=3, maximum=300),
            project_id=_optional_secret(values.get("GOOGLE_CLOUD_PROJECT"))
            or _optional_secret(values.get("GCP_PROJECT")),
        )

    def camera_for_court(self, court_number: int) -> CourtCamera:
        for camera in self.court_cameras:
            if camera.court_number == court_number:
                return camera
        raise ConfigurationError(f"No camera is configured for court {court_number}")


def _optional_secret(value: str | None) -> str | None:
    if value is None:
        return None
    result = value.strip()
    return result or None


def _boolean(values: Mapping[str, str], name: str, default: bool) -> bool:
    raw = values.get(name)
    if raw is None or not str(raw).strip():
        return default
    normalized = str(raw).strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ConfigurationError(f"{name} must be true or false")


def _path(value: str) -> str:
    if not value.startswith("/") or "?" in value or "#" in value:
        raise ConfigurationError("NVR ISAPI paths must be absolute paths without query strings")
    return value


def _parse_court_cameras(raw: str) -> tuple[CourtCamera, ...]:
    if not raw:
        return DEFAULT_COURTS

    cameras: list[CourtCamera] = []
    seen_courts: set[int] = set()
    seen_channels: set[int] = set()
    for item in raw.split(","):
        fields = [field.strip() for field in item.split(":", 2)]
        if len(fields) not in {2, 3}:
            raise ConfigurationError(
                "COURT_CAMERA_MAP items must be court:channel or court:channel:label",
            )
        try:
            court_number = int(fields[0])
            channel = int(fields[1])
        except ValueError as error:
            raise ConfigurationError("COURT_CAMERA_MAP court and channel values must be integers") from error
        if court_number < 1 or channel < 1:
            raise ConfigurationError("COURT_CAMERA_MAP values must be positive")
        if court_number in seen_courts or channel in seen_channels:
            raise ConfigurationError("COURT_CAMERA_MAP courts and channels must be unique")
        label = fields[2] if len(fields) == 3 and fields[2] else f"Court {court_number}"
        cameras.append(CourtCamera(court_number, channel, label))
        seen_courts.add(court_number)
        seen_channels.add(channel)

    if not cameras:
        raise ConfigurationError("COURT_CAMERA_MAP must configure at least one court")
    return tuple(cameras)
