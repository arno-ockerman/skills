# Google Drive capture root -> ProductivityCenter pattern

## Use case
A personal knowledge vault needs weekly ingestion of:
- iPhone voice recordings / Voice Memos
- iPad Apple Notes exported with Apple Pencil handwriting
- future miscellaneous files

## Proven structure
Upstream inbox in Google Drive:
- `ProductivityCenter Capture/`

Local vault structure:
- `raw/apple-notes/`
- `raw/voice-memos/`
- `raw/misc/`
- `raw/rendered/`
- `raw/manifests/`
- `notes/`
- `scripts/`

## Key design choice
Prefer a **single Drive root folder** as the user-facing inbox. Let automation sort files locally by type. This reduces friction on mobile and avoids requiring the user to choose the correct subfolder every time.

## Routing rule
- pdf -> `raw/apple-notes/`
- audio (`m4a`, `mp3`, `wav`, etc.) -> `raw/voice-memos/`
- other -> `raw/misc/`
- folders in the Drive root can be ignored if the root-scan workflow is active

## Processing rule
- Audio: transcribe with Whisper/faster-whisper and store transcript metadata in a manifest/catalog.
- Apple Notes PDFs: attempt extraction when possible, but for handwritten notes render pages to images for later vision interpretation.
- Keep processing state in a catalog file so weekly review can identify only new/unreviewed items.

## Scheduling pattern
- Sync/extract every few hours.
- Weekly Hermes review converts pending items from `raw/` into structured `notes/`.

## Important distinction
A vault may already have a separate cron job that commits/pushes the repo with git. Keep that conceptually separate from the capture pipeline:
- capture job = ingest and process content
- git-sync job = backup/version control

## User instruction to preserve
Explain the workflow simply: drop files into the Drive root and Hermes handles sorting + weekly review.
