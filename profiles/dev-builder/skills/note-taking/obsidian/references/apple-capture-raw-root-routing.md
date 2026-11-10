# Apple capture raw-root routing pattern

Use this when changing an Obsidian/Google Drive capture pipeline so source artifacts remain immutable under `raw/` while reviewed notes live under `notes/`.

## Durable lessons

- Treat Drive intake sync as a raw-source ingest step, not as note creation.
- Route Apple Notes PDFs/ZIPs and iPhone Voice Memos to the raw root when the user wants a flat immutable source area:
  - config example: `routing.audio_dir = "."`, `routing.pdf_dir = "."`
  - keep misc/unsupported captures in a subfolder such as `raw/misc/`.
- If the catalog stores full local paths, migrate existing entries and files together:
  - move old `raw/apple-notes/<file>` / `raw/voice-memos/<file>` to `raw/<file>` when needed
  - update both `local_path` and `local_rel_path` in the catalog.
- When a sync script rewrites catalog entries, preserve optional extraction/review metadata on unchanged files, especially:
  - `transcript_meta`
  - `suggested_note_name`
  - `extracted_at`, `transcript_path`, `extracted_text_path`, `rendered_pages`, `attachment_files`, `bundle_root`
- Add `.gitignore` rules for the new raw-root artifact patterns so large/private audio/PDF/ZIP files are not committed accidentally, for example:
  - `raw/apple-notes__*`
  - `raw/voice-memos__*`

## Verification checklist

1. Run the sync script after the config change.
2. Run non-audio extraction if applicable to confirm no reprocessing is required.
3. Validate catalog routing: all `apple-notes` and `voice-memos` entries should have `local_rel_path` starting with `raw/` and not `raw/apple-notes/`, `raw/voice-memos/`, or `notes/`.
4. Check the git status: raw artifacts should be ignored; only config/scripts/docs/catalog metadata should be staged.
5. Commit and push only after the real sync/extract checks passed.
