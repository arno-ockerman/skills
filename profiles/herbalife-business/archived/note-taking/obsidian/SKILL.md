---
name: obsidian
description: Read, search, create, and maintain Obsidian vaults, including research-wiki workflows.
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

## Research wiki / LLM wiki mode

This umbrella also covers the Karpathy-style "LLM wiki" workflow when the user's markdown vault is acting as a compounding research knowledge base rather than a generic notes folder.

Use this mode when the user wants to:
- build a persistent research wiki in markdown
- ingest sources into a vault-backed knowledge base
- maintain `SCHEMA.md`, `index.md`, and `log.md` style vault metadata
- query or lint a research vault as a coherent system instead of editing one note at a time

Core rules carried forward:
1. Orient first on every session: read `SCHEMA.md`, then `index.md`, then recent `log.md` entries.
2. Treat `raw/` source material as immutable; synthesize into agent-owned notes elsewhere in the vault.
3. Create new pages only when an entity/concept is central or repeatedly referenced.
4. Add cross-links aggressively so pages are discoverable through `[[wikilinks]]`.
5. Update navigation artifacts (`index.md`, `log.md`) whenever the vault structure changes materially.

When the vault is specifically a research wiki, the maintainership pattern is:
- `raw/` for captured sources
- topic/entity/concept pages for synthesis
- explicit provenance, dates, and tags in frontmatter
- periodic linting for orphans, broken links, and stale pages

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
4. Commit only when staged diff is non-empty.
5. Read `git rev-list --left-right --count HEAD...origin/<branch>` as **ahead first, behind second**.
6. Rebase before push when the remote moved ahead.
7. Prefer quiet cron scripts that emit stdout only when a meaningful sync event occurred.
8. If inline `CRON_TZ=` schedules are unsupported, use an hourly wrapper that gates on `TZ=... date +%H:%M`.

Detailed operational notes live in:
- `references/git-backed-vault-sync.md`
- `references/hermes-nightly-sync-pattern.md`
- `references/productivitycenter-sync-example.md`
