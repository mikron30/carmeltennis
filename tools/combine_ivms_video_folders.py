#!/usr/bin/env python3
r"""Combine each iVMS-4200 download directory into one MP4 file.

Defaults:
  Source:
    C:\Users\Public\iVMS-4200 Site\UserData\Video
  Destination:
    C:\Users\Roy\Documents\carmeltennis\downloaded_tennis_videos

For every immediate subdirectory under the source directory, the script:
1. Scans all candidate video files and prints a full preview with size/duration.
2. Waits for confirmation before changing anything.
3. Deletes video files that ffprobe cannot read.
3. Sorts the readable fragments naturally by filename/path.
4. Re-encodes each fragment to a normalized H.264/AAC MP4.
5. Concatenates the normalized fragments into one MP4.
6. Verifies the final MP4 with ffprobe.
7. Deletes the source directory only after a valid MP4 exists.
8. If a valid MP4 already exists, deletes the matching source directory
   without converting it again.

A source directory is never deleted unless its destination MP4 passes
validation.

Requirements:
  ffmpeg and ffprobe must be installed and available in PATH.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path


DEFAULT_SOURCE = Path(r"C:\Users\Public\iVMS-4200 Site\UserData\Video")
DEFAULT_OUTPUT = Path(
    r"C:\Users\Roy\Documents\carmeltennis\downloaded_tennis_videos"
)

FFMPEG_TIMEOUT_SECONDS = 6 * 60 * 60
VIDEO_EXTENSIONS = {
    ".avi", ".mp4", ".mkv", ".mov", ".mpeg", ".mpg", ".ts",
    ".m2ts", ".dav", ".264", ".h264", ".hevc", ".h265",
}
VERIFIED_MARKER_SUFFIX = ".ivms_verified"


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


def probe_video_details(
    ffprobe: str,
    source: Path,
) -> tuple[bool, bool, float | None]:
    """Return (has_video, has_audio, duration_seconds)."""
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
                str(source),
            ],
            check=False,
            text=True,
            capture_output=True,
            timeout=60,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False, False, None

    if result.returncode != 0:
        return False, False, None

    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return False, False, None

    stream_types = {
        str(stream.get("codec_type", "")).lower()
        for stream in payload.get("streams", [])
        if isinstance(stream, dict)
    }
    duration_value = (payload.get("format") or {}).get("duration")
    try:
        duration = float(duration_value) if duration_value is not None else None
    except (TypeError, ValueError):
        duration = None

    return "video" in stream_types, "audio" in stream_types, duration


def format_duration(seconds: float | None) -> str:
    if seconds is None or seconds < 0:
        return "unknown"
    total = int(round(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    if hours:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}"
    return f"{minutes:02d}:{secs:02d}"


def format_size(size_bytes: int) -> str:
    return f"{size_bytes / (1024 * 1024):.1f} MB"


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


def _make_writable_and_retry(func, path: str, _exc_info) -> None:
    """shutil.rmtree error handler for Windows read-only files/folders."""
    try:
        os.chmod(path, stat.S_IREAD | stat.S_IWRITE | stat.S_IEXEC)
        func(path)
    except OSError:
        raise


def delete_source_directory(directory: Path) -> bool:
    """Try to delete a verified source directory without stopping the batch."""
    last_error: OSError | None = None

    for attempt in range(1, 4):
        try:
            shutil.rmtree(directory, onerror=_make_writable_and_retry)
            if not directory.exists():
                print(f"  Deleted source directory: {directory}")
                return True
        except OSError as error:
            last_error = error

        if attempt < 3:
            print(
                f"  Delete attempt {attempt}/3 failed; retrying in 2 seconds..."
            )
            time.sleep(2)

    print(
        "  WARNING: video is verified, but the source directory could not be "
        "deleted."
    )
    if last_error is not None:
        print(f"  Delete error: {last_error}")
    print(
        "  Close iVMS-4200 if it is running, or run this script from an "
        "Administrator terminal, then run it again."
    )
    return False


def delete_unreadable_video(path: Path) -> bool:
    """Delete an unreadable source video file, including read-only files."""
    try:
        try:
            path.chmod(stat.S_IREAD | stat.S_IWRITE)
        except OSError:
            pass
        path.unlink()
        return True
    except OSError as error:
        print(f"    WARNING: could not delete unreadable file: {path.name}")
        print(f"             {error}")
        return False


def collect_video_files(
    ffprobe: str,
    directory: Path,
) -> tuple[
    list[tuple[Path, bool, float | None]],
    list[Path],
    int,
]:
    candidates = sorted(
        (path for path in directory.rglob("*") if path.is_file()),
        key=natural_key,
    )

    videos: list[tuple[Path, bool, float | None]] = []
    unreadable: list[Path] = []
    ignored_count = 0

    for path in candidates:
        suffix = path.suffix.casefold()

        if suffix not in VIDEO_EXTENSIONS:
            ignored_count += 1
            continue

        has_video, has_audio, duration = probe_video_details(ffprobe, path)
        if has_video:
            videos.append((path, has_audio, duration))
        else:
            unreadable.append(path)

    return videos, unreadable, ignored_count


def print_directory_preview(
    source_directory: Path,
    videos: list[tuple[Path, bool, float | None]],
    unreadable: list[Path],
    ignored_count: int,
) -> None:
    print()
    print("  PREVIEW - nothing has been changed yet")
    print("  " + "-" * 76)

    total_size = sum(path.stat().st_size for path, _, _ in videos)
    total_duration = sum(
        duration for _, _, duration in videos if duration is not None
    )

    by_extension: dict[str, int] = {}
    for path, _, _ in videos:
        ext = path.suffix.casefold() or "<none>"
        by_extension[ext] = by_extension.get(ext, 0) + 1

    print(f"  Readable video files to combine: {len(videos)}")
    print(f"  Unreadable video files to delete: {len(unreadable)}")
    print(f"  Non-video files ignored: {ignored_count}")
    print(f"  Total readable size: {format_size(total_size)}")
    print(f"  Total readable duration: {format_duration(total_duration)}")
    if by_extension:
        extensions = ", ".join(
            f"{ext}: {count}" for ext, count in sorted(by_extension.items())
        )
        print(f"  Readable types: {extensions}")

    print()
    print("  FILES THAT WILL BE COMBINED:")
    if not videos:
        print("    (none)")
    else:
        for index, (path, has_audio, duration) in enumerate(videos, start=1):
            size_text = format_size(path.stat().st_size)
            audio_text = "audio" if has_audio else "no-audio"
            relative = path.relative_to(source_directory)
            print(
                f"    {index:>4}. {size_text:>10}  "
                f"{format_duration(duration):>8}  {audio_text:<8}  {relative}"
            )

    if videos:
        print()
        print("  LARGEST READABLE FILES:")
        largest = sorted(
            videos,
            key=lambda item: item[0].stat().st_size,
            reverse=True,
        )[:15]
        for path, _, duration in largest:
            print(
                f"    {format_size(path.stat().st_size):>10}  "
                f"{format_duration(duration):>8}  "
                f"{path.relative_to(source_directory)}"
            )

    if unreadable:
        print()
        print("  UNREADABLE VIDEO FILES THAT WILL BE DELETED:")
        for index, path in enumerate(unreadable, start=1):
            print(
                f"    {index:>4}. {format_size(path.stat().st_size):>10}  "
                f"{path.relative_to(source_directory)}"
            )

    print("  " + "-" * 76)


def confirm_directory() -> str:
    while True:
        answer = input(
            "  Proceed with this directory? [y = yes, s = skip, q = quit]: "
        ).strip().lower()
        if answer in {"y", "yes"}:
            return "yes"
        if answer in {"s", "skip", "n", "no", ""}:
            return "skip"
        if answer in {"q", "quit", "exit"}:
            return "quit"
        print("  Please enter y, s, or q.")


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


def verified_marker_path(destination: Path) -> Path:
    return destination.with_name(destination.name + VERIFIED_MARKER_SUFFIX)


def write_verified_marker(destination: Path) -> None:
    marker = verified_marker_path(destination)
    marker.write_text(
        "Created by combine_ivms_video_folders.py after filtering source "
        "files to real video extensions and validating the final MP4.\n",
        encoding="utf-8",
    )


def combine_directory(
    ffmpeg: str,
    ffprobe: str,
    *,
    source_directory: Path,
    output_directory: Path,
    overwrite: bool,
    assume_yes: bool,
    preview_only: bool,
) -> str:
    output_name = sanitize_filename(source_directory.name) + ".mp4"
    destination = output_directory / output_name

    marker = verified_marker_path(destination)

    videos, unreadable_video_files, ignored_count = collect_video_files(
        ffprobe,
        source_directory,
    )
    print_directory_preview(
        source_directory,
        videos,
        unreadable_video_files,
        ignored_count,
    )

    if preview_only:
        print("  Preview only: no files were changed.")
        return "previewed"

    if not assume_yes:
        decision = confirm_directory()
        if decision == "quit":
            raise KeyboardInterrupt
        if decision == "skip":
            print("  Skipped by user. No files were changed.")
            return "skipped"

    if destination.exists() and not overwrite:
        if valid_output_mp4(ffprobe, destination) and marker.is_file():
            size_mb = destination.stat().st_size / (1024 * 1024)
            print(
                f"  EXISTS and verified by current script: "
                f"{destination} ({size_mb:.1f} MB)"
            )
            if delete_source_directory(source_directory):
                return "existing"
            return "cleanup_pending"

        if valid_output_mp4(ffprobe, destination):
            print(
                "  Existing MP4 was created before the JPG-filter fix; "
                "rebuilding it safely from real video files only."
            )
        else:
            print(f"  Existing output is invalid; rebuilding: {destination}")

        destination.unlink(missing_ok=True)
        marker.unlink(missing_ok=True)

    if not videos:
        print("  SKIP: no playable video files found; source was NOT deleted.")
        return "skipped"

    deleted_unreadable = 0
    failed_unreadable_deletes = 0
    for path in unreadable_video_files:
        if delete_unreadable_video(path):
            deleted_unreadable += 1
        else:
            failed_unreadable_deletes += 1

    if deleted_unreadable:
        print(f"  Deleted {deleted_unreadable} unreadable video file(s).")
    if failed_unreadable_deletes:
        print(
            f"  WARNING: could not delete {failed_unreadable_deletes} "
            "unreadable video file(s)."
        )

    print(f"  Found {len(videos)} readable video fragment(s).")

    output_directory.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="ivms-combine-") as temp:
        temp_directory = Path(temp)
        parts: list[Path] = []

        for index, (source, has_audio, _duration) in enumerate(videos, start=1):
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

    if deleted_unreadable:
        print(
            f"  Note: {deleted_unreadable} unreadable source video file(s) "
            "were discarded before creating this MP4."
        )
    if failed_unreadable_deletes:
        print(
            "  Some unreadable source files are still present because Windows "
            "blocked their deletion; source-folder cleanup will still be tried."
        )

    write_verified_marker(destination)

    if delete_source_directory(source_directory):
        return "created"
    return "cleanup_pending"


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
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Process each directory without asking for confirmation.",
    )
    parser.add_argument(
        "--preview-only",
        action="store_true",
        help="Show exactly what would be processed, but change nothing.",
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
    cleanup_pending = 0
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
                assume_yes=args.yes,
                preview_only=args.preview_only,
            )
            if result == "created":
                created += 1
            elif result == "existing":
                existing += 1
            elif result == "cleanup_pending":
                cleanup_pending += 1
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
        f"Finished. Created+cleaned: {created}, existing+cleaned: {existing}, "
        f"cleanup pending: {cleanup_pending}, "
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
