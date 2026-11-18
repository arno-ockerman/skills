---
name: reflect
description: Use when wrapping up a session, right after Arno corrects you, or when a session taught something worth keeping. Scans the conversation and routes each lesson to the one place it belongs (script/guard, MEMORY.md, a skill, decisions log, TODO, wiki, project note). Triggers: "reflect", "remember this", "wrap up", "what did we learn".
version: 1.0.0
created_by: agent
---

# Reflect

Turn this session into lasting improvements. Adapted from `poteto/brainmaxxing`
(MIT) for Arno's vault. The goal is a system that gets better, not a memory that
gets bigger.

## 1. Read what already exists

Before writing anything, read the current state of every place you might write
to, so you update a line instead of adding a duplicate:

- `MEMORY.md` (vault root). Loads into every conversation. Dutch, one fact per line.
- `decisions/log.md` (format is defined at the top of that file).
- `TODO.md`.
- The Claude auto-memory index (`~/.claude/projects/<project>/memory/MEMORY.md`), if it exists.

## 2. Scan the conversation for

- **Corrections**: where Arno said "no", "not like that", or redid your work. Quote his words.
- **Repeated preferences**: something he asked for that he has asked for before.
- **Gotchas**: tool, API, infra or repo behaviour that cost time to discover.
- **Decisions with a why**: a choice between options, and the reason.
- **Friction**: a skill that misfired, a missing step, a manual task done 3+ times.

Skip anything trivial, one-off, already captured, or derivable from the code or git history.

## 3. Route each lesson (first match wins)

1. **Can it be structural?** A script, lint rule, guard hook, test or checklist line
   beats a note, because a note can be ignored. If yes: add it to `TODO.md` as an
   automation candidate (engine changes go to `secondBrain`, never this vault).
   Do not also write a note.
2. **A skill misbehaved or missed a step** → edit that skill in
   `/opt/ai-tools/src/skills/skills/<name>/SKILL.md`, then
   `./sync.sh install`, commit and push in that repo. Read the skill first.
3. **A decision with tradeoffs** → append to `decisions/log.md` in its format.
4. **Follow-up work** → `TODO.md` (Someday for automation candidates). No GitHub
   issue until the item has an implementation plan.
5. **Domain knowledge** (business, training, health, a book) → `wiki/`, following
   `wiki/SCHEMA.md`.
6. **Project state or a project-specific gotcha** → that project's note in
   `Projects/<project>/`, or the repo's own `AGENTS.md`/`CLAUDE.md` when you are
   in that repo.
7. **A durable fact or preference about Arno, his setup, or how he works** →
   `MEMORY.md`. Terse, Dutch, absolute date. Update the existing line if there is one.
8. **Claude-only working feedback** (how Claude Code should behave, not true for
   Codex) → Claude auto-memory. Everything shared belongs in `MEMORY.md`.

**Quality bar.** Keep a lesson only if it is high-signal (an agent would get it
wrong without it), high-frequency (comes up in most sessions of a type) or
high-impact (getting it wrong wastes real time or causes damage). Three good
entries beat ten weak ones.

**MEMORY.md costs tokens in every conversation.** For every line you add, look for
one to shorten, merge or remove. Long specs belong in a project note with a
one-line pointer in `MEMORY.md`.

**Never edit `AGENTS.md` or `CLAUDE.md` silently.** Propose the exact change in
the summary and apply it only after Arno says yes. An instruction layer that
rewrites itself drifts.

## 4. Outside the vault

In another repo, route repo-specific lessons to that repo's agent docs. For
vault-level lessons (about Arno, cross-project), list them under "For the vault"
in the summary so they land in `MEMORY.md` in the next vault session. Do not
edit the vault from another repo's session.

## 5. Log and summarize

Append one line to today's `daily/YYYY-MM-DD.md` (append-only, never edit past
lines): `- Reflect: <n> lessons, <where they went>`.

Then report, no em dashes:

```
## Reflect
- Structural: [TODO items added]
- Skills: [skill files changed]
- Decisions: [entries appended]
- MEMORY.md: [+added / -removed lines]
- Wiki / projects: [pages touched]
- Proposed (needs your OK): [AGENTS.md / CLAUDE.md changes]
- For the vault: [only when outside the vault]
```

If nothing passed the quality bar, say so in one line. That is a valid outcome.
