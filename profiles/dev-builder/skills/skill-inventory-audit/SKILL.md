---
name: skill-inventory-audit
description: Use when pruning or reviewing a profile's installed skills.
version: 1.0.0
created_by: agent
---

# Auditing and pruning installed skills

Use when the user wants to review which skills are installed, drop unused ones, or shrink the always-on skill index.

## Measure before deleting

Never prune on impression. Usage evidence lives in the profile's session store:

```python
import sqlite3, json, collections
con = sqlite3.connect('file:/opt/data/profiles/dev-builder/state.db?mode=ro', uri=True)
rows = con.execute("select role, content, tool_calls, timestamp from messages").fetchall()
```

Count `skill_view` and `skill_manage` calls per skill name by parsing the `tool_calls` JSON (`function.name` plus `function.arguments.name`), and keep the newest timestamp per skill. Then scan the skills directory for `SKILL.md` files to get the installed set, normalizing tool-call names that carry a prefix (`mattpocock/engineering:implement` → `implement`).

Report per skill: times loaded, last used, installed date. Claude's own rule of thumb for always-on cost is roughly 130 tokens per skill description, so sum description lengths for a real estimate before/after.

## The archive convention

Skills under `skills/.archive/<name>/` are invisible: the index skips dot-directories, so archived skills cost **zero context**. Use it as the default for anything uncertain — it is a directory move, instantly reversible.

```bash
mv skills/<category>/<name> skills/.archive/<name>
```

Hard-delete only what is clearly dead, and back it up first with `zipfile` (verify the archive's `SKILL.md` count equals the count on disk, and run `testzip()` before removing anything).

## Measuring the fixed prompt budget

`hermes prompt-size --platform <cli|telegram|...> --json` reports the per-turn static cost offline: `system_prompt.chars`, `skills_index.chars`, `memory.chars`, `user_profile.chars`, `tools.count`/`tools.json_bytes`, plus `sections` and `toolsets_breakdown` (per-toolset json bytes — the ranking that shows which tools are worth disabling). Run it from the profile's `HOME` so it resolves the right `config.yaml` (`hermes config path` confirms which profile it reads).

Two traps:

- **`prompt-size` does not model MCP tools.** Disabling an MCP server changes nothing in its output — there is no `mcp__` string anywhere in the report. The MCP catalog rides inside the `tool_search` tool description at session start, so measure it from a real request dump (`profiles/<p>/sessions/request_dump_*.json`, or the live prompt) and treat the saving as taking effect on the next gateway start.
- **Per-tool cost in the MCP catalog** is roughly 45 chars per qualified name (`mcp__vercel__accept_project_transfer_request` ≈ 44). A server with 216 tools costs ≈ 10 k chars ≈ 2.5 k tokens per turn before its schemas are ever fetched.

Lever ranking by measured size, biggest first: MCP catalog, built-in tool schemas (`file`, `delegation`, `browser`, `terminal`, `skills`, `homeassistant`...), the skills index, then memory/user profile.

Disabling an MCP server is a config write, and the agent is blocked from patching `config.yaml` directly. Use the sanctioned CLI instead: `hermes config set mcp_servers.<name>.enabled false`, then verify with `hermes mcp list`. Prefer this over editing the file, and leave servers that have no CLI equivalent in place until the user says otherwise.

## Skill index mechanics

The index truncates each description to **57 chars + `...`**, so text beyond that costs nothing and cutting a long description down to 57 saves nothing — only going *below* 57 does. Each entry costs its name plus up to 57 chars (`index_line_bytes` in `prompt-size --json`'s `skills_breakdown`, typically 60–95 bytes), and a category with a `DESCRIPTION.md` adds one long header line.

## Judgement rules

- **Never-loaded is weak evidence.** A skill installed days ago, or belonging to work that has not started, has had no chance to fire. Compare install date with the audit window before calling it unused.
- **A same-day load inside `.archive` means restore, not delete.** Check the last-used dates of archive candidates against today before purging the archive.
- **An empty category shell** (a directory holding only `DESCRIPTION.md`) is removable, but back the shells up first — they carry the category's description text.
- Keep the used set intact by construction: build the archive list from never-loaded names only, then diff the remaining active names against the loaded set afterwards.
- Watch for skills superseded by a renamed sibling (for example `systematic-debugging` → `diagnosing-bugs`, `test-driven-development` → `tdd`, `requesting-code-review` → `code-review`); those are safe archive candidates regardless of history.

## Verification

1. Count `SKILL.md` files outside `.archive` before and after; state both numbers.
2. Recompute the description token estimate for the remaining set.
3. Reload the index (`skills_list`) and confirm the active count matches the filesystem count.
4. Write a cleanup log with the moved names per group, the backup paths, and copy-paste restore commands; hand it to the user instead of leaving it in chat only.

Prefer `clarify` with grouped decisions over one question per skill: group by theme (out-of-domain, superseded course skills, tooling internals, documents/productivity), recommend an option first, and offer "archive" ahead of "delete".
