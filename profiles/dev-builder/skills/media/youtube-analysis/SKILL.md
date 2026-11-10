---
name: youtube-analysis
description: "Use when a YouTube URL needs transcript + visual analysis."
version: 1.0.0
author: Hermes Agent
license: MIT
created_by: agent
metadata:
  hermes:
    tags: [YouTube, video, transcripts, vision]
    related_skills: [blocked-page-recovery]
---

# YouTube Analysis

## When to Use

Use this workflow when de gebruiker sends a YouTube URL and wants more than a generic web summary.

## Default workflow

1. Run the bundled ingestion script:

```bash
uv run scripts/youtube_ingest.py "<youtube-url>"
```

2. Read `transcript.md` and `metadata.json` from the reported output directory.
3. Inspect `contact-sheet.jpg` with `vision_analyze`.
4. If small UI text matters, inspect the relevant image from `frames/` separately at full resolution.
5. Base the answer on both transcript and visual evidence. Clearly distinguish what was spoken from what was inferred from diagrams or screens.

## Useful options

```bash
uv run scripts/youtube_ingest.py "<url>" --no-video
uv run scripts/youtube_ingest.py "<url>" --output-dir /path/to/output
uv run scripts/youtube_ingest.py "<url>" --frame-count 24
```

## Fallback ladder

1. `youtube-transcript-api` for timestamped captions.
2. `yt-dlp` for metadata and a low-resolution analysis copy.
3. `ffmpeg` for individual frames and a contact sheet.
4. If YouTube blocks the current IP, do not loop aggressively. Retry later or run the same script through a trusted residential/local egress worker. Never upload browser cookies to chat, Git, logs, or an untrusted proxy.
5. If captions are absent, download audio locally and transcribe it with an approved Whisper/STT runtime before analysis.

## Safety and storage

- Download only what is needed for private analysis; do not redistribute source media.
- Keep artifacts in the profile cache/scratch area unless the user asks to retain them.
- Never commit downloaded videos, captions, cookies, or proxy credentials to Git.
- Prefer anonymous access. Use browser cookies only for content that genuinely requires login, and keep them on the originating device.
