# Chaining Archon runs: finish one issue, then open the next

Use when a run must be followed by a repository action (merge, close, start the next ship) without a human in the loop. A cron script drives it; the design points below are what make that safe.

## `archon-ship` never merges — plan for that

The ship pack's tail is `deliver__await-checks` → `deliver__flip-ready` → `deliver__outcome` → `outcome`. There is **no merge node**, deliberately: the prompt de gebruiker uses forbids the agent from merging or deploying. So "finish the issue" means *the agent stops at a ready-for-review PR* and a separate step merges it.

Closing an issue is normally a consequence of merging, not a separate action: check the PR body for `Closes #<n>`. If it is there, `gh pr merge` closes the issue and there is no need to touch the issue directly. Merging by hand and closing the issue separately would drop the work.

## Only branch-protection-required checks may gate a merge

Gate on exactly the contexts main requires, which you can read at runtime:

```bash
gh api repos/<owner>/<repo>/branches/main/protection \
  --jq '.required_status_checks.contexts[]'
```

Everything else is informational. Third-party review bots (Greptile Review and friends) routinely sit at `IN_PROGRESS` for a long time or fail on their own account; treating them as gating blocks the merge forever. Classify each check into three buckets: required-and-green → proceed; required-and-pending → wait, do not fail; required-and-red → stop loudly. Report non-required failures as a note only.

`required_status_checks.strict: true` means the branch must be current with main. If a merge fails with *behind* / *not up to date*, run `gh pr update-branch` and retry once.

## A failed run looks identical to a run awaiting resume

A run that failed and is scheduled for resume sits at `failed` — the same status as a run that is genuinely dead. A watcher that treats `failed` as terminal fires its failure message immediately, before the resume has even happened.

Fix: have the resume step write an outcome marker, and require the marker before believing a terminal status.

```bash
# resume script, on every terminal path
printf 'resumed %s\n'       "$(date -u +%FT%TZ)" > "$STATE/archon-resume-<issue>.outcome"
printf 'skipped-quota %s\n' "$(date -u +%FT%TZ)" > "$STATE/archon-resume-<issue>.outcome"
```

The watcher then distinguishes: no marker → still waiting for the resume, stay silent; `resumed` → a terminal status is real, report it; `skipped-quota` → report once (flag it in state so it does not repeat) and keep polling, because a manual resume later should still let the chain continue.

`status: completed` is the success value; `outcome` is usually `null` even on success, so never gate on `outcome` alone.

## Cron environment differs from an interactive shell

Verified by probing: the cron runner has `HOME=/opt/data/profiles/dev-builder/home` (not the shell's HOME), while `gh` keeps its auth under `GH_CONFIG_DIR=/opt/ai-tools/config/gh`. A script that relies on `~/.config/gh` authenticates as nobody.

Set the variables explicitly instead of sourcing `/opt/ai-tools/config/shared/env.sh` — that file runs `set -euo pipefail`, which would silently turn a script written with `set -uo pipefail` into a fail-fast one:

```bash
export PATH="/opt/ai-tools/bin:$PATH"
export GH_CONFIG_DIR="${GH_CONFIG_DIR:-/opt/ai-tools/config/gh}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/opt/ai-tools/config/xdg}"
```

Prove the cron environment before trusting it: create a throwaway job with `deliver='local'`, `no_agent=true`, run it once, then read `~/profiles/dev-builder/cron/output/<job_id>/*.md`. Check binary resolution, `gh auth status`, and an SSH hop. Remove the job with `action='remove'` (`delete` is not a valid action).

## Reuse the issue's own run as the template for the next one

The launched run stores the exact prompt in `user_message`, retrievable via `GET /api/workflows/runs/<id>`. Take it, swap the issue number, and you inherit the project's real conventions (verify commands, review loop, merge prohibition) instead of inventing a prompt.

Give the next run a clean base: `git fetch origin --prune && git checkout main && git pull --ff-only` in the workspace `source` dir, then confirm the previous PR's merge commit is actually there before starting:

```bash
git merge-base --is-ancestor <mergeCommitOid> HEAD && echo ANCESTOR=yes || echo ANCESTOR=no
```

Without that check a silent pull failure starts the next run on a stale main.

## Never use `sh -lc` for `docker exec` into Archon

This burned a whole run. Archon's script nodes resolve their runtime as a bare command name — `bun` for `.ts`, `uv` for `.py` (`dag-executor.ts`: `cmd = 'uv'` / `cmd = 'bun'`, no configurable path). The container's own PATH includes `/opt/ai-tools/bin`, where `uv` lives, so this works — **but only for a non-login shell**:

```bash
docker exec archon sh -c  'echo $PATH'   # /opt/ai-tools/bin:/opt/ai-tools/work/npm-prefix/bin:…  ← good
docker exec archon sh -lc 'echo $PATH'   # /usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games  ← uv GONE
```

`/etc/profile` ends with an unconditional `export PATH=…` that wipes everything else. A detached run launched through `sh -lc` inherits that stripped PATH for its entire life, so every `.py` script node dies with:

```
Script node 'fix__assert-changed' failed [exit ENOENT]: Executable not found in $PATH: "uv"
```

Symptom that makes this confusing: the run gets *almost* to the end. `bun` nodes are fine (`/usr/local/bin/bun` is baked into the image), so the failure lands on the first `.py` node — and the bundled sdlc pack's tail is all `.py` (`assert-changed.py`, `gate-green.py`, `gate-ready.py`, `check-ci.py`, `outcome.py`, …). A run resumed this way can look like a quota or flake failure when it is purely inherited PATH.

Rules:
- Launch Archon CLI work with `docker exec … sh -c`, never `sh -lc`.
- Belt and braces: prepend `export PATH=/opt/ai-tools/bin:/opt/ai-tools/work/npm-prefix/bin:$PATH;` inside the `sh -c` payload.
- Diagnose PATH always without `-l`. A `sh -lc` probe reports a PATH the real process never sees.
- The official image ships `bun` in `/usr/local/bin` but **not** `uv`, even though the bundled pack requires it. `/usr/local/bin` is root-owned and not writable as appuser, so in-image install is not an option — the mounted `/opt/ai-tools/bin` plus a correct PATH is the fix.

## Resuming a quota-failed run (reusable)

`scripts/archon-resume-run.sh <RUN_ID> <WORKTREE>` polls `ordinaryUsageAllowed` and resumes detached once the window reopens. Poll attempts and sleep are overridable (`RESUME_POLL_ATTEMPTS`, `RESUME_POLL_SLEEP`) so the skip path is testable in seconds instead of 25 minutes — test it that way, and confirm it writes `skipped-quota` and consumes nothing before trusting it.

The cron can only pass a **script name**, not arguments, so each run needs a thin wrapper holding its `RUN_ID` and `WORKTREE` (e.g. `archon-resume-ship186.sh`) that `exec`s the generic script. Create the cron with an explicit one-shot schedule at the reset instant (`in <N>m`, repeat 1), not a recurring one.

Get `WORKTREE` from the run record (`GET /api/workflows/runs/<id>` → `working_path`), never by guessing a path convention — this project's run used `worktrees/archon-ship-<ts>` while the older one used `worktrees/archon/thread-<hash>`, and a wrong path fails the resume.

## State machine, not one long script

Keep the phase in a small JSON file and make every phase idempotent; the cron re-enters the same script every tick. Phases used here, in order: `wait_resume` → `merge` → `sync` → `start186` → `watch186` → `done`, plus a terminal `stopped_failed`. Each phase prints only when it has news, so empty stdout means silence on Telegram. Report the first occurrence of a pending gate and then go quiet — a naive "print the blocker every tick" turns into a message every 15 minutes.

Starting the next run needs the quota it will actually consume. Check the Codex window right before launching and stay silent while it is exhausted, so the chain naturally picks up the next reset instead of failing the new run at its first node.
