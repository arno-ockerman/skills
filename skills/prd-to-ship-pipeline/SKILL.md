---
name: prd-to-ship-pipeline
description: Use when a feature idea needs a PRD, issues, and ship runs.
version: 1.0.0
created_by: agent
---

# PRD → GitHub issues → Archon ship

Use for a new feature or product increment that should end as reviewed PRs. The default chain:

```
idea → plan-create-prd → (plan-architecture) → plan-create-stories --platform github
     → GitHub issues → archon-ship per issue (or archon-lifecycle once installed)
```

## Step 1 — PRD (skill `plan-create-prd`)

Interactive, problem-first interview; never generate from thin air. Let the interview run: post a cluster of questions, then stop and wait — never ask and answer in the same turn.

Hard rules that matter here:

- The problem statement must leave room for more than one solution; if only one solution fits, it is a spec, not a PRD.
- The hypothesis needs a RIGHT **and** a WRONG condition.
- No engineering decisions (libraries, versions, data model, security boundaries, testing architecture) — those belong to `plan-architecture` and to the per-ticket implementation plan.
- Unknown stays `TBD — needs validation`.
- Output goes to `<kebab-slug>.prd.md` (in `docs/` when it exists, else the repo root), never a hardcoded `PRD.md`.

Commit the PRD to the repo before any Archon run (see Pitfalls).

## Step 2 — Architecture (skill `plan-architecture`, optional)

Run it when the intent leaves the engineering shape genuinely open (new subsystem, stack choice, data model, integration boundary). Skip it for a small feature inside an established pattern — the per-ticket plan then carries the decisions.

## Step 3 — Slice to GitHub issues (skill `plan-create-stories`)

```
plan-create-stories <prd-path> --platform github [--milestone "<name>"]
```

- Reads the PRD's Implementation Phases (phase = ticket group) and User Stories (story = one ticket, split when it hides more than about a day of work).
- Prints the proposed ticket list first and **waits for confirmation** before creating anything.
- Creates issues with `gh issue create`, acceptance criteria as a markdown checklist, one `phase-N` label per phase (creates missing labels with `gh label create`).
- Requires PRD sections named Implementation Phases and User Stories. If the PRD lacks them, say so and either add them or slice manually — never invent tickets the PRD does not support.
- `gh` here is `/opt/ai-tools/bin/gh`, authenticated as `arno-ockerman` (scopes: repo, read:org, workflow).

When the Archon `archon-backlog` workflow becomes available on the server it is the automated equivalent (deterministic check for duplicate keys, forward dependencies and the ticket bound, plus a `<!-- archon-backlog: <key> -->` dedup marker). Prefer it then; use this skill meanwhile, or when a human-gated, reviewable ticket list matters more than automation.

## Step 4 — Run Archon per issue

One issue per run. Never combine multiple issues into one invocation: each run gets its own worktree and PR.

Where the workflows actually live in Arno's environment (verify again before quoting this):

- **Server** `https://archon.beinspiredbyus.be` (v0.10.1, docker, `/api/workflows`) has the composed sdlc pack: `archon-ship`, `archon-triage`, `archon-plan`, `archon-investigate`, `archon-deliver`, `archon-implement`, `archon-validate`, `archon-review`, `archon-pr`, `archon-upkeep`. `archon-ship` runs its own triage; its target may be an issue URL, document, plan, report, or free-form request.
- **CLI** `/opt/ai-tools/bin/archon` (v0.6.0, source checkout `/opt/ai-tools/src/Archon`) ships only the legacy defaults — `archon-idea-to-pr`, `archon-plan-to-pr`, `archon-feature-development`, `archon-fix-github-issue`, `archon-interactive-prd`, and 16 more. It has **no** `archon-ship`/`archon-triage`: `archon workflow run archon-ship` from the CLI cannot work until the pack is vendored into the repo's `.archon/workflows/`.

Routes to start a run:

```bash
# CLI, legacy pack (works today) — input is a feature description OR a path to a PRD file
/opt/ai-tools/bin/archon workflow run archon-idea-to-pr --branch feat/<name> "docs/<slug>.prd.md"
# CLI, existing plan/PRD file executed as the plan
/opt/ai-tools/bin/archon workflow run archon-plan-to-pr --branch feat/<name> "Execute docs/<slug>.prd.md"
```

- **Web UI / Telegram adapter**: both are active platforms on the server; start `archon-ship` with the issue URL as target. This is the route for the sdlc pack today.
- Repo-local sdlc runs (CLI) require vendoring the pack workflows from `coleam00/Archon` `.archon/workflows/sdlc/` into the target repo's `.archon/workflows/` — see the `archon-workflow-operations` skill for the pinned revision.

Always pass `--branch` (worktree isolation) for anything that mutates code, and run long workflows in the background.

## Sending a PRD straight to Archon (no slicing)

Legitimate for one coherent piece of work where a single PR is the right unit; wrong for a multi-phase PRD, because one run then produces one giant PR and one review. Use `archon-idea-to-pr` (CLI, accepts a PRD path) or `archon-ship` (server, target = the PRD path or its text). Slicing first stays the default: it yields one worktree, one PR, one review per issue and lets runs parallelize.

## Pitfalls

- A worktree contains tracked files only. A PRD that is not committed is invisible to a run — commit and push it first, or paste its content into the prompt.
- Archon's GitHub adapter triggers on issue/PR **comments** only, not on issue descriptions. Mentioning the bot in a PRD or issue body does nothing.
- Do not point triage/ship at a half-written PRD: triage judges the contract (problem, why, why now, outcome, invariants, acceptance) and routes `NEEDS_CONTRACT_WORK` when one is missing. A PRD that merely lists features will not become a run.
- Creating issues is not reversible in one click — keep the confirmation gate from step 3.
- Server and CLI versions differ (0.10.1 vs 0.6.0). Never promise a workflow name that exists on only one of them; check `/api/workflows` or `archon workflow list --json` first.

## Vendored source

The three planning skills came from `coleam00/skills` v1.3.1 (commit `dfaa9105741fc5ba9b16b6a72551cad4bad70415`), copied verbatim except for a trigger-first first sentence in each `description`. Refresh with `git -C <clone> pull` plus a re-copy when Cole changes them.
