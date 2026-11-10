---
name: containerized-agent-operations
description: "Use when containerized agent/provider runs fail."
version: 1.0.0
author: Hermes Agent
license: MIT
created_by: agent
metadata:
  hermes:
    tags: [containers, agents, providers, authentication, oom, diagnostics]
---

# Containerized Agent Operations

## When to Use

Use this skill when a coding-agent or provider runtime inside Docker/TrueNAS reports authentication failures, generic provider/transport errors, unexplained process exits, or failures under memory pressure.

## Workflow

1. **Match the server identity**
   - Inspect the running server process owner, UID/GID, executable, HOME, and credential path.
   - Run provider probes with that exact UID/GID and wrapper executable. `docker exec` defaults to root and can create mode-600 credentials the app cannot read.
   - Compare credential owner, numeric IDs, mode, inode, and mount path before changing permissions.

2. **Prove authentication end to end**
   - Do not trust an auth-status command alone; it may only prove that a credential file exists.
   - Send a minimal deterministic provider request as the app UID.
   - If it succeeds, stop changing credentials: the remaining fault is session, adapter, tool, or resource related.

3. **Correlate the exact failed turn**
   - Inspect the newest provider log by modification time and its terminal events.
   - If the app keeps canonical SQLite state, query thread, run, provider-session, and provider-turn projections for statuses, timestamps, and terminal failure objects.
   - Distinguish a resumed native session that failed before login from a genuinely new provider session.

4. **Check container resource pressure**
   - Read cgroup `memory.current`, `memory.peak`, `memory.max`, and `memory.events`; host-level free memory does not override a container limit.
   - Rising `oom`/`oom_kill` counters plus an agent-runtime OOM event prove that Linux killed the provider subprocess, even when the UI only says `Provider turn failed`.
   - Inventory memory consumers by RSS, process group, command, and age before stopping anything or raising the limit.

5. **Restart only at a clean boundary**
   - Check for active provider processes/turns first. A restart interrupts non-persistent sessions and creates a transport error that can hide the original failure.
   - After restart, verify the server endpoint/version, execute a short provider turn, and read back the run status.
   - Preserve and inspect partially modified worktrees after a provider crash; tool execution may have changed files before the terminal failure.

## Standing rules

- Treat generic UI errors as summaries, not root causes.
- Never repeat login after a real provider request succeeds as the app UID.
- Never kill large workloads solely because they consume memory; confirm they are stale or obtain the user's decision.
- Treat `chmod: Operation not permitted` on a mounted dataset as a mount/capability clue. Read `stat` first; if owner and mode already match the app identity, continue verification instead of forcing chmod.

See `references/provider-runtime-diagnosis.md` for commands and the evidence-to-action decision table.
