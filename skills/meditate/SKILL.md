---
name: meditate
description: Use for the monthly audit of the agent's memory and instruction layer, or when asked to "meditate", "audit the brain", "prune memory". Finds stale, duplicate, misplaced and bloated entries in MEMORY.md, auto-memory and the agent docs, checks skills against what was learned, and applies the safe fixes.
version: 1.0.0
created_by: agent
---

# Meditate

Monthly audit that keeps the memory lean and the skills honest. Adapted from
`poteto/brainmaxxing` (MIT) for Arno's vault. `/reflect` adds; `/meditate` makes
sure what was added still earns its place.

**Quality bar.** An entry stays only if it is high-signal (an agent would get it
wrong without it), high-frequency, or high-impact. A lean memory beats a
complete one.

## 1. Gather

Read, from the vault root:

- `MEMORY.md` (count lines and characters).
- Claude auto-memory: `~/.claude/projects/-opt-project-ProductivityCenter/memory/`.
- `AGENTS.md`, `CLAUDE.md`, `HEARTBEAT.md`, `TODO.md`.
- `decisions/log.md` (headings and decisions only; skim).
- The last 30 days of `daily/` (grep for `Reflect:`, corrections, repeated problems).
- Skills: `/opt/ai-tools/src/skills/skills/*/SKILL.md` and the vault's `.agents/skills/`.

## 2. Audit

For every entry in `MEMORY.md` and auto-memory, classify:

- **Stale**: dates passed, status changed, a file or tool it names no longer
  exists. Verify with `ls`, `grep` or git before calling it stale.
- **Duplicate**: the same fact in two places (`MEMORY.md` vs auto-memory vs
  `AGENTS.md`/`CLAUDE.md`). Keep the one in the right layer, remove the other.
- **Misplaced**: a spec or long explanation. Move it to `Projects/<project>/`
  or `wiki/` and leave a one-line pointer.
- **Verbose**: more than one line for one fact. Condense.
- **Contradicted**: conflicts with a newer `decisions/log.md` entry.

Then look across entries:

- **Unstated rules**: the same lesson shows up 2+ times in `daily/` or memory.
  Propose one rule, in the layer where it will be read.
- **Skill drift**: a skill whose steps contradict a lesson or decision, or a
  lesson that should be a step in a skill.
- **Structural candidates**: a lesson that keeps being repeated in prose and
  could be a script, guard or check instead. Add to `TODO.md` (engine work
  belongs in `secondBrain`).

## 3. Apply

Apply directly (Arno reviews the diff):

- Delete stale or duplicate lines, condense verbose ones, move misplaced ones.
  Never delete a file: move it to `archives/`.
- Fix skills in the skills repo, then `./sync.sh install`, commit and push there.
- Add `TODO.md` items for structural candidates.

Propose only, never apply: changes to `AGENTS.md`, `CLAUDE.md`, `HEARTBEAT.md`,
and any new rule. List them with the exact wording.

## 4. Log and summarize

Append to today's `daily/` file: `- Meditate: MEMORY.md <before> -> <after> regels, <n> skills aangepast`.

Report, no em dashes:

```
## Meditate
- MEMORY.md: <before> -> <after> lines (<removed>, <condensed>, <moved>)
- Auto-memory: [changes]
- Skills: [findings, applied]
- Structural: [TODO items]
- Needs your OK: [AGENTS.md / CLAUDE.md / HEARTBEAT.md proposals, new rules]
```
