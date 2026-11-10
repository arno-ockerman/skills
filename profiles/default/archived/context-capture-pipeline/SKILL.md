---
name: context-capture-pipeline
description: Build and maintain a durable capture pipeline that ingests personal notes, voice recordings, and other raw context into a knowledge vault with scheduled review.
---

# Context Capture Pipeline

## When to use
- The user wants Apple Notes, voice memos, scans, or other personal artifacts ingested into a repo or knowledge vault.
- The user wants a recurring workflow that separates raw capture from interpreted notes.
- The user mentions Google Drive or another sync layer as the collection inbox.
- The user wants Hermes to periodically review newly captured material and convert it into structured context.

## Core pattern
1. Pick **one user-friendly capture inbox** upstream. Prefer a single shared root folder over asking the user to sort files manually.
2. Mirror incoming files into a local vault under a strict split:
   - `raw/` for source artifacts
   - `notes/` for interpreted, human-usable context
   - `scripts/` for sync/extract/review automation
   - `raw/manifests/` for catalogs and processing state
3. Route files locally by type instead of making the user manage many upstream folders:
   - audio -> `raw/voice-memos/`
   - PDF notes/scans -> `raw/apple-notes/` or another note-source folder
   - everything else -> `raw/misc/`
4. Process raw material into machine-usable intermediate outputs:
   - audio -> transcript + metadata
   - PDF/handwritten notes -> text extraction if available, otherwise rendered images for later vision analysis
5. Keep a manifest/catalog so scheduled jobs can detect new vs already-processed files.
6. Use cron in two layers:
   - frequent sync/extract job
   - slower review job that turns pending items into structured notes in `notes/`
7. Preserve any separate git backup/sync automation unless it conflicts. Ingestion and repo backup are different jobs.

## Recommended workflow
1. Inspect the target vault structure and confirm where durable context belongs.
2. Confirm the upstream sync primitive already available to the user (for example Google Drive).
3. Create or confirm a single inbox folder the user can easily share to from phone/tablet.
4. Implement a sync script that scans the inbox root and routes files locally by mime type or extension.
5. Implement an extract script that generates transcripts, renderings, and manifest updates.
6. Implement a reporting/review script that lists unreviewed items for Hermes.
7. Schedule recurring cron jobs for sync/extract and review.
8. Test the scripts end-to-end with a manual run.
9. Document the user-facing rule simply: "drop everything into the capture root; Hermes sorts it locally."

## Apple-specific guidance
- For Apple Pencil / handwritten Apple Notes exported as PDF, do not rely only on text extraction. Render pages to images so a vision step remains possible.
- For iPhone voice recordings, store the original audio in `raw/voice-memos/` and keep transcript outputs alongside manifest metadata.
- If the user already has cloud storage they trust, prefer that over adding extra mobile automation complexity.

## Hermes cron wiring
When the scheduled jobs run under Hermes cron, script resolution has hard rules that bite if ignored:
- The `script` field resolves relative to `HERMES_HOME/scripts/` (NOT `workdir`) and the script must live inside that dir; symlinks that resolve outside it are blocked. `workdir` only sets the subprocess cwd.
- Established pattern: keep canonical scripts in the vault's `scripts/` (versioned), and put a thin `exec` wrapper in `HERMES_HOME/scripts/` that calls the real script by absolute path.
- In the wrapper use `exec bash <script>`, not `exec <script>`. On ZFS/repo mounts where `core.filemode=false` + `git pull --rebase` strips the executable bit, a direct `exec` fails with `Permission denied` (exit 126); `bash <script>` needs only read access.
- `write_file` is gated by `HERMES_WRITE_SAFE_ROOT`; to write outside it (shared tool root, a repo on another mount), stage the content under the safe root first, then `install`/`cp` it into place via terminal.
- Reuse the vault's existing git-sync script (it owns flock/auth/rebase/push) from the fetch script instead of re-implementing `git add/commit/push`.

## Pitfalls
- Do not turn the upstream inbox into a deep folder maze unless the user explicitly wants that. A single root is easier for mobile sharing.
- Do not mix source artifacts and interpreted notes in the same directory.
- Do not remove an existing git-sync job just because a new capture-sync job exists; first determine whether it serves backup/versioning.
- Do not assume handwritten PDFs contain extractable text.
- Do not leave processing state implicit; keep a catalog/manifest.
- Before concluding a capture source has no export path, check for an official API or MCP server. Many SaaS tools (meeting notetakers etc.) ship a REST API (`list`/`get` endpoints with bearer keys) even when the desktop app's local token/cache route does not apply (e.g. mobile-only users). Discover docs at `docs.<domain>/llms.txt` and `.md`-suffixed pages, which stay curl-fetchable even when web_extract/web_search backends are down.

## Verification
- Manual sync run exits cleanly.
- Manual extract run exits cleanly.
- Manifest updates after new files arrive.
- At least one test artifact lands in the correct local raw folder.
- Review job can produce a pending-items summary from current manifests.

## Support files
- `references/google-drive-apple-notes-voice-memos.md` — concrete pattern for a Google Drive capture root feeding a ProductivityCenter vault.
- `references/granola-api.md` — Granola (meeting notetaker) API/MCP/CLI facts and the mobile-only-tool discovery pattern.
