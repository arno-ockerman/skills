---
name: coding-agent-control-surfaces
description: "Use when installing or supervising T3 Code on TrueNAS."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [t3-code, control-surface, coding-agent, container, s6, supervision, truenas]
    related_skills: [coding-agents, hermes-agent, shared-agent-cli-runtime]
---

# Coding-Agent Control Surfaces

## When to Use
- Installing or connecting T3 Code (or another coding-agent GUI/frontend) on the TrueNAS/Hermes host.
- Making the surface reachable from other devices without installing anything client-side.
- Keeping the surface running under s6 in the container (surviving crashes and restarts).
- Wiring provider subscriptions (OpenCode Go, DeepSeek, etc.) into the surface.

A control surface (T3 Code, and future GUIs/frontends of the same kind) orchestrates CLI coding agents — Codex, Claude Code, OpenCode — but does NOT replace them. Install and supervise the surface in the shared AI container; user devices connect only via browser/tunnel. That keeps providers, credentials, and repos on the server and needs nothing installed on the work laptop (no admin rights required).

## Role split (keep these boundaries)
- **Control surface (T3)** = planning threads, model/provider choice, remote cockpit.
- **CLI agents (Codex/Claude/OpenCode)** = implementation.
- **Hermes** = personal/ops layer (Telegram, memory, cron, profiles).
The control surface is NOT the source of truth — keep project context in a git-backed context repo (e.g. `/opt/ai-context`).

## Install — user-local into the shared tool root
Inspect the installer before piping it blind:
```bash
curl -fsSL https://t3.codes/install.sh -o "$TMPDIR/t3-install.sh"
sha256sum "$TMPDIR/t3-install.sh"   # then read_file it before running
```
Install into the shared tree so every app (Hermes/OpenClaw/T3/Archon) sees it on PATH:
```bash
T3CODE_HOME=/opt/ai-tools/config/t3code \
T3CODE_INSTALL_BIN_DIR=/opt/ai-tools/bin \
sh "$TMPDIR/t3-install.sh"
/opt/ai-tools/bin/t3 --version
```
The default install target (`~/.t3`, `~/.local/bin`) is wrong for this environment — it is not on the shared PATH and gets hidden from other tools.

## Headless connect (OAuth device flow)
```bash
T3CODE_HOME=/opt/ai-tools/config/t3code t3 connect link --headless
```
- It prompts to download the relay client (cloudflared) — answer `y`.
- It prints a URL + `user_code`; the user confirms in a browser. Codes expire in ~10 min.
- Run it `background=true, pty=true`, submit `y`, then wait for the real success line before declaring done (watch patterns like `Linked`/`https://` can fire on DB names, not the actual event).
- On expiry, re-run `link --headless` for a fresh code.
- Verify: `t3 connect status` → "Other devices can reach this machine · Tunnel connected".

## Run the server
```bash
T3CODE_HOME=/opt/ai-tools/config/t3code t3 serve --host 127.0.0.1 --no-browser <project-root>
```
- Bind `127.0.0.1` only; expose via the managed tunnel, never a public port.
- Add projects one at a time: `t3 project add <path> --title "<name>"`.

## Supervise under s6 (see references/s6-supervision.md)
`t3 service install` writes a systemd/user unit that does NOT survive a container restart. Register a dynamic s6 service under `/run/service` instead. Full recipe (staging dir + atomic `mv` + `s6-svscanctl -a`) is in `references/s6-supervision.md`.

## Provider & key wiring
- **OpenCode Go and DeepSeek are not separate providers** — they surface through the OpenCode provider, which T3 leaves disabled by default.
- Keys live in `/opt/ai-tools/config/opencode/token.env` (`OPENCODE_API_KEY`, `DEEPSEEK_API_KEY`), sourced only by the `/opt/ai-tools/bin/opencode` wrapper. Verify what the CLI actually sees with `opencode auth list`; never print or request secret values in chat.
- For OpenCode v2 Console authentication, prefer the device flow: run `opencode auth login opencode --method device`, expose the printed URL and one-time code to the user, wait for `Connected to OpenCode Console`, then restart/reload the T3 runtime before probing it. A repeated login does not renew an already-expired API key; device authorization creates a fresh stored credential.
- To surface them in T3: **Settings → Providers → OpenCode → enable**. The binary is already on PATH. Codex/Claude auto-enable + authenticate when their CLI is installed and logged in.
- Claude Code may use a different `HOME` from T3's direct SDK process than the shared `/opt/ai-tools/bin/claude` wrapper. If T3 reports an expired OAuth token while the wrapper reports logged in, align the state path under `/opt/data/home/.claude` with `/opt/ai-tools/config/claude/home/.claude` before reauthenticating; then run `claude auth login --claudeai` and verify with a minimal live request.
- Model IDs rotate — fetch the live model list rather than hardcoding names. Treat provider authentication, model availability, and account quota as separate checks: a valid Console credential can still return HTTP 402 when the Console account has insufficient funds, while an `opencode-go/*` model may work through the Go subscription.
- Validate the selected model path with a minimal live request after authentication. Use a low-cost `opencode-go/*` model for the smoke test when the Console account may be unfunded; report quota/funds errors separately from authentication failures.

## Diagnosing provider state (read disk, don't fight the WebSocket UI)
Provider enablement and probe results live on disk under `T3CODE_HOME` (`/opt/ai-tools/config/t3code`):
- `userdata/settings.json` → `providerInstances.<id>` holds `{driver, displayName, enabled}`; the Settings→Providers toggle writes here.
- `caches/<driver>.json` → the last probe: `status` (`ready`/`disabled`), `installed`, `version`, `auth.status`, `models[]` (each with a `subProvider` tag like `opencode-go/*`, `deepseek/*`, `opencode/*`), and `versionAdvisory` / `compatibilityAdvisory`.
- `status: ready` + `auth.status: authenticated` = working. Confirm there instead of re-clicking the UI or driving the API over WebSocket.
- `versionAdvisory.status: behind_latest` and `compatibilityAdvisory.status: graceful` are SOFT warnings, not blockers. The two advisories can disagree: `versionAdvisory` tracks the current train (e.g. latest 1.x), while `compatibilityAdvisory` may point at a different major train (e.g. "Use >=2.0.18") that a plain `opencode upgrade` will not reach.

## Recovery recipes

### Codex App Server transport errors
When T3 reports `read-process-exit-status` or cannot ensure a Codex provider thread, restart the managed daemon and verify both versions:
```bash
export HOME=/opt/data CODEX_HOME=/opt/ai-tools/config/codex/home/.codex
/opt/ai-tools/bin/codex app-server daemon restart
/opt/ai-tools/bin/codex app-server daemon version
```
A healthy result shows `status: running`, an active socket, and matching/current managed app-server metadata. Do not diagnose this as an OpenCode key problem until the Codex daemon is independently healthy.

### OpenCode v2 smoke test
After device authorization and T3 restart, distinguish the layers in this order:
```bash
export HOME=/opt/data
/opt/ai-tools/bin/opencode auth list
/opt/ai-tools/bin/opencode models
/opt/ai-tools/bin/opencode run --model opencode-go/deepseek-v4.1-flash --format json 'Reply with exactly: T3-OpenCode-Go-OK'
```
- `Connected to OpenCode Console` proves credential enrollment, not paid-model quota.
- `opencode models` proves model discovery, not that the selected account can use every model.
- A successful `opencode-go/*` response proves the Go route; `opencode/*` may still fail with HTTP 402 if Console funds are exhausted.
- Keep API keys out of chat and logs; redact secret-like fields when inspecting config.

## Pitfalls
- `write_file` cannot write outside `HERMES_WRITE_SAFE_ROOT` (`/opt/data`) — `/run/service/...` is refused. Stage files under `/opt/data` then `install`/`mv` them into place via terminal.
- s6-supervise (root) chowns a service's `supervise/control` FIFO when a non-root process creates the service dir → `s6-svc` then fails "Permission denied" forever. Create the service dir atomically (see reference).
- Do not put a `down` marker on a service you want running — with a root-owned supervise dir the hermes user cannot `s6-svc -u` it back up.
- Never install or serve as root — it creates a separate identity/data dir from the hermes user and splits state.
- A provider "update" banner is cosmetic — `status: ready` + `authenticated` means the models already work; don't upgrade just to clear a `graceful` advisory. When the user does want a major-train migration (OpenCode 1.x→2.x to satisfy "Use >=2.0.18"), back up `/opt/ai-tools/bin/opencode-real` first and follow `references/opencode-2x-migration.md` — never `opencode upgrade`, which only walks the current major train (1.x → latest 1.x) and cannot reach 2.x.
- After migrating OpenCode to 2.x, `caches/opencode.json` transiently shows `models: []` + `auth.status: unknown` ("did not list any models yet"). The 2.x adapter inventories via a persistent server on first session, not the CLI (as 1.x did) — verify models exist with `opencode models`, then let T3 populate on the first OpenCode thread.
