# Apple Notes + Voice Memos via Google Drive into ProductivityCenter

## Use case
For this user's personal context repo (`/opt/ai-context/ProductivityCenter`), Google Drive acts as the intake layer and Hermes processes new captures into durable notes.

## Intake pattern
- Drive root folder: `ProductivityCenter Capture`
- Drop all inbound context there.
- Keep raw captures in `raw/` and interpreted notes in `notes/`.
- Preserve the existing daily git sync of the context repo for multi-device pull/rebase/push.

## Routing pattern
- Audio (`.m4a`, `.mp3`, `.wav`, `.mp4`, `.aac`, `.mpeg`, `.mpga`) -> `raw/voice-memos/`
- Apple Note PDFs -> `raw/apple-notes/`
- Apple Note ZIP exports (`.zip`) -> `raw/apple-notes/`
- Image exports (`.png`, `.jpg`, `.jpeg`, etc.) are usable as visual sources; if the pipeline supports them, route them with Apple Notes rather than generic misc.
- Other files -> `raw/misc/`

## Transcription pattern
- Use `faster-whisper` locally.
- For mixed Dutch/English voice notes, prefer automatic language detection over forcing `nl`.
- `medium` + `int8` on CPU is a reasonable quality/performance tradeoff for this workflow.

## Apple Notes export guidance
For handwritten Apple Notes, ZIP is usually the best source package **if the pipeline reads attachments**.

### Why ZIP wins
- Preserves note structure.
- Preserves embedded assets.
- Keeps screenshots, JPEGs, and embedded PDFs together.

### Critical pitfall
The `.md` inside an Apple Notes ZIP often does **not** contain the handwritten content itself. It frequently contains only:
- the title
- attachment references
- sparse alt text

For handwritten notes, the real content may live in:
- PDF attachments
- image attachments

So do **not** summarize ZIP Apple Notes from the `.md` alone. Always inspect or render the attachments too.

## Export preference order
1. ZIP (`.md` + attachments) when attachment-aware processing exists.
2. PDF as a simpler fallback.
3. Loose images only as fallback when structure is less important.

## Implementation guidance for future sessions
- Store extracted ZIP contents under a separate raw extracted directory.
- Record `attachment_files`, `rendered_pages`, and `bundle_root` in the catalog.
- For PDF attachments inside ZIPs, render pages for vision review because embedded text may be empty.
- Auto-generated context notes should summarize the combined bundle, not just the markdown stub.

## Verification checklist
- Renaming the Drive file should update the synced local filename and catalog entry.
- ZIP extraction should yield: extracted markdown, attachment inventory, rendered pages for embedded PDFs, and `ready-for-review` status.
- If an all-in-one wrapper is heavy, verify ZIP extraction directly rather than assuming the whole batch failed.
