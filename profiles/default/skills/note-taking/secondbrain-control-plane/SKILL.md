---
name: secondbrain-control-plane
description: Use when de gebruiker asks about his vault, context, or knowledge.
---

# secondBrain control plane — de gebruiker's vault interface

Provider-neutral CLI in de gebruiker's automation engine (`arno-ockerman/secondBrain`).
Hermes, Codex, and Claude all reach the same vault (`/opt/ai-context/ProductivityCenter`)
through this one interface instead of each reimplementing retrieval.

## Invocation

```bash
cd /opt/ai-context/secondBrain
export CODE_DIR=/opt/ai-context/secondBrain \
       VAULT_DIR=/opt/ai-context/ProductivityCenter \
       STATE_DIR=/opt/data/cache/scratch/secondbrain-state
PY=.venv/bin/python

$PY .claude/scripts/brain.py health --json          # source/index/draft/sync status
$PY .claude/scripts/brain.py search "<query>" --json # hybrid retrieval with citations
$PY .claude/scripts/brain.py context --json          # date, recent daily logs, pending drafts
$PY .claude/scripts/brain.py ingest-status --json    # reads VAULT_DIR/ingest-manifest.json
$PY .claude/scripts/vault_lint.py --json             # deterministic wiki lint
```

`append-memory-event` is the only write command; everything else is read-only.
`search` degrades to keyword-only when the embedding model/index is absent.

## When to use which

- "what do I know about X" → `search` first, then open the cited wiki page.
- "how healthy is my knowledge base" → `vault_lint --json` (watch mojibake/dead_link/orphan).
- "what did we decide recently" → `context --json` (recent daily logs + drafts).
- "is my ingest pipeline running" → `health --json` (sources report available/not-configured).

## Key facts

- Vault `wiki/` uses Obsidian `[[wikilinks]]`; the linter resolves them case-insensitively.
- A dead link is often a deliberate "to-do" per `wiki/SCHEMA.md` — treat as suggestion, not error.
- 14 wiki files carry mojibake (double-encoded `â€`/`Ã©`); the linter flags them. Fixing is a
  separate content migration, not automatic.
- `knowledge/` (ingestion-manifest.json, taxonomy.json, README.md) is the machine-readable
  contract; `AGENTS.md` is the human instruction layer.
- Apple-capture pipeline: iPhone recording = iOS Shortcut "Spraaknotitie" → Google Drive map
  "ProductivityCenter Capture" → faster-whisper → raw/ → notes. Scripts live in secondBrain/scripts/
  (not the vault). Audio transcription chunks at 10 min (no length limit) and auto-falls-back on the
  whisper model when RAM is low.
- INGESTION + SYNC OWNERSHIP (de gebruiker's rule): secondBrain owns ALL automated vault writes,
  ingestion, scheduling and ProductivityCenter Git sync. Its brain-cron supercronic schedule runs
  apple sync (15m), audio-transcribe (2h), auto-notes (6h), weekly-review and vault-sync (2m).
  Deployment requires the split TrueNAS compose with CODE_DIR=/app, VAULT_DIR=/vault and the actual
  nested checkout `/mnt/HomeNAS/appdata/ai-context/ProductivityCenter:/vault` in all brain services
  (the parent `ai-context:/vault` is wrong: AGENTS.md/MEMORY.md then appear under a subdirectory and
  entrypoint fails). `brain_key` is scoped to secondBrain;
  separate write-enabled `vault_key` is scoped to ProductivityCenter. Hermes is read-only after
  cutover; its sync/ingest crons must only be paused after brain-cron + vault round-trip verification.
- The engine's security hooks are Claude-only; the control plane does not re-implement them.
