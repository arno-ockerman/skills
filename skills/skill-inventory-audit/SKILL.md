---
name: skill-inventory-audit
description: Use when pruning or reviewing installed Claude/Codex skills.
version: 1.0.0
created_by: agent
---

# Auditing and pruning installed skills (Claude Code / Codex CLI)

Use when the user wants to review which skills are installed for these CLIs, drop unused ones, or shrink what loads at startup.

## Where the skills live

| CLI | Skill root | Notes |
|---|---|---|
| Claude Code | `~/.claude/skills/<name>/SKILL.md` | `HOME` is the shared ai-tools Claude home, so every consumer (Herdr workbox, Archon) sees the same set. Claude also supports plugins (`/plugin marketplace add`) for managed, read-only sets. |
| Codex CLI | `$CODEX_HOME/skills/<name>/SKILL.md` | Codex's own preinstalled skills sit in `skills/.system/` and are maintained by the CLI — never prune or edit those. |

Both take the same `SKILL.md` shape: YAML frontmatter with `name` and `description`, body below. A skill becomes available on the next turn/session after it is written.

## Measure before deleting

Claude Code keeps per-project transcripts; Codex keeps threads in SQLite. Both are readable evidence:

```python
import glob, os, collections, sqlite3
# Claude Code — per-project transcripts (~/.claude/projects/**/*.jsonl)
files = glob.glob(os.path.expanduser('~/.claude/projects/**/*.jsonl'), recursive=True)
hits = collections.Counter()
for f in files:
    for line in open(f, encoding='utf-8', errors='replace'):
        for name in SKILL_NAMES:          # the names you are auditing
            if name in line:
                hits[name] += 1
# Codex — thread items and logs
cx = os.path.expanduser('~/.codex')
con = sqlite3.connect(f'file:{cx}/thread_history_1.sqlite?mode=ro', uri=True)
rows = con.execute("select thread_id, item_json from thread_items").fetchall()
```

A skill being absent from that history is weak evidence on its own: transcripts only cover sessions that ran after the skill was installed. Treat "never seen" plus an install date older than the transcript window as unused; keep anything recent, and keep anything the user says they are about to use.

## The archive convention

Keep pruned skills **outside** the skills root rather than in a dot-directory inside it, because these CLIs' discovery rules for hidden directories are not guaranteed:

```bash
mkdir -p ~/.claude/skills-archive
mv ~/.claude/skills/<name> ~/.claude/skills-archive/<name>
# Codex
mkdir -p "$CODEX_HOME/skills-archive"
mv "$CODEX_HOME/skills/<name>" "$CODEX_HOME/skills-archive/<name>"
```

Before any hard delete, zip the directory and verify the archive (`zipfile.testzip()`, and that its `SKILL.md` count equals the count on disk). Restoring is then a single `mv` back.

## Judgement rules

- **Never touch `skills/.system/`** in Codex, and never touch files under a Claude plugin directory — those are CLI-managed and come back on the next update.
- Watch for skills superseded by a renamed sibling; those are safe candidates regardless of history.
- Prefer archive over delete for anything uncertain — it is a directory move and instantly reversible.
- Decide in groups, not one skill at a time: group by theme (out-of-domain, superseded/course skills, tooling internals, documents/productivity) and offer "archive" ahead of "delete".
- Report the cost honestly: each installed skill contributes only its name plus the truncated description to the always-on prompt, so the saving from pruning one skill is small and only matters in bulk. Say so instead of overselling it.

## Verification

1. Count `SKILL.md` files under the skills root before and after; state both numbers.
2. Re-check that the files left behind parse: frontmatter with non-empty `name` and `description`.
3. Keep a short written log (moved names per group, archive paths, restore commands) and hand it to the user.
