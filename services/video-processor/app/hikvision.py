"""Small, firmware-tolerant Hikvision ISAPI playback/download adapter.

The NVR is never contacted by Flutter or an ESP32. This module is used only
inside the private Cloud Run worker with HTTP Digest credentials injected from
Secret Manager-backed environment variables.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable
from xml.sax.saxutils import escape

import requests
from requests.auth import HTTPDigestAuth

try:  # defusedxml is mandatory in the container; fallback keeps stdlib tests runnable.
    from defusedxml import ElementTree as ElementTree
except ImportError:  # pragma: no cover - Docker image installs defusedxml
    from xml.etree import ElementTree  # type: ignore[no-redef]

from .config import Settings
from .errors import (
    NvrAuthenticationError,
    NvrProtocolError,
    NvrUnavailableError,
    RecordingNotReadyError,
)


@dataclass(frozen=True)
class RecordingDownload:
    path: Path
    segment_start: datetime | None
    segment_end: datetime | None
    bytes_downloaded: int


@dataclass(frozen=True)
class PlaybackMatch:
    playback_uri: str
    segment_start: datetime | None
    segment_end: datetime | None


class HikvisionClient:
    """Searches a configured camera track then downloads the matching recording."""

    def __init__(self, settings: Settings, session: requests.Session | None = None) -> None:
        self._settings = settings
        self._session = session or requests.Session()
        # Do not unexpectedly forward NVR traffic through ambient proxy variables.
        self._session.trust_env = False
        self._auth = HTTPDigestAuth(settings.nvr_username, settings.nvr_password)

    def download_recording(
        self,
        *,
        camera_channel: int,
        clip_start: datetime,
        clip_end: datetime,
        destination: Path,
    ) -> RecordingDownload:
        if camera_channel < 1:
            raise NvrProtocolError("The requested NVR camera channel is invalid.")
        if clip_start.tzinfo is None or clip_end.tzinfo is None or clip_end <= clip_start:
            raise NvrProtocolError("The requested clip interval is invalid.")

        matches = self._search(camera_channel, clip_start, clip_end)
        selected = _select_playback_match(matches, clip_start, clip_end)
        if selected is None:
            # A task is intentionally enqueued a little after a button press.
            # A missing match can still mean the NVR has not finalized the file.
            raise RecordingNotReadyError("No finalized recording was found for this interval yet.")

        return self._download(selected, destination)

    def _search(
        self,
        camera_channel: int,
        clip_start: datetime,
        clip_end: datetime,
    ) -> list[PlaybackMatch]:
        track_id = f"{camera_channel}{self._settings.nvr_track_suffix:02d}"
        payload = _build_search_xml(
            track_id=track_id,
            start=_nvr_timestamp(clip_start, self._settings),
            end=_nvr_timestamp(clip_end, self._settings),
        )
        response = self._request(
            "POST",
            self._url(self._settings.nvr_search_path),
            data=payload.encode("utf-8"),
            headers={"Content-Type": "application/xml", "Accept": "application/xml"},
        )
        try:
            return _parse_search_result(response.content)
        except Exception as error:
            raise NvrProtocolError("The NVR returned an invalid recording-search response.") from error
        finally:
            response.close()

    def _download(self, match: PlaybackMatch, destination: Path) -> RecordingDownload:
        # `requests` percent-encodes the playback URI query parameter. Never log
        # it: some NVR firmware may include sensitive query data in that URI.
        response = self._request(
            "GET",
            self._url(self._settings.nvr_download_path),
            params={"playbackURI": match.playback_uri},
            stream=True,
            headers={"Accept": "video/*,application/octet-stream"},
        )
        destination.parent.mkdir(parents=True, exist_ok=True)
        written = 0
        try:
            content_type = response.headers.get("Content-Type", "").lower()
            if "xml" in content_type or "json" in content_type:
                raise NvrProtocolError("The NVR download endpoint returned an API response, not video.")
            with destination.open("wb") as output:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    written += len(chunk)
                    if written > self._settings.max_download_bytes:
                        raise NvrProtocolError("The NVR download exceeded the configured size limit.")
                    output.write(chunk)
        finally:
            response.close()

        if written == 0:
            raise RecordingNotReadyError("The NVR returned an empty recording.")
        return RecordingDownload(
            path=destination,
            segment_start=match.segment_start,
            segment_end=match.segment_end,
            bytes_downloaded=written,
        )

    def _request(self, method: str, url: str, **kwargs: object) -> requests.Response:
        try:
            response = self._session.request(
                method,
                url,
                auth=self._auth,
                verify=self._settings.nvr_verify_tls,
                timeout=(
                    self._settings.nvr_connect_timeout_seconds,
                    self._settings.nvr_read_timeout_seconds,
                ),
                **kwargs,
            )
        except (requests.Timeout, requests.ConnectionError) as error:
            raise NvrUnavailableError("The NVR could not be reached.") from error
        except requests.RequestException as error:
            raise NvrUnavailableError("The NVR request could not be completed.") from error

        if 200 <= response.status_code < 300:
            return response
        status_code = response.status_code
        response.close()
        if status_code in {401, 403}:
            raise NvrAuthenticationError("The NVR rejected the configured credentials.")
        if status_code >= 500 or status_code in {408, 429}:
            raise NvrUnavailableError("The NVR is temporarily unavailable.")
        raise NvrProtocolError(f"The NVR rejected the recording request (HTTP {status_code}).")

    def _url(self, path: str) -> str:
        return f"{self._settings.nvr_base_url}{path}"


def _build_search_xml(*, track_id: str, start: str, end: str) -> str:
    """Build the CMSearchDescription accepted by current DS-76xx ISAPI firmware."""

    return f"""<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<CMSearchDescription>
  <searchID>carmel-tennis-video-request</searchID>
  <trackList><trackID>{escape(track_id)}</trackID></trackList>
  <timeSpanList>
    <timeSpan>
      <startTime>{escape(start)}</startTime>
      <endTime>{escape(end)}</endTime>
    </timeSpan>
  </timeSpanList>
  <maxResults>40</maxResults>
  <searchResultPostion>0</searchResultPostion>
  <metadataList><metadataDescriptor>//recordType.meta.std-cgi</metadataDescriptor></metadataList>
</CMSearchDescription>"""


def _nvr_timestamp(value: datetime, settings: Settings) -> str:
    if value.tzinfo is None:
        raise NvrProtocolError("NVR timestamps must be timezone-aware.")
    return value.astimezone(settings.nvr_time_zone).isoformat(timespec="seconds")


def _parse_search_result(xml_payload: bytes) -> list[PlaybackMatch]:
    root = ElementTree.fromstring(xml_payload)
    matches: list[PlaybackMatch] = []
    for item in _elements_named(root, "searchMatchItem"):
        descriptor = _first_child(item, "mediaSegmentDescriptor")
        source = descriptor if descriptor is not None else item
        playback_uri = _descendant_text(source, "playbackURI")
        if not playback_uri:
            continue
        matches.append(
            PlaybackMatch(
                playback_uri=playback_uri,
                segment_start=_parse_datetime(_descendant_text(source, "startTime")),
                segment_end=_parse_datetime(_descendant_text(source, "endTime")),
            ),
        )

    # Some Hikvision firmware omits searchMatchItem and returns bare
    # mediaSegmentDescriptor entries. Support it without relying on namespaces.
    if not matches:
        for descriptor in _elements_named(root, "mediaSegmentDescriptor"):
            playback_uri = _descendant_text(descriptor, "playbackURI")
            if playback_uri:
                matches.append(
                    PlaybackMatch(
                        playback_uri=playback_uri,
                        segment_start=_parse_datetime(_descendant_text(descriptor, "startTime")),
                        segment_end=_parse_datetime(_descendant_text(descriptor, "endTime")),
                    ),
                )
    return matches


def _select_playback_match(
    matches: Iterable[PlaybackMatch],
    clip_start: datetime,
    clip_end: datetime,
) -> PlaybackMatch | None:
    candidates = list(matches)
    if not candidates:
        return None
    for candidate in candidates:
        if candidate.segment_start is None or candidate.segment_end is None:
            continue
        if candidate.segment_start <= clip_start and candidate.segment_end >= clip_end:
            return candidate
    for candidate in candidates:
        if candidate.segment_start is None or candidate.segment_end is None:
            continue
        if candidate.segment_start < clip_end and candidate.segment_end > clip_start:
            return candidate
    # A playback URI returned for the exact requested range is generally already
    # trimmed by the NVR. Use it when the firmware did not include segment bounds.
    return next((candidate for candidate in candidates if candidate.segment_start is None), None)


def _elements_named(parent: object, name: str) -> Iterable[object]:
    return (element for element in parent.iter() if _local_name(element.tag) == name)  # type: ignore[attr-defined]


def _first_child(parent: object, name: str) -> object | None:
    return next((element for element in list(parent) if _local_name(element.tag) == name), None)  # type: ignore[arg-type,attr-defined]


def _child_text(parent: object, name: str) -> str | None:
    child = _first_child(parent, name)
    if child is None:
        return None
    text = getattr(child, "text", None)
    return text.strip() if isinstance(text, str) and text.strip() else None


def _descendant_text(parent: object, name: str) -> str | None:
    for element in _elements_named(parent, name):
        text = getattr(element, "text", None)
        if isinstance(text, str) and text.strip():
            return text.strip()
    return None


def _local_name(tag: object) -> str:
    return str(tag).rsplit("}", 1)[-1]


def _parse_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None
