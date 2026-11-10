---
name: kanban
description: "Hermes Kanban system: orchestrator decomposition playbook, worker lifecycle, task management, cross-agent collaboration. Use when coordinating multi-agent work through the Kanban board — creating tasks, routing to profiles, handling dependencies, and managing long-running collaborations."
version: 3.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
environments: [kanban]
metadata:
  hermes:
    tags: [kanban, multi-agent, orchestration, collaboration, workflow, task-management]
    related_skills: [hermes-agent, hermes-multi-profile-bots, shared-agent-cli-runtime]
---

# Kanban — Multi-Agent Work Orchestration

This umbrella skill covers the complete Kanban system for Hermes: the **orchestrator** decomposition playbook and the **worker** lifecycle/pitfalls. The core lifecycle (orient → work → heartbeat → block/complete) is auto-injected via `KANBAN_GUIDANCE` into every dispatched worker; this skill provides the deeper playbooks.

---

## When to Use Kanban (vs. delegate_task)

Create Kanban tasks when any of these are true:

1. **Multiple specialists needed** — Research + analysis + writing = three profiles
2. **Work must survive crash/restart** — Long-running, recurring, or important
3. **Human may interject** — Human-in-the-loop at any step
4. **Parallel subtasks** — Fan-out for speed
5. **Review/iteration expected** — Reviewer profile loops on drafter output
6. **Audit trail matters** — Board rows persist in SQLite forever

If *none* apply — it's a small one-shot reasoning task — use `delegate_task` instead or answer directly.

---

## Architecture

- **Orchestrator profile** — Plans, decomposes, creates tasks, assigns to specialists
- **Worker profiles** — Execute assigned tasks (one task per dispatch)
- **Dispatcher** — Runs in gateway, claims ready tasks, spawns workers
- **Board** — SQLite-backed, persists across sessions, supports dependencies (`parents=[]`), tenants, and goal_mode

---

## Part 1: Orchestrator Playbook

### Step 0: Discover Available Profiles

Before fanning out, ground the decomposition in profiles that actually exist:

```bash
hermes profile list                    # prints table of profiles on this machine
kanban_list(assignee="<name>")         # sanity-check a name (empty list = unknown)
# Or just ask: "What profiles do you have set up?"
```

Cache the result — re-asking every turn wastes tool calls.

### Step 1: Understand the Goal

Ask clarifying questions if ambiguous. Cheap to ask; expensive to spawn wrong fleet.

### Step 2: Sketch the Task Graph

Before creating anything, draft the graph out loud:

1. Extract lanes from the request
2. Map each lane to a discovered profile
3. Decide independence vs. gating
4. Create independent lanes as parallel cards (no parents)
5. Create synthesis/review cards with `parents=[...]`

**Example decomposition:**

```python
t1 = kanban_create(title="research: cost comparison", assignee="researcher", body="Compare AWS/GCP costs...")
t2 = kanban_create(title="research: performance comparison", assignee="researcher", body="Compare query latency...")
t3 = kanban_create(title="synthesize recommendation", assignee="analyst", body="Read T1+T2, produce recommendation", parents=[t1, t2])
t4 = kanban_create(title="draft decision memo", assignee="writer", body="Turn T3 into CTO memo", parents=[t3])
```

### Step 3: Create Tasks & Link

- Use real profile names from Step 0
- `parents=[...]` gates promotion — children stay `todo` until all parents `done`
- Create parent cards FIRST, capture IDs, then create children with those IDs
- Show the graph to the user before creating — let them correct profile assignments

### Step 4: Complete Your Own Task

If you were spawned as a task (e.g. planner assigned), mark done with summary:

```python
kanban_complete(
    summary="decomposed into T1-T4: 2 research lanes in parallel, 1 synthesis, 1 prose draft",
    metadata={"task_graph": {...}}
)
```

### Step 5: Report Back

Tell the user what you created in plain prose with actual profile names.

---

## Common Patterns

| Pattern | Structure |
|---------|-----------|
| **Fan-out + fan-in** | N research cards (no parents) → 1 synthesis card (all as parents) |
| **Parallel impl + validation** | 1 implementer + 1 explorer/researcher (independent) → 1 reviewer (parents=both) |
| **Pipeline with gates** | `planner → implementer → reviewer` each with `parents=[previous]` |
| **Same-profile queue** | N tasks, same assignee, no deps — dispatcher serializes |
| **Human-in-the-loop** | Any task `kanban_block()` → operator unblocks → respawns with comment thread |
| **Goal-mode (persistent worker)** | `kanban_create(..., goal_mode=True, goal_max_turns=15)` — judge re-checks after each turn |

---

## Anti-Temptation Rules (Orchestrator)

- **Do not execute the work yourself** — your toolset usually lacks terminal/file/web
- **For any concrete task, create a Kanban task and assign it** — every single time
- **Split multi-lane requests before creating cards** — one card per lane
- **Run independent lanes in parallel** — link only true data dependencies
- **Never create dependent work as independent ready cards** — use `parents=[]` at creation
- **If no specialist fits, ask the user** — do not invent profile names
- **Decompose, route, and summarize — that's the whole job**

---

## Pitfalls (Orchestrator)

| Pitfall | Fix |
|---------|-----|
| Inventing profile names | Always assign from Step 0 discovery; ask if unsure |
| Bundling independent lanes | Create separate cards for each outcome |
| Over-linking from wording | "Finally check X" may be parallel — link only when output is needed |
| Forgetting dependency links | Use `parents=[]` so implement/review can't run before inputs exist |
| Reassignment vs new task | Reviewer blocks → create NEW task linked from reviewer's task |
| Argument order for links | `kanban_link(parent_id=..., child_id=...)` — parent first |
| Pre-creating when shape depends on findings | Let synthesis task plan its own children after reading parents |

---

## Part 2: Worker Lifecycle & Pitfalls

### Workspace Handling

| Kind | Behavior |
|------|----------|
| `scratch` | Fresh tmp dir, yours alone — read/write freely, GC'd on archive |
| `dir:<path>` | Shared persistent directory — treat as long-lived state |
| `worktree` | Git worktree at resolved path — if no `.git`, run `git worktree add` first |

### Tenant Isolation

If `$HERMES_TENANT` set, prefix memory entries: `tenant: key` not bare `key`.

### Good Summary + Metadata Shapes

**Coding task:**
```python
kanban_complete(summary="shipped rate limiter — token bucket, keys on user_id with IP fallback, 14 tests pass", metadata={"changed_files": ["rate_limiter.py", "tests/test_rate_limiter.py"], "tests_run": 14, "tests_passed": 14, "decisions": ["user_id primary, IP fallback for unauthenticated"]})
```

**Code task needing review (review-required):**
```python
kanban_comment(body="review-required handoff:\n" + json.dumps({"changed_files": [...], "tests_run": 14, "diff_path": "/path/to/worktree", "decisions": [...]}, indent=2))
kanban_block(reason="review-required: rate limiter shipped, 14/14 tests pass — needs eyes on user_id/IP fallback choice before merging")
```

**Research task:**
```python
kanban_complete(summary="3 libraries reviewed; vLLM wins on throughput", metadata={"sources_read": 12, "recommendation": "vLLM", "benchmarks": {"vllm": 1.0, "sglang": 0.87}})
```

### Claiming Cards You Created

If your run produced new tasks via `kanban_create`, pass IDs in `created_cards`. Kernel verifies each ID exists and was created by your profile.

```python
# GOOD
c1 = kanban_create(title="remediate SQL injection", assignee="security-worker")
c2 = kanban_create(title="fix CSRF middleware", assignee="web-worker")
kanban_complete(summary="Review done; spawned remediations.", metadata={...}, created_cards=[c1["task_id"], c2["task_id"]])

# BAD — never invent IDs from prose, never claim cards another worker created
```

### Block Reasons That Get Answered Fast

Bad: `"stuck"` — human has no context.

Good: One sentence naming the specific decision. Longer context as a comment.

```python
kanban_comment(task_id=os.environ["HERMES_KANBAN_TASK"], body="Full context: IPs from Cloudflare but some behind NATs with thousands of peers. Keying on IP causes false positives.")
kanban_block(reason="Rate limit key choice: IP (simple, NAT-unsafe) or user_id (requires auth, skips anonymous endpoints)?")
```

### Heartbeats Worth Sending

Good: `"epoch 12/50, loss 0.31"`, `"scanned 1.2M/2.4M rows"`, `"uploaded 47/120 videos"`

Bad: `"still working"`, empty notes, sub-second intervals. Every few minutes max; skip for tasks under ~2 minutes.

### Retry Diagnostics

If `kanban_show` returns `runs: [...]` with closed runs, you're a retry. Check prior `outcome`:

| Outcome | Meaning | Action |
|---------|---------|--------|
| `timed_out` | Hit `max_runtime_seconds` | Chunk work or shorten |
| `crashed` | OOM or segfault | Reduce memory footprint |
| `spawn_failed` | Profile config issue (missing cred, bad PATH) | Block with specific ask |
| `reclaimed` | Operator archived task | Check status carefully |
| `blocked` | Prior attempt blocked | Read unblock comment in thread |

### Notification Routing

Add to `~/.hermes/config.yaml`:
```yaml
notification_sources: ['*']           # all profiles
notification_sources: ['default', 'profile-name']  # specific
```

---

## Do NOT (Worker)

- Call `delegate_task` instead of `kanban_create` — delegate_task is for short subtasks inside YOUR run
- Call `clarify` — you're headless, no live user. Use `kanban_comment` + `kanban_block` instead
- Modify files outside `$HERMES_KANBAN_WORKSPACE` unless task body says to
- Create follow-up tasks assigned to yourself — assign to the right specialist
- Complete a task you didn't actually finish — block it instead

---

## CLI Fallback (Human Operators)

| Tool | CLI Equivalent |
|------|----------------|
| `kanban_show` | `hermes kanban show <id> --json` |
| `kanban_complete` | `hermes kanban complete <id> --summary "..." --metadata '{...}'` |
| `kanban_block` | `hermes kanban block <id> "reason"` |
| `kanban_create` | `hermes kanban create "title" --assignee <profile> [--parent <id>]` |
| `kanban_link` | `hermes kanban link <parent_id> <child_id>` |
| `kanban_comment` | `hermes kanban comment <id> "body"` |

Use tools from inside agent; CLI exists for human at terminal.

---

## Recovery Actions (Dashboard)

When worker keeps crashing/hallucinating:

1. **Reclaim** — abort running worker, reset to `ready` (fast, ~15min claim TTL)
2. **Reassign** — switch to different profile, fresh worker spawn
3. **Change profile model** — edit `hermes -p <profile> model`, then Reclaim

Hallucination warnings appear when `created_cards` includes phantom IDs or prose references unresolvable `t_<hex>` IDs. Trail persists for debugging.