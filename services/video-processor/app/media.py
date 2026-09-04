"""Bounded FFmpeg conversion to a browser-compatible MP4."""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Protocol, Sequence

from .config import Settings
from .errors import MediaProcessingError
from .hikvision import RecordingDownload


OUTPUT_DURATION_TOLERANCE_SECONDS = 0.5


@dataclass(frozen=True)
class ProcessedClip:
    path: Path
    bytes_written: int
    duration_seconds: float


class CommandRunner(Protocol):
    def run(self, args: Sequence[str], *, timeout: int) -> subprocess.CompletedProcess[str]: ...


class SubprocessCommandRunner:
    def run(self, args: Sequence[str], *, timeout: int) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(
                list(args),
                check=False,
                capture_output=True,
                text=True,
                timeout=timeout,
            )
        except FileNotFoundError as error:
            raise MediaProcessingError("FFmpeg is not installed in the video processor image.") from error
        except subprocess.TimeoutExpired as error:
            raise MediaProcessingError("FFmpeg exceeded the configured processing timeout.") from error


class MediaProcessor:
    def __init__(
        self,
        settings: Settings,
        *,
        runner: CommandRunner | None = None,
        ffmpeg_binary: str = "ffmpeg",
        ffprobe_binary: str = "ffprobe",
    ) -> None:
        self._settings = settings
        self._runner = runner or SubprocessCommandRunner()
        self._ffmpeg_binary = ffmpeg_binary
        self._ffprobe_binary = ffprobe_binary

    def transcode_browser_mp4(
        self,
        recording: RecordingDownload,
        *,
        clip_start: datetime,
        clip_end: datetime,
        destination: Path,
    ) -> ProcessedClip:
        if not recording.path.is_file():
            raise MediaProcessingError("The NVR download file is missing.")
        duration_seconds = (clip_end - clip_start).total_seconds()
        if duration_seconds <= 0 or duration_seconds > self._settings.max_clip_seconds:
            raise MediaProcessingError("The requested clip duration is outside the allowed limit.")
        start_offset = _start_offset_seconds(recording.segment_start, clip_start)
        destination.parent.mkdir(parents=True, exist_ok=True)

        command = self.ffmpeg_command(
            source=recording.path,
            destination=destination,
            start_offset_seconds=start_offset,
            duration_seconds=duration_seconds,
        )
        result = self._runner.run(command, timeout=self._settings.ffmpeg_timeout_seconds)
        if result.returncode != 0:
            raise MediaProcessingError("FFmpeg could not convert the NVR recording to MP4.")
        if not destination.is_file():
            raise MediaProcessingError("FFmpeg did not create an MP4 output file.")
        bytes_written = destination.stat().st_size
        if bytes_written <= 0:
            raise MediaProcessingError("FFmpeg produced an empty MP4 output file.")
        if bytes_written > self._settings.max_output_bytes:
            raise MediaProcessingError("The converted MP4 exceeded the configured size limit.")

        actual_duration = self._probe_duration(destination)
        if actual_duration <= 0:
            raise MediaProcessingError("The converted MP4 has no playable duration.")
        if abs(actual_duration - duration_seconds) > OUTPUT_DURATION_TOLERANCE_SECONDS:
            raise MediaProcessingError(
                "The converted MP4 duration does not match the requested interval.",
            )
        return ProcessedClip(destination, bytes_written, actual_duration)

    def ffmpeg_command(
        self,
        *,
        source: Path,
        destination: Path,
        start_offset_seconds: float,
        duration_seconds: float,
    ) -> list[str]:
        """Return a shell-free command: H.264/AAC, yuv420p and faststart play broadly."""

        return [
            self._ffmpeg_binary,
            "-hide_banner",
            "-loglevel",
            "error",
            "-nostdin",
            "-y",
            "-ss",
            f"{max(start_offset_seconds, 0):.3f}",
            "-i",
            str(source),
            "-t",
            f"{duration_seconds:.3f}",
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

    def _probe_duration(self, path: Path) -> float:
        result = self._runner.run(
            [
                self._ffprobe_binary,
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "json",
                str(path),
            ],
            timeout=min(60, self._settings.ffmpeg_timeout_seconds),
        )
        if result.returncode != 0:
            raise MediaProcessingError("FFprobe could not validate the MP4 output.")
        try:
            payload = json.loads(result.stdout)
            duration = float(payload["format"]["duration"])
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as error:
            raise MediaProcessingError("FFprobe returned an invalid MP4 duration.") from error
        return duration


def _start_offset_seconds(segment_start: datetime | None, clip_start: datetime) -> float:
    if segment_start is None:
        # The playback URI from some firmware is already constrained to the
        # requested range. There is no trustworthy offset in that response.
        return 0.0
    return max(0.0, (clip_start - segment_start).total_seconds())
