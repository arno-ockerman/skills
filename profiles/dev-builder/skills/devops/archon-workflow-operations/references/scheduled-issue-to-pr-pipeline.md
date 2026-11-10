# Scheduled Issue-to-PR Pipeline (unattended)

For a cron job that picks GitHub issues and drives them to a reviewed PR through Archon with no human in the loop.

## Job contract to write into the prompt

- **One issue per run.** Prevents branch conflicts, duplicate PRs, and uncontrolled PR volume.
- **Eligible** = open issue carrying the ready label. Exclude issues that already have an open PR, an active Archon run, a declared blocker, or a parent/umbrella whose children are still open. Prefer the oldest eligible leaf issue.
- Read the full issue body **and comments** and sweep for duplicate PRs before launching — the body is a snapshot, comments carry the live state.
- Never merge, deploy, force-push, or mutate production secrets. The PR body carries `Closes #NNN`; that reference is what closes the issue, not the merge action.
- Cap the scope: if no eligible issue exists, report the reason and stop instead of inventing work.
- The prompt must be self-contained (fresh session, no chat context) and must name the repo path, the `GH_CONFIG_DIR`, the gh wrapper path, and the SSH alias used to reach the Archon host.

## Launch and read back through the internal API

Run the server API from inside the Archon container; the web API is reachable but the Docker runtime is reached over SSH.

```text
POST /api/workflows/<workflow>/run
  { conversationId, message, inputs: { target: <issue url>, publish: 'true', errors: 'auto' } }
```

**Bind the codebase first.** A fresh random-UUID `conversationId` in the run payload creates a bare web conversation with `codebase_id: null`; the run is accepted (`{"accepted":true,"status":"started"}`) but never executes — no agent turn, no worktree, no run record (health stays `runningWorkflows:0`). Prior successful launches used console-created conversations (`web-<ts>-<rand>`/`web-worker-<ts>-<rand>`) bound to the codebase. For a headless launch, first `POST /api/conversations` with `{codebaseId: <id>}` (returns `conversationId` of form `web-<ts>-<rand>`, `id` = DB UUID), then dispatch the run with that `conversationId`. Verify with `GET /api/conversations/<id>` that `codebase_id` is set and `cwd` is a worktree path, and health shows `runningWorkflows:1` with `activeConversationIds` populated. The `runs` list only returns completed runs and does not show in-progress work — read health + the conversation record instead."})]

- `{"accepted":true,"status":"started"}` is acceptance, **not** success.
- Read the run back with `GET /api/workflows/runs?limit=200` and filter client-side. `GET /api/workflows/runs/<id>` can return an empty `{"metadata": {}}` while the run is alive.
- Before launching, query live runs and refuse to start when any run of the same workflow for that codebase is queued/running/paused — otherwise two runs collide on the same worktree.
- Record the run id, status, and working path in the report so the user can watch it.

## Triage may legitimately answer NO_ACTION

A triage node can return contract `NO_ACTION` with a close-style label and empty proposed edits. That is not a failure. Handle it as repository housekeeping:

1. Verify the claim against live GitHub yourself — does the merged PR exist, is the behaviour present on the current base?
2. If already delivered, close the issue with a comment naming the merged PR and commit as evidence.
3. Do **not** force an implementation run onto a `NO_ACTION` issue; that burns quota to reproduce an existing PR.

## Schedule at local midnight without DST drift

Schedules run in UTC, so "midnight local time" moves by an hour when DST flips. Resolve it with a monitor instead of an offset chosen by hand:

1. Add a script under the profile's `scripts/` directory that prints only today's local calendar date:

```python
from datetime import datetime
from zoneinfo import ZoneInfo

print(datetime.now(ZoneInfo("Europe/Brussels")).date().isoformat())
```

2. Schedule the job twice across the transition — `0 22,23 * * *` for Europe/Brussels (UTC+2 summer, UTC+1 winter) — so one of the two fires is always local midnight.
3. Attach the date script as the job's `monitor`. Monitor output is hashed: unchanged output silently skips the agent run, changed output wakes it. The first fire of a local day runs the pipeline and the second is a no-op, which yields exactly one run per local day in both summer and winter.
4. The path is relative to the profile's `scripts/` dir; an absolute path is rejected.
5. A monitor's **first tick always runs** as baseline. Seed the monitor with the previous day's date so the pre-midnight baseline does not itself fire a run.

Verify the gate before trusting it: run the date script, compare against the seeded value, and confirm the two differ on the day of the transition.

## Choose the window from the user's intent

When the user asks for an overnight run, they are usually protecting a *daytime provider quota* (Codex/Claude windows shared with the interactive agent). Confirm the local hour they mean, and state when the first run lands in their local time — do not report the cron expression as if it were the answer.

## Gate a follower job behind a live prerequisite

A second job that consumes the first job's output (for example an error-tracker intake that files the issues this pipeline then implements) is created **paused** with an explicit `paused_reason` naming the unmet prerequisite, and is resumed only once that prerequisite is demonstrably live. Order the two jobs so the producer runs before the consumer's pick-up window. Report per-run counts (collected, deduplicated, reproduced, created, carried over) so nothing is silently dropped.

## Reporting

Read the job back before calling it active — a create response may not carry the final job id. Report the job id, the schedule, when it next fires in local time, and the last status.
