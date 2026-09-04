from __future__ import annotations

import subprocess
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

from app.errors import MediaProcessingError
from app.hikvision import RecordingDownload
from app.media import MediaProcessor

from tests.support import settings


class FakeRunner:
    def __init__(self, *, probed_duration: float = 10.0) -> None:
        self.probed_duration = probed_duration
        self.commands: list[list[str]] = []

    def run(self, args: list[str], *, timeout: int) -> subprocess.CompletedProcess[str]:
        self.commands.append(list(args))
        if args[0] == "ffmpeg":
            Path(args[-1]).write_bytes(b"browser-compatible-mp4")
            return subprocess.CompletedProcess(args, 0, "", "")
        payload = f'{{"format":{{"duration":"{self.probed_duration}"}}}}'
        return subprocess.CompletedProcess(args, 0, payload, "")


class MediaProcessorTest(unittest.TestCase):
    def test_transcodes_with_browser_compatible_settings(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "recording.bin"
            source.write_bytes(b"nvr-recording")
            runner = FakeRunner(probed_duration=10.2)
            result = MediaProcessor(settings(), runner=runner).transcode_browser_mp4(
                RecordingDownload(
                    source,
                    datetime(2026, 8, 4, 9, 0, tzinfo=UTC),
                    datetime(2026, 8, 4, 9, 1, tzinfo=UTC),
                    source.stat().st_size,
                ),
                clip_start=datetime(2026, 8, 4, 9, 0, 5, tzinfo=UTC),
                clip_end=datetime(2026, 8, 4, 9, 0, 15, tzinfo=UTC),
                destination=root / "clip.mp4",
            )

            self.assertAlmostEqual(result.duration_seconds, 10.0, delta=0.3)
            ffmpeg_command = runner.commands[0]
            self.assertEqual(ffmpeg_command[ffmpeg_command.index("-ss") + 1], "5.000")
            self.assertEqual(ffmpeg_command[ffmpeg_command.index("-t") + 1], "10.000")
            command = MediaProcessor(settings()).ffmpeg_command(
                source=source,
                destination=root / "another.mp4",
                start_offset_seconds=5,
                duration_seconds=10,
            )
            self.assertIn("libx264", command)
            self.assertIn("yuv420p", command)
            self.assertIn("+faststart", command)

    def test_transcodes_an_exact_forty_second_button_clip(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "recording.bin"
            source.write_bytes(b"nvr-recording")
            runner = FakeRunner(probed_duration=40.2)
            result = MediaProcessor(settings(), runner=runner).transcode_browser_mp4(
                RecordingDownload(
                    source,
                    datetime(2026, 8, 4, 9, 0, tzinfo=UTC),
                    datetime(2026, 8, 4, 9, 1, tzinfo=UTC),
                    source.stat().st_size,
                ),
                clip_start=datetime(2026, 8, 4, 9, 0, 5, tzinfo=UTC),
                clip_end=datetime(2026, 8, 4, 9, 0, 45, tzinfo=UTC),
                destination=root / "clip-40.mp4",
            )

            self.assertAlmostEqual(result.duration_seconds, 40.0, delta=0.3)
            ffmpeg_command = runner.commands[0]
            self.assertEqual(ffmpeg_command[ffmpeg_command.index("-ss") + 1], "5.000")
            self.assertEqual(ffmpeg_command[ffmpeg_command.index("-t") + 1], "40.000")

    def test_rejects_an_output_whose_duration_does_not_match_request(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "recording.bin"
            source.write_bytes(b"nvr-recording")

            with self.assertRaisesRegex(MediaProcessingError, "duration"):
                MediaProcessor(
                    settings(),
                    runner=FakeRunner(probed_duration=11.0),
                ).transcode_browser_mp4(
                    RecordingDownload(
                        source,
                        datetime(2026, 8, 4, 9, 0, tzinfo=UTC),
                        datetime(2026, 8, 4, 9, 1, tzinfo=UTC),
                        source.stat().st_size,
                    ),
                    clip_start=datetime(2026, 8, 4, 9, 0, 5, tzinfo=UTC),
                    clip_end=datetime(2026, 8, 4, 9, 0, 15, tzinfo=UTC),
                    destination=root / "clip.mp4",
                )


if __name__ == "__main__":
    unittest.main()
