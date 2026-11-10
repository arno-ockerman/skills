# Herdr agent orchestration (terminal multiplexer for coding agents)

Herdr organizes terminals into workspaces/tabs/panes, recognizes coding agents in panes, and exposes `herdr` CLI + socket API to control them — locally and on saved SSH machines. Hermes Agent is a supported kind (session-identity integration). Reference for driving agents from/with Herdr and for de gebruiker's TrueNAS workbox.

Distilled from herdr v0.9.x docs and the official `herdr` skill. Check `herdr --help` / `herdr <group>` on the installed binary for exact syntax.

## Safety gate

Only control a Herdr session when running **inside** a Herdr-managed pane. If `test "${HERDR_ENV:-}" = 1` fails, stop — do not inspect or control the focused session from outside Herdr.

## Core vocabulary

- **Pane** = terminal slot (id `w1:p1`); holds a shell, process, or agent.
- **Agent** = recognized coding agent occupying a pane, addressed by unique live name (`[a-z][a-z0-9_-]{0,31}`) or pane id.
- States: `idle`/`done` (ready for input), `working`, `blocked` (approval/question UI), `unknown` (present but unclassified — NOT proof of completion).

## Launch & drive an agent

`agent start` requires an existing interactive shell pane; it never creates/splits layout.

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane_id=$(printf '%s\n' "$split" | jq -r '.result.pane.pane_id')
herdr agent start reviewer --kind codex --pane "$pane_id" -- -m gpt-5.4
herdr agent prompt reviewer "Review the current diff" --wait --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 120
herdr agent send-keys reviewer esc   # logical keys, validated before writing
```

Supported kinds include `codex`, `claude`, `opencode`, `hermes`, plus more; pass native agent args after `--`. Good: `herdr agent start hermes-helper --kind hermes --pane <id>`.

- `agent prompt` submissions honor bracketed-paste; `--wait` settles on idle/done/blocked (add `--until <state>` for exact).
- A `timeout`/`agent_prompt_stalled` result does **not** prove the prompt was delivered — `agent read` first, never blind-resubmit.
- For full-screen agents (Claude Code, OpenCode), transcript history may live in the alternate screen; ask the agent to write a file path and read it as fallback.

## Ordinary commands in a pane

```bash
herdr pane run <pane-id> "just test"
herdr pane wait-output <pane-id> --regex "passed|failed" --timeout 120000
herdr pane read <pane-id> --source recent-unwrapped --lines 120
```

Prefer `--source recent-unwrapped` for logs/transcripts. Parse IDs from JSON responses, never from sidebar order.

## Remote SSH machines

Saved machines are driven with a global `--machine` prefix on discovery AND every later command; remote paths must be absolute or `~/`.

```bash
herdr --machine <saved-label> agent list
herdr --machine <saved-label> agent prompt <remote-name> "status?" --wait --timeout 120000
```

Machine API forwarding never installs/starts the remote server. IDs/agent names are machine-scoped; a TUI machine selection does NOT retarget CLI commands. `herdr status` check before relying on new server features.

## de gebruiker's TrueNAS workbox

- `herdr-workbox` container: Ubuntu 24.04, Herdr v0.9.0, single user `agent` (UID/GID 568), SSH-only (no password/root), **no Docker socket mounted**, port `2223`. Shared datasets mounted at `/opt/project`, `/opt/ai-context`, `/opt/ai-tools`; shared CLI wrappers on `/opt/ai-tools/bin`.
- Reach it: `ssh -p 2223 agent@<nas-ip>`, then `cd /opt/project/<repo>` and run `herdr`. Verify `id`, `herdr --version`, `claude --version`, `test -w /opt/project`.
- **Authorized keys** come from `SSH_PUBLIC_KEYS` in the compose YAML (public keys ONLY — never a private key). `agent start` fails-fast (exit 64) if no valid key is present.
- To let Hermes drive the workbox, add Hermes' public key (e.g. `~/.ssh/…pub` / the profile's `ssh/…pub`) to `SSH_PUBLIC_KEYS` and redeploy via TrueNAS Apps. This is the single access gate between Hermes and the workbox.
- The workbox bind-mounts the same `/opt/ai-tools` as Hermes, so Hermes and Herdr share one Claude/Codex quota window — schedule together, not concurrently, for heavy runs.

## Pitfalls

- Never run bare `herdr` for discovery — it launches/attaches the TUI; print command groups explicitly.
- Never kill the main Herdr process or `server stop` an active shared session; use named/test sessions for isolated experiments.
- Do not `workspace close` anything you did not create.
- `herdr --machine` selects a *saved profile label*, not an arbitrary hostname; without `--machine` CLI commands keep using the inherited local session.
