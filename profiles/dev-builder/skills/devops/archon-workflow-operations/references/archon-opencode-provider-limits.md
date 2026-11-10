# Archon × OpenCode: provider testing that changes the routing plan

Use when assigning Archon work to the `opencode` provider (tiers, aliases, per-run `--model`) or testing whether the provider is usable for unattended runs. Revalidate the exact installed OpenCode version before routing production work: earlier tool-loop blockers were upstream bugs and may be fixed in current releases.

## Tier/alias assignment works, and is per-run overridable

The per-run override is the safe testing tool — it leaves config untouched:

```bash
archon workflow run archon-triage --cwd <repo> --no-worktree \
  --model medium=opencode/opencode-go/deepseek-v4-flash --detach --json "Triage issue #185"
```

Confirmed in one run's log (`run_model_overrides_applied` → `effective.medium`), with the node line reading `[triage::triage] Started (opencode/opencode-go/deepseek-v4-flash ← medium)`. Tier keywords make this work with zero YAML edits.

## But a workflow node on OpenCode hangs

Observed on the bundled `archon-triage` (2 nodes, `output_format` on both), `opencode-go/deepseek-v4-flash`, 0.10.1:

- 18 `bash` calls completed, then one `read` call was issued and **never completed**
- after that, every subsequent `bash` `tool_called` event carried **`tool_input: {}`** — empty arguments
- 5+ minutes with zero new events; the run stayed `running`

Those two symptoms are the open upstream bugs #3321 (tool calls lose arguments after a pending event) and #3332 (node hangs forever when OpenCode raises `permission.updated`). A `read` that never returns is consistent with an unanswered permission prompt.

These observations applied to OpenCode 0.10.1. Upstream #3321 was closed completed on 2026-03-24 and #3332 was fixed for 0.15.17; the current installation can therefore no longer be rejected solely from this old probe. On OpenCode 1.18.31, `opencode-go/deepseek-v4.1-flash` completed a real shell-tool turn successfully. Before unattended production routing, still run one embedded Archon workflow preflight that reads a file and executes a harmless shell command, because a standalone CLI turn does not prove Archon's event adapter and permission handling.

## Side-service gotcha: the title generator uses the default assistant

With every node tiered away from Codex, a run still made a Codex call: `provider.codex` → `thread_started` → usage limit → `turn_failed` → `service.title-generator msg=title.generate_empty`. The title generator resolves the **default assistant** (`assistants` / `defaultAssistant`), not the node's tier. During a Codex exhaustion this fails harmlessly (no conversation title), but it means "no node uses Codex" does not mean "no Codex calls happen".

## Cleaning up after probing the runtime

`releaseEmbeddedRuntime()` releases a **reference**; it does not stop the embedded server. Every separate process that calls `acquireEmbeddedRuntime()` leaves its own `opencode serve` behind — each ~300–470 MB RSS. My diagnostics left two orphans (347 MB + 298 MB) alongside the real run's server. After probing, list and kill them:

```bash
ps -eo pid,etimes,rss,args | grep '[o]pencode-real serve'
```

Age tells them apart: the run's own server is the young one. Kill the stragglers.

## Cancelling a hung detached run

`archon workflow cancel <id>` **refuses** while the detached process group is alive:

```
Error: Detached workflow process group <pid> is still running
```

Kill the group first, then cancel:

```bash
PG=$(ps -o pgid= -p <pid> | tr -d ' '); kill -TERM -"$PG"
```

After killing the group, `workflow cancel` does **not** work either — it reports `No live detached CLI owner is reachable for run <id> … (ENOENT)`. `archon workflow abandon <id>` is the command that releases the row (status → `cancelled`). So the recovery is: kill the process group, then `abandon`.

## Confirm the hang from the OpenCode server log

The embedded server keeps its own log, independent of Archon's events:

```bash
# in the container
cat $OPENCODE_HOME_DIR/.local/share/opencode/log/opencode.log
```

Archon's tool loop and this log agree to the millisecond, which is what turns "it hangs" into a root cause. A blocked node shows:

```text
message=evaluated permission=external_directory pattern=/…/artifacts/runs/<prevRunId>/* action.action=ask
message=asking id=per_… permission=external_directory patterns="[\"/…\"]"
```

and then the log simply stops — no `permission.replied`, no `session.idle`. `grep -c permission` plus the last few lines is enough to identify it. The trigger is ordinary: reading a *previous* run's artifacts sits outside the workflow `--cwd`, so it evaluates to `external_directory` → `ask` even in a headless detached run.

## The empty `tool_input` is total, not conditional

Upstream #3321 reads as "input is lost after a pending event", but observation says every call is affected: 19/19 tool calls in a run carried `tool_input: {}`, in both the run events and the persisted transcript at `/.archon/workspaces/<owner>/<repo>/logs/<runId>.jsonl`. The plausible mechanism is that Archon emits the normalized invocation from the `pending` snapshot and never reconciles it with the later `running`/`completed` payload — and every OpenCode call passes through `pending`, making the loss total. Practical consequence: when an OpenCode node hangs, the transcript cannot tell you which file or command it was blocked on; use the OpenCode log for that.
