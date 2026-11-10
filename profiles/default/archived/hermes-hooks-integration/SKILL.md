---
name: hermes-hooks-integration
description: Use when wiring Hermes lifecycle events to external systems.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, hooks, lifecycle, integration, webhooks, events, state.db]
    related_skills: [hermes-agent]
---

# Hermes Hooks Integration

Wire Hermes lifecycle and tool events to an external system — a task board, a
CI pipeline, a webhook receiver, a second agent — with **zero patching**. Hermes
already ships a plugin-hook manager that fires named events (`on_session_start`,
`on_session_end`, `pre_tool_call`, …); you just declare handlers in `config.yaml`.

This is the answer to "make Hermes create/update a task in my board every time I
give a profile a job, and show it as in-progress while it works."

## Two mechanisms — pick one

| | Shell hooks (`hooks.<event>`) | Outbound webhooks (`hooks.outbound`) |
|---|---|---|
| Runs | A local command you specify, JSON piped to stdin | An HTTP POST to a URL you specify |
| Timing | Synchronous, inside the agent loop (bounded by `timeout`) | Fire-and-forget via an in-process queue + worker thread |
| Can it influence flow? | Yes — stdout JSON can block/modify (`pre_tool_call`) | No — notify-only, can never block a tool call |
| Needs a long-running service? | No (script exits) | Yes (something must receive the POST) |
| Secret signing | n/a | Optional HMAC `X-Hermes-Signature-256` |
| Best for | Calling an API directly from a short script | Pushing events to CI/dashboards/other agents |

For a board/tracker integration, **shell hooks + a small script is usually simpler** — no service to keep alive.

## Config shape

```yaml
# Shell hooks — keyed by event name; each entry is {command, matcher?, timeout?, fail_closed?}
hooks:
  pre_llm_call:
    - command: "/opt/ai-tools/bin/my-bridge.py --profile dev-builder"
      timeout: 10
  on_session_end:
    - command: "/opt/ai-tools/bin/my-bridge.py --profile dev-builder"
      timeout: 10

# Outbound webhooks — the reserved `outbound:` sub-key (not an event)
hooks:
  outbound:
    - url: "https://ci.example.com/hermes-events"
      events: [on_session_end, subagent_stop]
      secret_env: HERMES_OUTBOUND_WEBHOOK_SECRET   # preferred over inline `secret`
      matcher: "terminal|delegate_task"             # only for pre/post_tool_call
      timeout: 10
      name: ci-notify
```

Reserved sub-keys under `hooks:` that are **not** event names: `outbound`,
`output_spill`. The hook command is `shlex.split`-ed, so `--profile X` reaches the
script as argv — that's how you tell the script which profile fired (each profile
has its own `config.yaml`).

## Wire protocol

Shell-hook stdin (same shape as the outbound-webhook POST body):

```json
{"hook_event_name": "post_tool_call", "tool_name": "terminal",
 "tool_input": {"command": "..."}, "session_id": "20260909_111307_2bfe13c4",
 "cwd": "/opt/ai-context", "extra": {"status": "ok", "duration_ms": 412}}
```

`extra` carries every kwarg that isn't a top-level key. Top-level keys:
`tool_name`, `args`(=tool_input), `session_id`, `parent_session_id`.

Key events and their `extra` fields (the ones you'll actually use):

- `pre_llm_call` → `extra: {user_message, is_first_turn, conversation_history, task_id, turn_id, model, platform}`. **The one event that carries the actual task text** (`user_message`). Use it to CREATE the remote item on the first turn (`is_first_turn`), not `on_session_start`.
- `on_session_start` → `extra: {model, platform}`. **No task text AND `state.db` hasn't committed the title/first-message yet at this instant** — enrichment returns empty, so the item lands in the wrong bucket if you create it here.
- `on_session_end` → `extra: {task_id, turn_id, completed, interrupted, model, platform}`.
- `post_tool_call` → `extra: {result, status(ok|error|blocked), error_type, error_message, duration_ms, task_id, tool_call_id, turn_id}`. Use this for "agent is actively working".
- `pre_tool_call` → `tool_name` + `tool_input`; stdout JSON `{"action":"block","message":"..."}` or exit code 2 blocks it.
- `subagent_stop` → `extra: {child_session_id, child_role, child_summary, child_status, duration_ms}`.

Full event catalog: `VALID_HOOKS` in `hermes_cli/plugins.py` (includes `pre_llm_call`,
`post_llm_call`, `on_stream_*`, `pre_verify`, `pre_gateway_dispatch`, kanban lifecycle
hooks, …). Shell hooks support everything except `transform_api_error_classification`
(`SHELL_UNSUPPORTED_HOOKS`).

## Enriching events from state.db

`on_session_start` gives you only `session_id` — get the title and the user's actual
task from the profile's SQLite session store (WAL mode; safe to read concurrently):

```sql
-- path: /opt/data/profiles/<profile>/state.db  (de gebruiker's layout)
SELECT title, cwd FROM sessions WHERE id = ?;                        -- may be NULL early
SELECT content FROM messages WHERE session_id = ?
  AND role = 'user' AND content IS NOT NULL ORDER BY id LIMIT 1;     -- first user message = the task
```

`sessions` columns of interest: `id, title, cwd, profile_name, started_at, last_activity_at`.
`messages`: `id, session_id, role, content` (ordered by `id`). Read with
`sqlite3.connect("file:...?mode=ro", uri=True, timeout=5)`.

## The bridge-script pattern (worked example)

1. One script, invoked as `script.py --profile <name>`; the profile is carried in the hook command.
2. `pre_llm_call` (first turn): **create** the remote issue with title = `extra.user_message`, status `in_progress`; record `session_id → issue_id` in a local `state.json`. Gate on "no issue recorded yet" (not `is_first_turn` alone) so later turns and resumed sessions don't double-create.
3. `post_tool_call` (optional): ensure `in_progress` — only needed if you create in `todo` first.
4. `on_session_end`: set `done`, optionally refresh the title from `state.db` (committed by now).
5. Always `exit 0`; log to stderr. Never let a DB read or network error crash the script.

A ready-made, working implementation ships at `/opt/ai-tools/bin/multica-bridge.py`
(de gebruiker's env) with a matching `multica-sync.py` that mirrors the board back to a
Markdown file. See `references/multica-api.md`.

## Pitfalls

- **`on_session_start` has no task text, and `state.db` hasn't committed it yet either.** Enriching at that exact moment returns empty (title + first user message both NULL), so a keyword-router falls through to its fallback bucket. Create the item from `pre_llm_call`'s `extra.user_message`; read `state.db` only on `on_session_end`, when the title IS committed.
- **`sessions.cwd` is often NULL** in gateway sessions — don't use it as your primary project-detection signal.
- **Shell hooks are synchronous in the agent loop.** Keep them fast; don't block on slow network I/O (outbound webhooks are the async option). Set `timeout`.
- **Consent allowlist.** Shell hooks won't fire until approved (`~/.hermes/shell-hooks-allowlist.json`). Headless gateways never see the TTY prompt — set `hooks_auto_accept: true` (or `HERMES_ACCEPT_HOOKS=1`) or the hook is silently skipped.
- **Exit codes:** non-zero just logs a warning on most events; exit 2 on `pre_tool_call` BLOCKS the tool. Don't accidentally exit 2.
- **No token/credential in the config file** if the repo auto-syncs to GitHub — keep secrets in a `0600` file or env var, not in the hook config.
- **de gebruiker's container:** `write_file` is gated to `HERMES_WRITE_SAFE_ROOT=/opt/data`; `/opt/ai-tools` and `/opt/ai-context` are outside it. Stage under `/opt/data`, then `install`/`mv` to the target via the terminal tool (the shell can write anywhere the `hermes` user can).
- **Hooks read once at startup** — after editing `hooks:` config, restart the profile's gateway. From inside the Hermes container: `kill -TERM <pid>` of the `hermes -p <profile> gateway run --replace` process — s6 auto-restarts it (verified; `s6-svc -r /run/service/gateway-<profile>` as the `hermes` user did NOT restart it).

## Verification

- `python3 -m py_compile <script>` before wiring it into a live profile.
- Dry-run against a real payload: `printf '%s' '{"hook_event_name":"on_session_start","session_id":"<real id>"}' | script.py --profile <name> --dry-run`.
- `hermes hooks list` and `hermes hooks doctor` (CLI) inspect/test configured hooks without firing them.
