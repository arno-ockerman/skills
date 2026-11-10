#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = ["youtube-transcript-api>=1.2.3"]
# ///
"""Create transcript and visual-analysis artifacts for a YouTube video."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from youtube_transcript_api import YouTubeTranscriptApi

DEFAULT_ROOT = Path("/opt/data/profiles/dev-builder/cache/scratch/youtube")


def video_id_from(value: str) -> str:
    value = value.strip()
    if re.fullmatch(r"[0-9A-Za-z_-]{11}", value):
        return value
    parsed = urlparse(value)
    host = parsed.netloc.lower().split(":", 1)[0]
    if host.endswith("youtu.be"):
        candidate = parsed.path.strip("/").split("/", 1)[0]
    elif "youtube.com" in host:
        if parsed.path == "/watch":
            candidate = parse_qs(parsed.query).get("v", [""])[0]
        else:
            parts = [part for part in parsed.path.split("/") if part]
            candidate = parts[1] if len(parts) >= 2 and parts[0] in {"embed", "shorts", "live"} else ""
    else:
        candidate = ""
    if not re.fullmatch(r"[0-9A-Za-z_-]{11}", candidate):
        raise ValueError(f"Geen geldige YouTube-video-ID gevonden in: {value}")
    return candidate


def run(command: list[str], *, timeout: int = 600) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, capture_output=True, text=True, timeout=timeout)


def timestamp(seconds: float) -> str:
    total = max(0, int(seconds))
    hours, remainder = divmod(total, 3600)
    minutes, secs = divmod(remainder, 60)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}"


def fetch_transcript(video_id: str, out_dir: Path, languages: list[str]) -> dict:
    try:
        transcript = YouTubeTranscriptApi().fetch(video_id, languages=languages)
        snippets = [
            {"start": item.start, "duration": item.duration, "text": item.text}
            for item in transcript
        ]
        payload = {
            "video_id": video_id,
            "language": getattr(transcript, "language", None),
            "language_code": getattr(transcript, "language_code", None),
            "is_generated": getattr(transcript, "is_generated", None),
            "snippets": snippets,
        }
        (out_dir / "transcript.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        lines = [f"# Transcript — {video_id}", ""]
        lines.extend(f"[{timestamp(item['start'])}] {item['text']}" for item in snippets)
        (out_dir / "transcript.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        return {
            "ok": True,
            "items": len(snippets),
            "language": payload["language_code"],
            "path": str(out_dir / "transcript.md"),
        }
    except Exception as exc:
        (out_dir / "transcript-error.txt").write_text(
            f"{type(exc).__name__}: {exc}\n", encoding="utf-8"
        )
        return {"ok": False, "error": type(exc).__name__}


def fetch_metadata(url: str, out_dir: Path) -> tuple[dict, dict]:
    command = [
        "uvx", "yt-dlp",
        "--js-runtimes", "node:/usr/local/bin/node",
        "--skip-download",
        "--dump-single-json",
        "--no-warnings",
        "--no-playlist",
        url,
    ]
    proc = run(command, timeout=300)
    if proc.returncode != 0:
        (out_dir / "metadata-error.txt").write_text(proc.stderr[-4000:], encoding="utf-8")
        return {}, {"ok": False, "error": f"yt-dlp exit {proc.returncode}"}
    try:
        metadata = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        (out_dir / "metadata-error.txt").write_text(str(exc), encoding="utf-8")
        return {}, {"ok": False, "error": "invalid JSON"}
    useful = {
        key: metadata.get(key)
        for key in (
            "id", "title", "description", "channel", "channel_id", "uploader",
            "upload_date", "duration", "webpage_url", "thumbnail", "availability",
        )
    }
    (out_dir / "metadata.json").write_text(
        json.dumps(useful, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    return useful, {"ok": True, "path": str(out_dir / "metadata.json")}


def create_visual_artifacts(url: str, out_dir: Path, duration: float, frame_count: int) -> dict:
    if not shutil.which("ffmpeg"):
        return {"ok": False, "error": "ffmpeg ontbreekt"}
    video_path = out_dir / "analysis-video.mp4"
    download = run(
        [
            "uvx", "yt-dlp",
            "--js-runtimes", "node:/usr/local/bin/node",
            "--format", "bv*[height<=360]+ba/b[height<=360]/b",
            "--merge-output-format", "mp4",
            "--max-filesize", "250M",
            "--no-playlist",
            "-o", str(video_path),
            url,
        ],
        timeout=900,
    )
    if download.returncode != 0 or not video_path.exists():
        (out_dir / "video-error.txt").write_text(
            (download.stdout + "\n" + download.stderr)[-8000:], encoding="utf-8"
        )
        return {"ok": False, "error": f"yt-dlp exit {download.returncode}"}

    interval = max(5.0, float(duration or 0) / max(1, frame_count))
    frames_dir = out_dir / "frames"
    frames_dir.mkdir(exist_ok=True)
    frame_pattern = frames_dir / "frame-%03d.jpg"
    frame_proc = run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(video_path),
            "-vf", f"fps=1/{interval:.3f},scale='min(1280,iw)':-2",
            "-q:v", "2", str(frame_pattern),
        ],
        timeout=600,
    )
    frames = sorted(frames_dir.glob("frame-*.jpg"))
    if frame_proc.returncode != 0 or not frames:
        return {"ok": False, "error": "frame extraction failed", "video": str(video_path)}

    sheet = out_dir / "contact-sheet.jpg"
    sheet_proc = run(
        [
            "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(video_path),
            "-vf", f"fps=1/{interval:.3f},scale=320:-1,tile=4x4:padding=4:margin=4",
            "-frames:v", "1", str(sheet),
        ],
        timeout=600,
    )
    return {
        "ok": sheet_proc.returncode == 0 and sheet.exists(),
        "video": str(video_path),
        "contact_sheet": str(sheet) if sheet.exists() else None,
        "frames_dir": str(frames_dir),
        "frame_count": len(frames),
        "interval_seconds": round(interval, 3),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("url")
    parser.add_argument("--output-dir")
    parser.add_argument("--no-video", action="store_true")
    parser.add_argument("--frame-count", type=int, default=16)
    parser.add_argument("--languages", default="en,nl,en-US,en-GB")
    args = parser.parse_args()

    try:
        video_id = video_id_from(args.url)
    except ValueError as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        return 2

    out_dir = Path(args.output_dir) if args.output_dir else DEFAULT_ROOT / video_id
    out_dir.mkdir(parents=True, exist_ok=True)
    languages = [item.strip() for item in args.languages.split(",") if item.strip()]

    transcript = fetch_transcript(video_id, out_dir, languages)
    metadata, metadata_result = fetch_metadata(args.url, out_dir)
    visuals = {"ok": False, "skipped": True}
    if not args.no_video:
        visuals = create_visual_artifacts(
            args.url,
            out_dir,
            float(metadata.get("duration") or 0),
            max(1, args.frame_count),
        )

    result = {
        "ok": bool(transcript.get("ok") or metadata_result.get("ok") or visuals.get("ok")),
        "video_id": video_id,
        "output_dir": str(out_dir),
        "transcript": transcript,
        "metadata": metadata_result,
        "visuals": visuals,
    }
    (out_dir / "ingest-result.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
