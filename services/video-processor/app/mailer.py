"""Adapter for the existing mail service's POST {to, subject, html} contract."""

from __future__ import annotations

from datetime import datetime
from html import escape

import requests

from .config import Settings
from .errors import MailConfigurationError, MailDeliveryError


class MailServiceClient:
    def __init__(self, settings: Settings, session: requests.Session | None = None) -> None:
        self._settings = settings
        self._session = session or requests.Session()

    def send_clip_link(
        self,
        *,
        recipient: str,
        request_id: str,
        court_number: int,
        court_label: str,
        clip_end: datetime,
        download_url: str,
    ) -> None:
        subject, html = build_video_email(
            court_number=court_number,
            court_label=court_label,
            clip_end=clip_end.astimezone(self._settings.nvr_time_zone),
            download_url=download_url,
        )
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json",
            # The existing service may ignore this today. It should persist this
            # key before a production retry can be exactly-once across a crash.
            "X-Idempotency-Key": f"video-{request_id}-{_recipient_hash(recipient)}",
        }
        if self._settings.mail_service_bearer_token:
            headers["Authorization"] = f"Bearer {self._settings.mail_service_bearer_token}"
        try:
            response = self._session.post(
                self._settings.mail_service_url,
                json={"to": recipient, "subject": subject, "html": html},
                headers=headers,
                timeout=self._settings.mail_service_timeout_seconds,
            )
        except (requests.Timeout, requests.ConnectionError) as error:
            raise MailDeliveryError("The mail service could not be reached.") from error
        except requests.RequestException as error:
            raise MailDeliveryError("The mail service request could not be completed.") from error

        status_code = response.status_code
        response.close()
        if 200 <= status_code < 300:
            return
        if status_code in {408, 429} or status_code >= 500:
            raise MailDeliveryError("The mail service is temporarily unavailable.")
        if status_code in {401, 403}:
            raise MailConfigurationError("The mail service rejected the configured credentials.")
        raise MailConfigurationError(f"The mail service rejected the video message (HTTP {status_code}).")


def build_video_email(
    *,
    court_number: int,
    court_label: str,
    clip_end: datetime,
    download_url: str,
) -> tuple[str, str]:
    """Return a compact RTL email without leaking recipients or internal metadata."""

    date_label = clip_end.strftime("%d-%m-%Y")
    time_label = clip_end.strftime("%H:%M")
    subject = f"סרטון מגרש {court_number} - {date_label} {time_label}"
    safe_url = escape(download_url, quote=True)
    safe_court = escape(str(court_number))
    safe_label = escape(court_label)
    html = f"""<!doctype html>
<html dir="rtl" lang="he">
  <body style="font-family:Arial,sans-serif;direction:rtl;color:#222;line-height:1.55">
    <p>שלום,</p>
    <p>הסרטון המבוקש ממגרש {safe_court} ({safe_label}) מיום {date_label} בשעה {time_label} מוכן.</p>
    <p><a href="{safe_url}">להורדת הסרטון</a></p>
    <p style="font-size:13px;color:#666">הקישור אישי, מוגבל בזמן, ואין להעבירו לאחרים.</p>
    <p>מועדון טניס כרמל</p>
  </body>
</html>"""
    return subject, html


def _recipient_hash(recipient: str) -> str:
    # A deterministic but non-email-bearing suffix makes a short idempotency key.
    import hashlib

    return hashlib.sha256(recipient.encode("utf-8")).hexdigest()[:24]
