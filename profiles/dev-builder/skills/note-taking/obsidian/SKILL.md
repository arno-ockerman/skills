---
name: obsidian
description: Read, search, create, and edit notes in the Obsidian vault.
platforms: [linux, macos, windows]
---

# Obsidian Vault

Use this skill for filesystem-first Obsidian vault work: reading notes, listing notes, searching note files, creating notes, appending content, and adding wikilinks.

## Vault path

Use a known or resolved vault path before calling file tools.

The documented vault-path convention is the `OBSIDIAN_VAULT_PATH` environment variable, for example from `~/.hermes/.env`. If it is unset, use `~/Documents/Obsidian Vault`.

File tools do not expand shell variables. Do not pass paths containing `$OBSIDIAN_VAULT_PATH` to `read_file`, `write_file`, `patch`, or `search_files`; resolve the vault path first and pass a concrete absolute path. Vault paths may contain spaces, which is another reason to prefer file tools over shell commands.

If the vault path is unknown, `terminal` is acceptable for resolving `OBSIDIAN_VAULT_PATH` or checking whether the fallback path exists. Once the path is known, switch back to file tools.

## Read a note

Use `read_file` with the resolved absolute path to the note. Prefer this over `cat` because it provides line numbers and pagination.

## List notes

Use `search_files` with `target: "files"` and the resolved vault path. Prefer this over `find` or `ls`.

- To list all markdown notes, use `pattern: "*.md"` under the vault path.
- To list a subfolder, search under that subfolder's absolute path.

## Search

Use `search_files` for both filename and content searches. Prefer this over `grep`, `find`, or `ls`.

- For filenames, use `search_files` with `target: "files"` and a filename `pattern`.
- For note contents, use `search_files` with `target: "content"`, the content regex as `pattern`, and `file_glob: "*.md"` when you want to restrict matches to markdown notes.

## Create a note

Use `write_file` with the resolved absolute path and the full markdown content. Prefer this over shell heredocs or `echo` because it avoids shell quoting issues and returns structured results.

## Append to a note

Prefer a native file-tool workflow when it is not awkward:

- Read the target note with `read_file`.
- Use `patch` for an anchored append when there is stable context, such as adding a section after an existing heading or appending before a known trailing block.
- Use `write_file` when rewriting the whole note is clearer than constructing a fragile patch.

For an anchored append with `patch`, replace the anchor with the anchor plus the new content.

For a simple append with no stable context, `terminal` is acceptable if it is the clearest safe option.

## Targeted edits

Use `patch` for focused note changes when the current content gives you stable context. Prefer this over shell text rewriting.

## Wikilinks

Obsidian links notes with `[[Note Name]]` syntax. When creating notes, use these to link related content.

## Capture-ingestion pipelines

This umbrella also covers the common subclass of work where raw captures land elsewhere first (for example a Google Drive intake folder) and must become reviewed Obsidian notes.

Use this when the user wants to:
- sync newly uploaded voice memos, PDFs, or misc captures into the vault
- turn a raw memo/transcript into a usable context note
- troubleshoot why a capture pipeline downloaded nothing or stopped advancing state

Default workflow:
1. Identify the pipeline config plus its catalog/manifest state.
2. Run sync first so raw files land under a predictable `raw/` tree.
3. Run extraction second (transcript/text/images as appropriate).
4. Review extraction quality before writing the final note.
5. Write one durable markdown note under `notes/` with links back to the source artifacts.
6. Mark the catalog entry processed and verify the recorded note path matches reality.

High-value pitfalls preserved from the absorbed micro-skill:
- An "empty sync" often means the configured Drive root/folder ID is wrong, not that uploads are absent.
- Folder-only listings often signal a root/subfolder mismatch after a migration or manual reshuffle.
- Rough ASR output should be labeled as rough; summarize meaning and decisions instead of presenting noisy transcripts as authoritative.
- Do not stop at transcription when the real ask is vault ingestion — finish the reviewed note and state update.

## Git-backed vault sync

This umbrella also covers the common subclass of work where the vault itself is stored in Git and synced by Hermes automation.

Use this when the user wants:
- periodic vault sync via cron
- safe commit → fetch/rebase → push behavior
- troubleshooting of Git auth that only fails inside Hermes/cron
- suppression of noisy mode-bit-only changes on mounted vaults
- wrapper schedules for timezone-aware midnight sync
- explicit repo-boundary verification when the vault lives inside a parent container folder

High-value rules:
1. Verify the effective runtime `HOME`, not just the Unix account's home.
2. Test `git fetch origin` in the exact runtime context the automation will use.
3. Automate the real repo root, not a parent folder that merely contains it.
4. Write a real sync script with explicit pull/rebase/push behavior; dry-run it manually before cron.
5. Commit only when staged diff is non-empty and exit quietly on no-op.
6. Read `git rev-list --left-right --count HEAD...origin/<branch>` as **ahead first, behind second**.
7. Rebase before push when the remote moved ahead.
8. Treat rebase conflicts as recoverable operational states; do not overwrite notes to force a push.
9. Prefer quiet cron scripts that emit stdout only when a meaningful sync event occurred.
10. If inline `CRON_TZ=` schedules are unsupported, use an hourly wrapper that gates on `TZ=... date +%H:%M`.

Detailed operational notes live in:
- `references/git-backed-vault-sync.md`
- `references/hermes-nightly-sync-pattern.md`
- `references/productivitycenter-sync-example.md`
- `references/apple-capture-raw-root-routing.md` — Google Drive Apple Notes/Voice Memos capture routing to flat `raw/` while preserving catalog metadata and ignoring raw artifacts in Git.
