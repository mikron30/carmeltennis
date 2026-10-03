#!/usr/bin/env python3
"""Combine each iVMS-4200 download directory into one MP4 file.

Defaults:
  Source:
    C:\Users\Public\iVMS-4200 Site\UserData\Video
  Destination:
    C:\Users\Roy\Documents\carmeltennis\downloaded_tennis_videos

For every immediate subdirectory under the source directory, the script:
1. Finds all playable video files inside that directory (recursively).
2. Sorts them naturally by filename/path.
3. Re-encodes each fragment to a normalized H.264/AAC MP4.
4. Concatenates the normalized fragments into one MP4.
5. Writes <directory-name>.mp4 to the destination directory.

Original iVMS files are never modified or deleted.

Requirements:
  ffmpeg and ffprobe must be installed and available in PATH.
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


DEFAULT_SOURCE = Path(r"C:\Users\Public\iVMS-4200 Site\UserData\Video")
DEFAULT_OUTPUT = Path(
    r"C:\Users\Roy\Documents\carmeltennis\downloaded_tennis_videos"
)

FFMPEG_TIMEOUT_SECONDS = 6 * 60 * 60


def natural_key(path: Path) -> list[object]:
    """Sort names like clip2 before clip10."""
    text = str(path).casefold()
    return [
        int(part) if part.isdigit() else part
        for part in re.split(r"(\d+)", text)
    ]


def sanitize_filename(name: str) -> str:
    """Make a Windows-safe output filename."""
    cleaned = re.sub(r'[<>:"/\\|?*]+', "_", name).strip().rstrip(". ")
    return cleaned or "combined_video"


def require_tool(name: str) -> str:
    resolved = shutil.which(name)
    if not resolved:
        raise RuntimeError(
            f"{name} was not found in PATH. Install FFmpeg and make sure "
            f"both ffmpeg.exe and ffprobe.exe are available."
        )
    return resolved


def run_command(
    args: list[str],
    *,
    timeout_seconds: int = FFMPEG_TIMEOUT_SECONDS,
) -> subprocess.CompletedProcess[str]:
    try:
        result = subprocess.run(
            args,
            check=False,
            text=True,
            capture_output=True,
            timeout=timeout_seconds,
        )
    except subprocess.TimeoutExpired as error:
        raise RuntimeError(f"Command timed out: {args[0]}") from error

    if result.returncode != 0:
        message = (result.stderr or result.stdout or "").strip()
        tail = message[-3000:] if message else "No error text was returned."
        raise RuntimeError(f"{args[0]} failed:\n{tail}")

    return result


def probe_streams(ffprobe: str, source: Path) -> tuple[bool, bool]:
    """Return (has_video, has_audio). Unreadable/non-video files return False."""
    try:
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "stream=codec_type",
                "-of",
                "json",
                str(source),
            ],
            check=False,
            text=True,
            capture_output=True,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False, False

    if result.returncode != 0:
        return False, False

    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return False, False

    stream_types = {
        str(stream.get("codec_type", "")).lower()
        for stream in payload.get("streams", [])
        if isinstance(stream, dict)
    }
    return "video" in stream_types, "audio" in stream_types


def collect_video_files(ffprobe: str, directory: Path) -> list[tuple[Path, bool]]:
    candidates = sorted(
        (path for path in directory.rglob("*") if path.is_file()),
        key=natural_key,
    )

    videos: list[tuple[Path, bool]] = []
    for path in candidates:
        has_video, has_audio = probe_streams(ffprobe, path)
        if has_video:
            videos.append((path, has_audio))
        else:
            print(f"    Skipping non-video/unreadable file: {path.name}")

    return videos


def normalize_fragment(
    ffmpeg: str,
    *,
    source: Path,
    destination: Path,
    has_audio: bool,
) -> None:
    """Convert one source fragment to a consistent H.264/AAC MP4."""
    common = [
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-nostdin",
        "-y",
        "-fflags",
        "+genpts",
        "-i",
        str(source),
    ]

    if has_audio:
        args = common + [
            "-map",
            "0:v:0",
            "-map",
            "0:a:0",
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
            "-ar",
            "48000",
            "-ac",
            "2",
            "-movflags",
            "+faststart",
            str(destination),
        ]
    else:
        # Add silent audio so every normalized part has the same stream layout.
        args = common + [
            "-f",
            "lavfi",
            "-i",
            "anullsrc=channel_layout=stereo:sample_rate=48000",
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
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
            "-ar",
            "48000",
            "-ac",
            "2",
            "-shortest",
            "-movflags",
            "+faststart",
            str(destination),
        ]

    run_command(args)

    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError(f"FFmpeg did not create {destination.name}")


def concat_parts(ffmpeg: str, parts: list[Path], destination: Path) -> None:
    if not parts:
        raise RuntimeError("No normalized MP4 parts were created.")

    destination.parent.mkdir(parents=True, exist_ok=True)

    if len(parts) == 1:
        shutil.copy2(parts[0], destination)
        return

    concat_file = parts[0].parent / "concat.txt"
    lines: list[str] = []

    for part in parts:
        # Forward slashes work well with FFmpeg's concat demuxer on Windows.
        path_text = part.resolve().as_posix().replace("'", "'\\''")
        lines.append(f"file '{path_text}'")

    concat_file.write_text("\n".join(lines) + "\n", encoding="utf-8")

    run_command(
        [
            ffmpeg,
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
            str(concat_file),
            "-c",
            "copy",
            "-movflags",
            "+faststart",
            str(destination),
        ]
    )

    if not destination.is_file() or destination.stat().st_size == 0:
        raise RuntimeError(f"FFmpeg did not create {destination.name}")


def combine_directory(
    ffmpeg: str,
    ffprobe: str,
    *,
    source_directory: Path,
    output_directory: Path,
    overwrite: bool,
) -> Path | None:
    output_name = sanitize_filename(source_directory.name) + ".mp4"
    destination = output_directory / output_name

    if destination.exists() and not overwrite:
        print(f"  SKIP: output already exists: {destination}")
        return destination

    videos = collect_video_files(ffprobe, source_directory)
    if not videos:
        print("  SKIP: no playable video files found.")
        return None

    print(f"  Found {len(videos)} video fragment(s).")

    with tempfile.TemporaryDirectory(prefix="ivms-combine-") as temp:
        temp_directory = Path(temp)
        parts: list[Path] = []

        for index, (source, has_audio) in enumerate(videos, start=1):
            part = temp_directory / f"part_{index:05d}.mp4"
            print(
                f"    [{index}/{len(videos)}] Converting: "
                f"{source.relative_to(source_directory)}"
            )
            normalize_fragment(
                ffmpeg,
                source=source,
                destination=part,
                has_audio=has_audio,
            )
            parts.append(part)

        print(f"  Joining {len(parts)} part(s)...")
        concat_parts(ffmpeg, parts, destination)

    size_mb = destination.stat().st_size / (1024 * 1024)
    print(f"  DONE: {destination} ({size_mb:.1f} MB)")
    return destination


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Combine every iVMS download subdirectory into one MP4 file."
        )
    )
    parser.add_argument(
        "--source",
        type=Path,
        default=DEFAULT_SOURCE,
        help=f"Source root. Default: {DEFAULT_SOURCE}",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output directory. Default: {DEFAULT_OUTPUT}",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace MP4 files that already exist.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()

    try:
        ffmpeg = require_tool("ffmpeg")
        ffprobe = require_tool("ffprobe")
    except RuntimeError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    source_root = args.source.expanduser()
    output_root = args.output.expanduser()

    if not source_root.is_dir():
        print(
            f"ERROR: source directory does not exist: {source_root}",
            file=sys.stderr,
        )
        return 2

    output_root.mkdir(parents=True, exist_ok=True)

    directories = sorted(
        (path for path in source_root.iterdir() if path.is_dir()),
        key=natural_key,
    )

    if not directories:
        print(f"No subdirectories found under: {source_root}")
        return 0

    print(f"Source: {source_root}")
    print(f"Output: {output_root}")
    print(f"Directories found: {len(directories)}")
    print()

    completed = 0
    skipped = 0
    failed: list[tuple[Path, str]] = []

    for index, directory in enumerate(directories, start=1):
        print("=" * 80)
        print(f"[{index}/{len(directories)}] {directory.name}")
        try:
            result = combine_directory(
                ffmpeg,
                ffprobe,
                source_directory=directory,
                output_directory=output_root,
                overwrite=args.overwrite,
            )
            if result is None:
                skipped += 1
            else:
                completed += 1
        except KeyboardInterrupt:
            print("\nCancelled.")
            return 130
        except Exception as error:
            failed.append((directory, str(error)))
            print(f"  FAILED: {error}", file=sys.stderr)

    print()
    print("=" * 80)
    print(
        f"Finished. Completed: {completed}, skipped: {skipped}, "
        f"failed: {len(failed)}"
    )

    if failed:
        print("\nFailures:")
        for directory, message in failed:
            print(f"  - {directory.name}: {message}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
