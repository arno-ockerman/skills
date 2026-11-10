---
name: ai-context-ops
description: Use when operating de gebruiker's AI-context vault and engine.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [ai-context, secondbrain, vault, knowledge-base, ingest, cross-agent]
    related_skills: [note-taking-tools, github-workflow]
---

# AI Context Ops

## When to Use

- Working on anything under `/opt/ai-context`: the ProductivityCenter vault or the secondBrain engine.
- Adding or fixing ingest automation, retrieval, linting, or cross-tool (Hermes/Codex/Claude) context.
- Reconciling the vault/engine split, scheduler ownership, or vault git sync.

de gebruiker's source-of-truth context lives at `/opt/ai-context`, split into two git repos with one invariant.

- **Vault** = `ProductivityCenter` (github arno-ockerman/ProductivityCenter). Durable knowledge only: Markdown notes, `wiki/`, `context/`, `daily/`, `drafts/`, `CRM/`, `decisions/`, and `knowledge/` manifests+taxonomy. Auto-pushed to GitHub.
- **Engine** = `secondBrain` (github arno-ockerman/secondBrain). Executable behavior: scripts, hooks, schedulers, retrieval index, deployment, tests. Reads/writes the vault via `VAULT_DIR`.
- **State** = machine-local, never git: Telegram offsets/queues, chat sessions, token caches, SQLite/Postgres index, locks.

## Hard rules

1. **Never mix the two repos.** Automation and scripts go in `secondBrain`; content, manifests, taxonomy and indexes go in the vault. A script that writes notes lives in `secondBrain` and resolves `VAULT_DIR`, never a baked vault path.
2. **Vault writers require sentinels.** `AGENTS.md` + `MEMORY.md` must exist in `VAULT_DIR` before any engine write. This defends against writing into a wrong or empty mount.
3. **Commit selectively in the vault.** ProductivityCenter may carry de gebruiker's own uncommitted work (modified `MEMORY.md`, untracked `learning/`). `git add` only the files you created or changed, never `git add -A`.
4. **AGENTS.md is the canonical tool-neutral rules file.** `CLAUDE.md` imports it (`@AGENTS.md`). Anything Hermes, Codex and Claude must all obey lives in `AGENTS.md` exactly once — never re-declared per tool.

## Test the engine with separate roots

Tests exercise the split topology, not a merged-repo layout:

```bash
CODE_DIR=/opt/ai-context/secondBrain \
VAULT_DIR=/opt/ai-context/ProductivityCenter \
STATE_DIR=/tmp/secondbrain-state \
  .venv/bin/python -m pytest tests -q
```

`conftest.py` asserts the three roots are set, distinct and non-nested. Do not write tests that expect vault files (`CLAUDE.md`, `decisions/log.md`, `daily/`, `.gitattributes`) inside the code repo — they live in the vault after the split.

## Path validation must be host-independent

Write guards run on Linux but must still reject Windows paths. A bare string like `C:\Windows\x` parses as a *relative* path on POSIX, so string-prefix checks silently allow it. Classify foreign absolute paths with `pathlib.PureWindowsPath`/`PurePosixPath` (plus `ntpath`/`posixpath`) regardless of host, and reject drive-letter, UNC (`\\server\share`), device (`\\?\`, `\\.\`), POSIX-absolute, traversal and mixed-separator escapes in both shell redirections and write-tool paths. Preserve legitimate writes inside either root.

## Wiki conventions (vault)

- Obsidian `[[wikilinks]]`, no path or extension. Frontmatter: `type: concept|entity|source|overview|index`, plus `tags/created/updated/sources/status`. Source pages add `source_path`/`source_date`.
- **Read with `utf-8-sig`, not `utf-8`.** Some `wiki/concepts/` pages start with a UTF-8 BOM; a frontmatter regex anchored at `---` silently fails on them.
- Deterministic lint also flags mojibake indicators (e.g. `â€`, `Ã©`) and invalid dates.
- Retrieval is **index-first** (`wiki/index.md` → typed links) with **hybrid search fallback** (0.6 vector / 0.4 keyword) for the un-compiled long tail.

## Single-source research ingest

Use this sequence for a book, article, podcast, or other researched source:

1. Read `wiki/index.md`, `wiki/SCHEMA.md`, and one comparable source page before writing. Reuse the established cluster and page shape instead of inventing a parallel structure.
2. Establish the evidence boundary first. If the full source was not read, label the artifact as a synthesis from public publisher/author/review material; never call it a complete or authoritative summary. Prefer the publisher/author as the metadata source and cross-check substantive themes against independent material.
3. Write the durable source note, then the `wiki/sources/<slug>.md` page. Create an entity only when it has real reusable content. Extend existing concepts before creating a new concept.
4. Complete the wiring in the same task: relevant concepts, `wiki/index.md`, `wiki/overview.md` when the thesis moves, the catalog entity (for example `[[leeslijst]]`), `knowledge/taxonomy.json`, `knowledge/ingestion-manifest.json`, `wiki/log.md`, and `MEMORY.md` only when a durable count or fact changes.
5. Use a full `YYYY-MM-DD` `source_date`. Add the SHA-256 of the immutable source note to the manifest and mark it `compiled` only after all wiring is complete.
6. Run `.claude/scripts/vault_lint.py --vault "$VAULT_DIR" --json`. Compare against the baseline and require zero findings for the newly added source/entity even when the older vault has unrelated findings.
7. Inspect Git status again immediately before committing because vault autosync may commit or push while the task is running. Stage only remaining task files, push, then verify the remote branch SHA and exact target files through `gh api` before reporting completion.

## Knowledge compilation

For bulk ingestion of a backlog, use the two-pass pattern, never per-source free-writing:

1. extract structured candidates in parallel (JSON only, no prose pages);
2. a serial **canonicalization barrier** dedupes/clusters and freezes a manifest of canonical slugs + taxonomy;
3. only then write pages in parallel against that manifest.

This stops parallel agents from forking one concept into divergent slugs. After bootstrap, prefer **extend before create**: update existing pages, create only past a recurrence threshold. Full design + P0-P3 roadmap: `ProductivityCenter/research/secondBrain-current-state-analysis.md` and `/opt/ai-context/research/cole-medin-knowledge-base-analysis.md`.

## Cross-tool control plane

Hermes/Codex/Claude share the vault directory but not automatically the same memory, tools or lifecycle. The provider-neutral entry point is `.claude/scripts/brain.py` (subcommands `health`, `search`, `context`, `ingest-status`, `append-memory-event`, each `--json`), backed by `.claude/scripts/vault_lint.py`. Thin Hermes skills and Claude/Codex adapters call the same scripts rather than reimplementing retrieval or memory rules.

## Git auth on the Hermes container

Clone via `gh`, with credentials under `/opt/data`:

```bash
HOME=/opt/data gh repo clone arno-ockerman/<repo> /opt/ai-context/<repo>
```

Plain `git clone https://…` fails with `could not read Username` because git credentials live under `/opt/data`, not `/opt/data/home`.

## Pitfalls

- **The vault auto-pushes to GitHub.** Never put a token or secret in a tracked vault file; the daily sync and obsidian-git commit and push automatically. Re-read `git status` and `git log` before every manual commit because autosync can absorb part of the task mid-run; verify the remote through the provider API rather than inferring success from a stale tracking ref.
- **Scheduler overlap.** secondBrain's supercronic owns heartbeat/index/reflection/vault-sync on TrueNAS (`HEARTBEAT_ENABLED=1`). Hermes cron owns Apple/Drive capture and Granola sync. Never schedule the same job in both.
- **Hermes cron jobs can reference moved scripts.** After the engine split, capture scripts live in `secondBrain/scripts/`; a Hermes cron whose workdir still points at the vault will fail silently until re-pointed.
