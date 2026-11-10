# Raw-to-Notes Capture Pipeline

Concrete pattern for personal knowledge capture when source material is created on mobile/tablet devices and synchronized through a cloud folder.

## Goal
Keep a clean separation between:

- `raw/` — original artifacts and machine-generated extraction outputs
- `notes/` — human-usable markdown knowledge

## Example Folder Layout

```text
ProductivityCenter/
  notes/
  raw/
    apple-notes/
    voice-memos/
    manifests/
    rendered/
    logs/
  references/
  scripts/
```

## Intake Pattern

Cloud root with per-source subfolders:

- `Capture/Apple Notes`
- `Capture/Voice Memos`

Share/export from devices into those folders, then let a local sync script download to `raw/`.

## Processing Stages

1. **Sync**
   - list cloud folder contents
   - detect new/changed files
   - download into source-specific raw folders
   - update catalog JSON

2. **Extract**
   - audio: generate transcript text
   - PDF: extract embedded text when present
   - PDF: render page images for later visual inspection

3. **Review**
   - consume only pending items from the catalog
   - create concise markdown notes in `notes/`
   - mark entries processed with destination note path

## Recommended Scheduling

- sync+extract: every 4–6 hours
- review: weekly, delivered back to the user

This keeps ingestion deterministic and frequent, while reserving interpretation for a slower agentic pass.

## Catalog Fields Worth Tracking

- source type
- original cloud id/path
- local path
- modified time
- file size
- extraction status
- processed status
- output note path
- timestamps for sync/extract/process

## Why This Pattern Is Durable

- raw artifacts stay available for re-processing
- notes stay clean and human-readable
- duplicate work is reduced by explicit catalog state
- vision review can be added later without changing the intake layer

## Practical Notes

- Prefer timestamped filenames from the source device.
- Keep no-op sync jobs silent so cron output stays meaningful.
- Use a manifest/catalog instead of inferring status from filenames alone.
- If handwriting extraction is weak, treat rendered pages as the authoritative review input.
