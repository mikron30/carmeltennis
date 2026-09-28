#!/usr/bin/env python3
"""Interactively download a tennis-court recording for one of my reservations.

The script:
1. Resolves the signed-in player name from Firestore users_2024 by email.
2. Lists only reservations where that player is userName or partner.
3. Lets the operator choose a reservation (date, hour, court).
4. Maps the court to the configured Hikvision NVR camera channel.
5. Searches Hikvision ISAPI recording segments, downloads them, and joins the
   requested reservation hour into one MP4.

The user's email is remembered locally after the first run. Firebase and NVR
passwords are requested interactively and are never written to disk.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Iterable
from urllib.parse import urlparse
from uuid import uuid4
from xml.etree import ElementTree
from xml.sax.saxutils import escape
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import requests
from requests.auth import HTTPDigestAuth


DEFAULT_PROJECT_ID = "potent-howl-228108"
DEFAULT_FIREBASE_API_KEY = "AIzaSyBRFzwULCldAPvEoCl9Oe7pbSZ2P9VIUeo"
DEFAULT_USERS_COLLECTION = "users_2024"
DEFAULT_RESERVATIONS_COLLECTION = "reservations"
DEFAULT_TIME_ZONE = "Asia/Jerusalem"
DEFAULT_COURT_CAMERA_MAP = "1:4:Left Court,2:6:Right Court,3:7:Back Court"
DEFAULT_TRACK_SUFFIX = 1
DEFAULT_SEARCH_PATH = "/ISAPI/ContentMgmt/search"
DEFAULT_DOWNLOAD_PATH = "/ISAPI/ContentMgmt/download"
EMAIL_FIELD = "מייל"
FIRST_NAME_FIELD = "שם פרטי"
LAST_NAME_FIELD = "שם משפחה"


@dataclass(frozen=True)
class ReservationChoice:
    date: str
    hour: int
    court_number: int
    user_name: str
    partner: str

    @property
    def opponent_or_partner(self) -> str:
        return self.partner


@dataclass(frozen=True)
class Camera:
    court_number: int
    channel: int
    label: str


@dataclass(frozen=True)
class PlaybackMatch:
    playback_uri: str
    segment_start: datetime | None
    segment_end: datetime | None


def normalize_text(value: object) -> str:
    return " ".join(str(value or "").strip().split())


def normalize_name(value: object) -> str:
    return normalize_text(value).casefold()


def normalize_email(value: object) -> str:
    return str(value or "").strip().casefold()


def parse_bool(value: object, default: bool = False) -> bool:
    if value is None or not str(value).strip():
        return default
    normalized = str(value).strip().lower()
    if normalized in {"1", "true", "yes", "on"}:
        return True
    if normalized in {"0", "false", "no", "off"}:
        return False
    raise ValueError(f"Expected true/false value, got: {value}")


def parse_verify_tls(value: str | None) -> bool | str:
    raw = str(value or "true").strip()
    if raw.lower() == "true":
        return True
    if raw.lower() == "false":
        return False
    return raw


def resolve_time_zone(value: str) -> ZoneInfo:
    raw = str(value or "").strip()
    aliases = {
        "israel standard time": DEFAULT_TIME_ZONE,
        "jerusalem standard time": DEFAULT_TIME_ZONE,
        "jerusalem": DEFAULT_TIME_ZONE,
        "israel": DEFAULT_TIME_ZONE,
        "asia/tel_aviv": DEFAULT_TIME_ZONE,
    }
    normalized = aliases.get(raw.casefold(), raw or DEFAULT_TIME_ZONE)
    try:
        return ZoneInfo(normalized)
    except ZoneInfoNotFoundError as error:
        raise RuntimeError(
            f'Cannot load time zone "{raw or DEFAULT_TIME_ZONE}". '
            'On Windows run: py -m pip install tzdata '
            'and use NVR_TIME_ZONE=Asia/Jerusalem.'
        ) from error


CONFIG_PATH = Path.home() / ".carmeltennis_video.json"


def load_local_config() -> dict[str, str]:
    try:
        if CONFIG_PATH.is_file():
            payload = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                return {
                    str(key): str(value)
                    for key, value in payload.items()
                    if value is not None
                }
    except (OSError, json.JSONDecodeError):
        pass
    return {}


def save_local_email(email: str) -> None:
    normalized = email.strip()
    if not normalized:
        return
    config = load_local_config()
    if config.get("email") == normalized:
        return
    config["email"] = normalized
    try:
        CONFIG_PATH.write_text(
            json.dumps(config, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    except OSError as error:
        print(f"Warning: could not save email in {CONFIG_PATH}: {error}")


def git_config_email() -> str:
    try:
        result = subprocess.run(
            ["git", "config", "user.email"],
            check=False,
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip() if result.returncode == 0 else ""


def resolve_email(cli_email: str | None) -> str:
    if cli_email and cli_email.strip():
        email = cli_email.strip()
        save_local_email(email)
        return email

    env_email = os.getenv("TENNIS_USER_EMAIL", "").strip()
    if env_email:
        save_local_email(env_email)
        return env_email

    saved_email = load_local_config().get("email", "").strip()
    if saved_email:
        print(f"Using saved Carmel Tennis email: {saved_email}")
        return saved_email

    candidate = git_config_email()
    if candidate:
        print(f"Using Git email for Carmel Tennis: {candidate}")
        save_local_email(candidate)
        return candidate

    email = input("Carmel Tennis account email: ").strip()
    if email:
        save_local_email(email)
    return email


def _firestore_value(value: dict) -> object:
    if "stringValue" in value:
        return value["stringValue"]
    if "integerValue" in value:
        return int(value["integerValue"])
    if "doubleValue" in value:
        return float(value["doubleValue"])
    if "booleanValue" in value:
        return bool(value["booleanValue"])
    if "timestampValue" in value:
        return value["timestampValue"]
    if "nullValue" in value:
        return None
    return None


def _document_fields(document: dict) -> dict[str, object]:
    return {
        field_name: _firestore_value(field_value)
        for field_name, field_value in (document.get("fields") or {}).items()
    }


class FirebaseUserClient:
    """Firebase Auth + Firestore REST client using the same user account as the app."""

    def __init__(
        self,
        *,
        project_id: str,
        api_key: str,
        email: str,
        password: str,
    ) -> None:
        self.project_id = project_id
        self.api_key = api_key
        self.email = email
        self.session = requests.Session()
        self.session.trust_env = False
        self.id_token = self._sign_in(password)

    @property
    def _documents_base(self) -> str:
        return (
            f"https://firestore.googleapis.com/v1/projects/{self.project_id}"
            "/databases/(default)/documents"
        )

    def _sign_in(self, password: str) -> str:
        if not password:
            raise ValueError("Firebase password is required.")
        response = self.session.post(
            "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword",
            params={"key": self.api_key},
            json={
                "email": self.email,
                "password": password,
                "returnSecureToken": True,
            },
            timeout=30,
        )
        try:
            payload = response.json()
        except ValueError:
            payload = {}
        if response.status_code >= 400:
            code = (
                payload.get("error", {}).get("message")
                if isinstance(payload, dict)
                else None
            ) or f"HTTP {response.status_code}"
            friendly = {
                "INVALID_LOGIN_CREDENTIALS": "email or password is incorrect",
                "EMAIL_NOT_FOUND": "email was not found in Firebase Authentication",
                "INVALID_PASSWORD": "password is incorrect",
                "USER_DISABLED": "this Firebase account is disabled",
                "TOO_MANY_ATTEMPTS_TRY_LATER": "too many login attempts; try again later",
            }.get(code, code)
            raise RuntimeError(f"Firebase login failed: {friendly}")
        token = payload.get("idToken") if isinstance(payload, dict) else None
        if not token:
            raise RuntimeError("Firebase login did not return an ID token.")
        return str(token)

    def _headers(self) -> dict[str, str]:
        return {"Authorization": f"Bearer {self.id_token}"}

    def run_query(self, collection: str, where: dict, *, order_by: list[dict] | None = None) -> list[dict]:
        structured_query: dict[str, object] = {
            "from": [{"collectionId": collection}],
            "where": where,
        }
        if order_by:
            structured_query["orderBy"] = order_by

        response = self.session.post(
            f"{self._documents_base}:runQuery",
            headers=self._headers(),
            json={"structuredQuery": structured_query},
            timeout=60,
        )
        if response.status_code >= 400:
            try:
                detail = response.json().get("error", {}).get("message")
            except ValueError:
                detail = None
            raise RuntimeError(
                "Firestore query failed"
                + (f": {detail}" if detail else f" (HTTP {response.status_code})")
            )

        rows = response.json()
        return [
            _document_fields(row["document"])
            for row in rows
            if isinstance(row, dict) and "document" in row
        ]

    def list_collection(self, collection: str) -> list[dict]:
        documents: list[dict] = []
        page_token = ""
        while True:
            params = {"pageSize": "1000"}
            if page_token:
                params["pageToken"] = page_token
            response = self.session.get(
                f"{self._documents_base}/{collection}",
                headers=self._headers(),
                params=params,
                timeout=60,
            )
            if response.status_code >= 400:
                try:
                    detail = response.json().get("error", {}).get("message")
                except ValueError:
                    detail = None
                raise RuntimeError(
                    "Firestore read failed"
                    + (f": {detail}" if detail else f" (HTTP {response.status_code})")
                )
            payload = response.json()
            documents.extend(
                _document_fields(document)
                for document in payload.get("documents", [])
            )
            page_token = str(payload.get("nextPageToken", "") or "")
            if not page_token:
                return documents


def _field_filter(field_path: str, op: str, value: dict) -> dict:
    return {
        "fieldFilter": {
            "field": {"fieldPath": field_path},
            "op": op,
            "value": value,
        }
    }


def resolve_player_name(
    db: FirebaseUserClient,
    email: str,
    users_collection: str,
) -> str:
    normalized_target = normalize_email(email)
    if not normalized_target:
        raise ValueError("Email cannot be empty.")

    documents = db.run_query(
        users_collection,
        _field_filter(EMAIL_FIELD, "EQUAL", {"stringValue": email.strip()}),
    )

    if not documents:
        documents = [
            data
            for data in db.list_collection(users_collection)
            if normalize_email(data.get(EMAIL_FIELD)) == normalized_target
        ]

    if not documents:
        raise LookupError(f"No user in {users_collection} matches {email}.")
    if len(documents) > 1:
        raise LookupError(f"More than one user in {users_collection} matches {email}.")

    data = documents[0]
    first_name = normalize_text(data.get(FIRST_NAME_FIELD))
    last_name = normalize_text(data.get(LAST_NAME_FIELD))
    full_name = normalize_text(f"{first_name} {last_name}")
    if not full_name:
        raise LookupError("The matching user does not contain a first/last name.")
    return full_name


def load_my_reservations(
    db: FirebaseUserClient,
    *,
    player_name: str,
    collection: str,
    start_date: str,
    end_date: str,
) -> list[ReservationChoice]:
    documents = db.run_query(
        collection,
        {
            "compositeFilter": {
                "op": "AND",
                "filters": [
                    _field_filter(
                        "date",
                        "GREATER_THAN_OR_EQUAL",
                        {"stringValue": start_date},
                    ),
                    _field_filter(
                        "date",
                        "LESS_THAN_OR_EQUAL",
                        {"stringValue": end_date},
                    ),
                ],
            }
        },
        order_by=[
            {
                "field": {"fieldPath": "date"},
                "direction": "DESCENDING",
            }
        ],
    )

    target = normalize_name(player_name)
    choices: dict[tuple[str, int, int, str, str], ReservationChoice] = {}

    for data in documents:
        if data.get("isReserved") is False:
            continue

        user_name = normalize_text(data.get("userName"))
        partner = normalize_text(data.get("partner"))
        if target not in {normalize_name(user_name), normalize_name(partner)}:
            continue

        try:
            hour = int(data.get("hour"))
            court_number = int(data.get("courtNumber"))
        except (TypeError, ValueError):
            continue

        date_value = normalize_text(data.get("date"))
        if not date_value or not (0 <= hour <= 23) or court_number < 1:
            continue

        choice = ReservationChoice(
            date=date_value,
            hour=hour,
            court_number=court_number,
            user_name=user_name,
            partner=partner,
        )
        key = (date_value, hour, court_number, user_name, partner)
        choices[key] = choice

    return sorted(
        choices.values(),
        key=lambda item: (item.date, item.hour, item.court_number),
        reverse=True,
    )

def choose_reservation(choices: list[ReservationChoice], player_name: str) -> ReservationChoice:
    if not choices:
        raise LookupError("No matching reservations were found in the selected date range.")

    print(f"\nReservations for {player_name}:")
    print("-" * 78)
    for index, choice in enumerate(choices, start=1):
        other = (
            choice.partner
            if normalize_name(choice.user_name) == normalize_name(player_name)
            else choice.user_name
        )
        print(
            f"{index:>2}. {choice.date}  "
            f"{choice.hour:02d}:00-{choice.hour + 1:02d}:00  "
            f"Court {choice.court_number}  with {other}"
        )
    print("-" * 78)

    while True:
        raw = input("Choose reservation number (or q to quit): ").strip()
        if raw.lower() in {"q", "quit", "exit"}:
            raise KeyboardInterrupt
        try:
            selected = int(raw)
        except ValueError:
            print("Please enter a number from the list.")
            continue
        if 1 <= selected <= len(choices):
            return choices[selected - 1]
        print("Selection is out of range.")


def parse_court_camera_map(raw: str) -> dict[int, Camera]:
    result: dict[int, Camera] = {}
    for item in raw.split(","):
        fields = [field.strip() for field in item.split(":", 2)]
        if len(fields) not in {2, 3}:
            raise ValueError(
                "COURT_CAMERA_MAP items must be court:channel or court:channel:label."
            )
        court_number = int(fields[0])
        channel = int(fields[1])
        label = fields[2] if len(fields) == 3 and fields[2] else f"Court {court_number}"
        result[court_number] = Camera(court_number, channel, label)
    return result


class HikvisionDownloader:
    def __init__(
        self,
        *,
        base_url: str,
        username: str,
        password: str,
        time_zone: ZoneInfo,
        track_suffix: int,
        search_path: str,
        download_path: str,
        verify_tls: bool | str,
        search_results_are_local_time: bool,
        max_download_bytes: int,
    ) -> None:
        self.base_url = base_url.rstrip("/")
        self.time_zone = time_zone
        self.track_suffix = track_suffix
        self.search_path = search_path
        self.download_path = download_path
        self.verify_tls = verify_tls
        self.search_results_are_local_time = search_results_are_local_time
        self.max_download_bytes = max_download_bytes
        self.session = requests.Session()
        self.session.trust_env = False
        self.auth = HTTPDigestAuth(username, password)

    def search(
        self,
        *,
        camera_channel: int,
        clip_start: datetime,
        clip_end: datetime,
    ) -> list[PlaybackMatch]:
        track_id = f"{camera_channel}{self.track_suffix:02d}"
        payload = build_search_xml(
            track_id=track_id,
            start=clip_start.astimezone(self.time_zone).isoformat(timespec="seconds"),
            end=clip_end.astimezone(self.time_zone).isoformat(timespec="seconds"),
        )
        response = self._request(
            "POST",
            self.base_url + self.search_path,
            data=payload.encode("utf-8"),
            headers={"Content-Type": "application/xml", "Accept": "application/xml"},
        )
        try:
            return parse_search_result(
                response.content,
                time_zone=self.time_zone,
                z_is_local=self.search_results_are_local_time,
            )
        finally:
            response.close()

    def download(self, match: PlaybackMatch, destination: Path) -> int:
        payload = build_download_xml(match.playback_uri)
        response = self._request(
            "GET",
            self.base_url + self.download_path,
            data=payload.encode("utf-8"),
            stream=True,
            headers={
                "Content-Type": "application/xml",
                "Accept": "video/*,application/octet-stream",
            },
        )
        destination.parent.mkdir(parents=True, exist_ok=True)
        written = 0
        next_progress = 100 * 1024 * 1024
        try:
            content_type = response.headers.get("Content-Type", "").lower()
            if "xml" in content_type or "json" in content_type:
                raise RuntimeError("NVR returned an API response instead of video.")

            with destination.open("wb") as output:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    output.write(chunk)
                    written += len(chunk)
                    if written > self.max_download_bytes:
                        raise RuntimeError(
                            "NVR download exceeded MAX_DOWNLOAD_BYTES; "
                            "increase the limit only if enough disk space is available."
                        )
                    if written >= next_progress:
                        print(f"  downloaded {written / (1024 * 1024):.0f} MB...")
                        next_progress += 100 * 1024 * 1024
        finally:
            response.close()

        if written == 0:
            raise RuntimeError("NVR returned an empty recording.")
        return written

    def _request(self, method: str, url: str, **kwargs) -> requests.Response:
        response = self.session.request(
            method,
            url,
            auth=self.auth,
            verify=self.verify_tls,
            timeout=(15, 900),
            **kwargs,
        )
        if 200 <= response.status_code < 300:
            return response
        status = response.status_code
        response.close()
        raise RuntimeError(f"Hikvision request failed with HTTP {status}.")


def build_search_xml(*, track_id: str, start: str, end: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<CMSearchDescription>
  <searchID>{uuid4()}</searchID>
  <trackList><trackID>{escape(track_id)}</trackID></trackList>
  <timeSpanList>
    <timeSpan>
      <startTime>{escape(start)}</startTime>
      <endTime>{escape(end)}</endTime>
    </timeSpan>
  </timeSpanList>
  <maxResults>100</maxResults>
  <searchResultPostion>0</searchResultPostion>
  <metadataList><metadataDescriptor>//recordType.meta.std-cgi</metadataDescriptor></metadataList>
</CMSearchDescription>"""


def build_download_xml(playback_uri: str) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<downloadRequest>
  <playbackURI>{escape(playback_uri)}</playbackURI>
</downloadRequest>"""


def local_name(tag: object) -> str:
    return str(tag).rsplit("}", 1)[-1]


def elements_named(parent: object, name: str) -> Iterable[object]:
    return (
        element
        for element in parent.iter()  # type: ignore[attr-defined]
        if local_name(element.tag) == name
    )


def descendant_text(parent: object, name: str) -> str | None:
    for element in elements_named(parent, name):
        text = getattr(element, "text", None)
        if isinstance(text, str) and text.strip():
            return text.strip()
    return None


def parse_nvr_datetime(
    value: str | None,
    *,
    time_zone: ZoneInfo,
    z_is_local: bool,
) -> datetime | None:
    if not value:
        return None
    try:
        if value.endswith("Z") and z_is_local:
            local = datetime.fromisoformat(value[:-1])
            return local.replace(tzinfo=time_zone)
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=time_zone)
        return parsed.astimezone(time_zone)
    except ValueError:
        return None


def parse_search_result(
    xml_payload: bytes,
    *,
    time_zone: ZoneInfo,
    z_is_local: bool,
) -> list[PlaybackMatch]:
    root = ElementTree.fromstring(xml_payload)
    matches: list[PlaybackMatch] = []

    items = list(elements_named(root, "searchMatchItem"))
    sources = items if items else list(elements_named(root, "mediaSegmentDescriptor"))
    for item in sources:
        playback_uri = descendant_text(item, "playbackURI")
        if not playback_uri:
            continue
        matches.append(
            PlaybackMatch(
                playback_uri=playback_uri,
                segment_start=parse_nvr_datetime(
                    descendant_text(item, "startTime"),
                    time_zone=time_zone,
                    z_is_local=z_is_local,
                ),
                segment_end=parse_nvr_datetime(
                    descendant_text(item, "endTime"),
                    time_zone=time_zone,
                    z_is_local=z_is_local,
                ),
            )
        )

    return matches


def select_overlapping_matches(
    matches: list[PlaybackMatch],
    clip_start: datetime,
    clip_end: datetime,
) -> list[PlaybackMatch]:
    bounded = [
        match
        for match in matches
        if match.segment_start is not None
        and match.segment_end is not None
        and match.segment_end > clip_start
        and match.segment_start < clip_end
    ]
    if bounded:
        bounded.sort(key=lambda match: match.segment_start or clip_start)
        return bounded

    unbounded = [
        match
        for match in matches
        if match.segment_start is None and match.segment_end is None
    ]
    return unbounded[:1]


def run_ffmpeg(args: list[str], timeout_seconds: int = 7200) -> None:
    try:
        result = subprocess.run(
            args,
            check=False,
            text=True,
            capture_output=True,
            timeout=timeout_seconds,
        )
    except FileNotFoundError as error:
        raise RuntimeError(
            "FFmpeg is not installed or is not in PATH."
        ) from error
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("FFmpeg processing timed out.") from error

    if result.returncode != 0:
        message = (result.stderr or result.stdout or "").strip()
        tail = message[-2000:] if message else "No FFmpeg error text was returned."
        raise RuntimeError(f"FFmpeg failed:\n{tail}")


def make_part_mp4(
    *,
    raw_path: Path,
    destination: Path,
    match: PlaybackMatch,
    clip_start: datetime,
    clip_end: datetime,
) -> None:
    if match.segment_start is None or match.segment_end is None:
        offset = 0.0
        duration = (clip_end - clip_start).total_seconds()
    else:
        part_start = max(match.segment_start, clip_start)
        part_end = min(match.segment_end, clip_end)
        offset = max(0.0, (part_start - match.segment_start).total_seconds())
        duration = (part_end - part_start).total_seconds()

    if duration <= 0:
        raise RuntimeError("Calculated video segment duration is invalid.")

    run_ffmpeg(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-y",
            "-ss",
            f"{offset:.3f}",
            "-i",
            str(raw_path),
            "-t",
            f"{duration:.3f}",
            "-map",
            "0:v:0",
            "-map",
            "0:a?",
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-crf",
            "23",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            "-movflags",
            "+faststart",
            str(destination),
        ]
    )

    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("FFmpeg did not create the expected MP4 part.")


def concat_parts(parts: list[Path], destination: Path) -> None:
    if not parts:
        raise RuntimeError("No MP4 parts were created.")
    destination.parent.mkdir(parents=True, exist_ok=True)

    if len(parts) == 1:
        shutil.move(str(parts[0]), str(destination))
        return

    list_path = parts[0].parent / "concat.txt"
    lines = []
    for part in parts:
        escaped_path = str(part.resolve()).replace("'", "'\\''")
        lines.append(f"file '{escaped_path}'")
    list_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    run_ffmpeg(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(list_path),
            "-c",
            "copy",
            "-movflags",
            "+faststart",
            str(destination),
        ]
    )

    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError("FFmpeg did not create the final MP4.")


def reservation_window(choice: ReservationChoice, time_zone: ZoneInfo) -> tuple[datetime, datetime]:
    day = datetime.strptime(choice.date, "%Y-%m-%d")
    start = day.replace(hour=choice.hour, minute=0, second=0, tzinfo=time_zone)
    return start, start + timedelta(hours=1)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Choose one of my tennis reservations and download its NVR video."
    )
    parser.add_argument("--email", help="Your Carmel Tennis account email.")
    parser.add_argument("--project-id", default=DEFAULT_PROJECT_ID)
    parser.add_argument(
        "--firebase-api-key",
        default=os.getenv("FIREBASE_API_KEY", DEFAULT_FIREBASE_API_KEY),
    )
    parser.add_argument("--users-collection", default=DEFAULT_USERS_COLLECTION)
    parser.add_argument("--reservations-collection", default=DEFAULT_RESERVATIONS_COLLECTION)
    parser.add_argument("--date", help="Limit choices to one date: YYYY-MM-DD.")
    parser.add_argument("--days-back", type=int, default=1)
    parser.add_argument("--days-forward", type=int, default=0)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("downloaded_tennis_videos"),
    )
    parser.add_argument("--nvr-url")
    parser.add_argument("--nvr-user")
    parser.add_argument("--nvr-password")
    parser.add_argument("--time-zone", default=os.getenv("NVR_TIME_ZONE", DEFAULT_TIME_ZONE))
    parser.add_argument(
        "--court-camera-map",
        default=os.getenv("COURT_CAMERA_MAP", DEFAULT_COURT_CAMERA_MAP),
    )
    parser.add_argument(
        "--track-suffix",
        type=int,
        default=int(os.getenv("NVR_TRACK_SUFFIX", str(DEFAULT_TRACK_SUFFIX))),
    )
    parser.add_argument(
        "--search-results-are-local-time",
        action="store_true",
        default=parse_bool(os.getenv("NVR_SEARCH_RESULTS_ARE_LOCAL_TIME"), False),
    )
    parser.add_argument(
        "--max-download-bytes",
        type=int,
        default=int(os.getenv("MAX_DOWNLOAD_BYTES", "4000000000")),
    )
    parser.add_argument(
        "--verify-tls",
        default=os.getenv("NVR_VERIFY_TLS", "true"),
        help="true, false, or path to a CA bundle.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.days_back < 0 or args.days_forward < 0:
        print("--days-back and --days-forward must be non-negative.", file=sys.stderr)
        return 2

    try:
        time_zone = resolve_time_zone(args.time_zone)
    except Exception as error:
        print(f"Time zone error: {error}", file=sys.stderr)
        return 2

    email = resolve_email(args.email)
    if not email:
        print("Email is required.", file=sys.stderr)
        return 2

    firebase_password = os.getenv("TENNIS_FIREBASE_PASSWORD", "")
    if not firebase_password:
        firebase_password = getpass.getpass("Carmel Tennis password: ")

    try:
        db = FirebaseUserClient(
            project_id=args.project_id,
            api_key=args.firebase_api_key,
            email=email,
            password=firebase_password,
        )
        player_name = resolve_player_name(db, email, args.users_collection)

        if args.date:
            datetime.strptime(args.date, "%Y-%m-%d")
            start_date = args.date
            end_date = args.date
        else:
            today = datetime.now(time_zone).date()
            start_date = (today - timedelta(days=args.days_back)).isoformat()
            end_date = (today + timedelta(days=args.days_forward)).isoformat()

        choices = load_my_reservations(
            db,
            player_name=player_name,
            collection=args.reservations_collection,
            start_date=start_date,
            end_date=end_date,
        )
        choice = choose_reservation(choices, player_name)
    except KeyboardInterrupt:
        print("\nCancelled.")
        return 130
    except Exception as error:
        print(f"Firebase/reservation lookup failed: {error}", file=sys.stderr)
        return 1

    cameras = parse_court_camera_map(args.court_camera_map)
    camera = cameras.get(choice.court_number)
    if camera is None:
        print(
            f"No camera mapping exists for court {choice.court_number}.",
            file=sys.stderr,
        )
        return 1

    nvr_url = args.nvr_url or os.getenv("NVR_BASE_URL") or input("NVR base URL: ").strip()
    nvr_user = args.nvr_user or os.getenv("NVR_USERNAME") or input("NVR username: ").strip()
    nvr_password = args.nvr_password or os.getenv("NVR_PASSWORD")
    if not nvr_password:
        nvr_password = getpass.getpass("NVR password: ")

    if not nvr_url or not nvr_user or not nvr_password:
        print("NVR URL, username and password are required.", file=sys.stderr)
        return 2

    parsed_url = urlparse(nvr_url)
    if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
        print("NVR URL must be an absolute http:// or https:// URL.", file=sys.stderr)
        return 2
    if parsed_url.scheme == "http":
        print("WARNING: NVR connection uses unencrypted HTTP.")

    clip_start, clip_end = reservation_window(choice, time_zone)
    output_name = (
        f"court_{choice.court_number}_{choice.date}_"
        f"{choice.hour:02d}00-{choice.hour + 1:02d}00.mp4"
    )
    destination = args.output_dir / output_name

    print(
        f"\nSelected: {choice.date}, {choice.hour:02d}:00-"
        f"{choice.hour + 1:02d}:00, court {choice.court_number}"
    )
    print(f"Camera: {camera.label}, NVR channel {camera.channel}")
    print(f"Output: {destination}")

    try:
        downloader = HikvisionDownloader(
            base_url=nvr_url,
            username=nvr_user,
            password=nvr_password,
            time_zone=time_zone,
            track_suffix=args.track_suffix,
            search_path=os.getenv("NVR_SEARCH_PATH", DEFAULT_SEARCH_PATH),
            download_path=os.getenv("NVR_DOWNLOAD_PATH", DEFAULT_DOWNLOAD_PATH),
            verify_tls=parse_verify_tls(args.verify_tls),
            search_results_are_local_time=args.search_results_are_local_time,
            max_download_bytes=args.max_download_bytes,
        )

        matches = downloader.search(
            camera_channel=camera.channel,
            clip_start=clip_start,
            clip_end=clip_end,
        )
        selected_matches = select_overlapping_matches(matches, clip_start, clip_end)
        if not selected_matches:
            raise LookupError("No NVR recording overlaps the selected reservation hour.")

        print(f"Found {len(selected_matches)} NVR recording segment(s).")

        with tempfile.TemporaryDirectory(prefix="tennis-video-") as temp:
            temp_dir = Path(temp)
            parts: list[Path] = []
            for index, match in enumerate(selected_matches, start=1):
                print(f"Downloading segment {index}/{len(selected_matches)}...")
                raw_path = temp_dir / f"segment_{index:02d}.raw"
                part_path = temp_dir / f"part_{index:02d}.mp4"
                downloader.download(match, raw_path)

                print(f"Converting segment {index}/{len(selected_matches)} to MP4...")
                make_part_mp4(
                    raw_path=raw_path,
                    destination=part_path,
                    match=match,
                    clip_start=clip_start,
                    clip_end=clip_end,
                )
                parts.append(part_path)

            print("Joining MP4 parts...")
            concat_parts(parts, destination)

    except KeyboardInterrupt:
        print("\nCancelled.")
        return 130
    except Exception as error:
        print(f"Video download failed: {error}", file=sys.stderr)
        return 1

    size_mb = destination.stat().st_size / (1024 * 1024)
    print(f"\nDone: {destination} ({size_mb:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
