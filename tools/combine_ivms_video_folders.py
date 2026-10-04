#!/usr/bin/env python3
r"""Combine each iVMS-4200 download directory into one MP4 file.

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
5. Verifies the final MP4 with ffprobe.
6. Deletes the source directory only after a valid MP4 exists.
7. If a valid MP4 already exists, deletes the matching source directory
   without converting it again.

A source directory is never deleted unless its destination MP4 passes
validation.

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


def valid_output_mp4(ffprobe: str, path: Path) -> bool:
    """Return True only for a non-empty MP4 with video and positive duration."""
    if not path.is_file() or path.stat().st_size < 1024:
        return False

    try:
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "stream=codec_type:format=duration",
                "-of",
                "json",
                str(path),
            ],
            check=False,
            text=True,
            capture_output=True,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False

    if result.returncode != 0:
        return False

    try:
        payload = json.loads(result.stdout or "{}")
        stream_types = {
            str(stream.get("codec_type", "")).lower()
            for stream in payload.get("streams", [])
            if isinstance(stream, dict)
        }
        duration = float((payload.get("format") or {}).get("duration") or 0)
    except (json.JSONDecodeError, TypeError, ValueError):
        return False

    return "video" in stream_types and duration > 0


def delete_source_directory(directory: Path) -> None:
    """Delete a source directory after its MP4 has been verified."""
    shutil.rmtree(directory)
    if directory.exists():
        raise RuntimeError(f"Could not delete source directory: {directory}")
    print(f"  Deleted source directory: {directory}")


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
) -> str:
    output_name = sanitize_filename(source_directory.name) + ".mp4"
    destination = output_directory / output_name

    if destination.exists() and not overwrite:
        if valid_output_mp4(ffprobe, destination):
            size_mb = destination.stat().st_size / (1024 * 1024)
            print(f"  EXISTS and verified: {destination} ({size_mb:.1f} MB)")
            delete_source_directory(source_directory)
            return "existing"

        print(f"  Existing output is invalid; rebuilding: {destination}")
        destination.unlink(missing_ok=True)

    videos = collect_video_files(ffprobe, source_directory)
    if not videos:
        print("  SKIP: no playable video files found; source was NOT deleted.")
        return "skipped"

    print(f"  Found {len(videos)} video fragment(s).")

    output_directory.mkdir(parents=True, exist_ok=True)

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

        # Build into a temporary MP4 first. Only replace the real destination
        # after the complete file has passed ffprobe validation.
        staged_destination = temp_directory / output_name
        print(f"  Joining {len(parts)} part(s)...")
        concat_parts(ffmpeg, parts, staged_destination)

        if not valid_output_mp4(ffprobe, staged_destination):
            raise RuntimeError(
                "Final MP4 failed ffprobe validation; source was NOT deleted."
            )

        if destination.exists():
            destination.unlink()
        shutil.move(str(staged_destination), str(destination))

    if not valid_output_mp4(ffprobe, destination):
        raise RuntimeError(
            "Destination MP4 failed final validation; source was NOT deleted."
        )

    size_mb = destination.stat().st_size / (1024 * 1024)
    print(f"  CREATED and verified: {destination} ({size_mb:.1f} MB)")
    delete_source_directory(source_directory)
    return "created"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Combine every iVMS download subdirectory into one MP4 file, "
            "verify it, then delete the source directory."
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

    created = 0
    existing = 0
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
            if result == "created":
                created += 1
            elif result == "existing":
                existing += 1
            else:
                skipped += 1
        except KeyboardInterrupt:
            print("\nCancelled.")
            return 130
        except Exception as error:
            failed.append((directory, str(error)))
            print(f"  FAILED: {error}", file=sys.stderr)

    print()
    print("=" * 80)
    print(
        f"Finished. Created: {created}, already existed: {existing}, "
        f"skipped: {skipped}, failed: {len(failed)}"
    )

    if failed:
        print("\nFailures:")
        for directory, message in failed:
            print(f"  - {directory.name}: {message}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
