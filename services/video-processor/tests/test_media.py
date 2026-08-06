from __future__ import annotations

import subprocess
import tempfile
import unittest
from datetime import UTC, datetime
from pathlib import Path

from app.hikvision import RecordingDownload
from app.media import MediaProcessor

from tests.support import settings


class FakeRunner:
    def run(self, args: list[str], *, timeout: int) -> subprocess.CompletedProcess[str]:
        if args[0] == "ffmpeg":
            Path(args[-1]).write_bytes(b"browser-compatible-mp4")
            return subprocess.CompletedProcess(args, 0, "", "")
        return subprocess.CompletedProcess(args, 0, '{"format":{"duration":"10.0"}}', "")


class MediaProcessorTest(unittest.TestCase):
    def test_transcodes_with_browser_compatible_settings(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "recording.bin"
            source.write_bytes(b"nvr-recording")
            result = MediaProcessor(settings(), runner=FakeRunner()).transcode_browser_mp4(
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

            self.assertEqual(result.duration_seconds, 10.0)
            command = MediaProcessor(settings()).ffmpeg_command(
                source=source,
                destination=root / "another.mp4",
                start_offset_seconds=5,
                duration_seconds=10,
            )
            self.assertIn("libx264", command)
            self.assertIn("yuv420p", command)
            self.assertIn("+faststart", command)


if __name__ == "__main__":
    unittest.main()
