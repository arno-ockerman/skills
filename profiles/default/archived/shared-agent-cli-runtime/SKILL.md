---
name: shared-agent-cli-runtime
description: "Build and maintain a shared CLI runtime for multiple agents (Hermes, OpenClaw, others) with centralized auth, cache, workdirs, and wrapper-based execution."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [shared-runtime, cli, wrappers, auth, cache, hermes, openclaw, multi-agent]
---

# Shared Agent CLI Runtime

## Purpose

Use this skill when multiple agents on the same machine should share the **same external CLI tools**, **same authentication**, and **same cache/work directories** without forcing the agents themselves to share one global HOME.

Typical examples:
- Hermes + OpenClaw should use one `gh`, one `claude`, one `codex`
- auth should only be done once per tool
- updates should happen in one place
- binaries should be exposed from a stable shared root like `/opt/ai-tools/bin`

## Core design rule

**Do not try to force all agents onto one shared HOME.**

Instead:
1. Keep each agent's own profile/runtime semantics intact
2. Put shared tooling under a neutral root (for example `/opt/ai-tools`)
3. Expose tools through wrappers in `bin/`
4. Let the wrappers set `HOME`, `XDG_*`, cache vars, and tool-specific config dirs

This avoids conflicts between agent internals while still centralizing the external CLIs.

## Recommended layout

```text
/opt/ai-tools/
  bin/
  config/
    shared/
      env.sh
      doctor.sh
  cache/
  work/
```

Recommended substructure:

```text
bin/
  gh
  claude
  codex
  tool-env

config/
  shared/
  gh/
  claude/home/
  codex/home/
  git/
  npm/
  pip/
  uv/

cache/
  gh/
  npm/
  pip/
  uv/
  xdg/
  claude/
  codex/

work/
  tmp/
  repos/
  scratch/
  sessions/
  venvs/
  installs/
```

## Wrapper-first policy

Agents must execute the wrapper, not the underlying binary.

Good:
- `/opt/ai-tools/bin/gh`
- `/opt/ai-tools/bin/claude`
- `/opt/ai-tools/bin/codex`

Bad:
- `/usr/bin/gh`
- a random npm global path in a user home
- a tool binary hidden under one agent's private config dir

## Shared env file

Create a canonical env file such as:
- `/opt/ai-tools/config/shared/env.sh`

Wrappers should `source` it first.

That env file should usually define:
- `AI_TOOLS_ROOT`
- `PATH=/opt/ai-tools/bin:$PATH`
- `TMPDIR`
- `XDG_CONFIG_HOME`
- `XDG_CACHE_HOME`
- `XDG_STATE_HOME`
- package-manager caches like npm/pip/uv/go/cargo
- tool-specific homes or config roots (`GH_CONFIG_DIR`, `CLAUDE_HOME_DIR`, `CODEX_HOME_DIR`, etc.)

It should also `mkdir -p` the expected directory tree so wrappers are self-healing.

## Compatibility rule

If older wrappers or external tools already source an older env file path, keep a **shim**.

Example pattern:
- canonical file: `/opt/ai-tools/config/shared/env.sh`
- compatibility shim: `/opt/ai-tools/work/env.sh` that only sources the canonical file

This lets you migrate the structure without breaking existing wrappers or another agent like OpenClaw.

## Wrapper templates

### Tool with dedicated HOME

```bash
#!/usr/bin/env bash
set -euo pipefail
source /opt/ai-tools/config/shared/env.sh
export HOME="$CLAUDE_HOME_DIR"
mkdir -p "$HOME"
exec /real/path/to/tool "$@"
```
```

Use for tools that heavily rely on `HOME`.

### Tool with explicit config variable

```bash
#!/usr/bin/env bash
set -euo pipefail
source /opt/ai-tools/config/shared/env.sh
mkdir -p "$GH_CONFIG_DIR"
exec /real/path/to/tool "$@"
```
```

Use for tools like `gh` where a config env var can pin the auth/config location.

## Per-tool guidance

### gh
- Prefer `GH_CONFIG_DIR=/opt/ai-tools/config/gh`
- Keep wrapper stable, real binary separate if possible (`gh-real` pattern is fine)
- Authenticate via the wrapper only

### claude / codex / similar agent CLIs
- Give each tool its own HOME under `config/<tool>/home`
- Prefer wrapper-controlled `HOME` over trusting the ambient shell HOME
- Also give them a dedicated cache dir if the tool supports one; otherwise rely on `XDG_CACHE_HOME`
- **Share the binary, never the OAuth session.** A wrapper that points every agent at one
  `config/<tool>/home` also shares that tool's `auth.json`, and subscription-login refresh
  tokens are single-use — the agents then invalidate each other (HTTP 401). See
  `references/oauth-credential-sharing-pitfalls.md` before centralizing a Codex/Claude login.

### Python CLIs
- Put venvs under `work/venvs/<tool>`
- Expose only wrapper entrypoints from `bin/`
- Keep pip/uv caches under `cache/`

### Node/npm CLIs
- Avoid random user-home npm globals
- Prefer a shared install prefix under the shared runtime tree
- Still front everything with wrappers in `bin/`
- Global install with custom prefix: `npm install -g <tool> --prefix /opt/ai-tools` auto-links to `bin/`
- Examples installed this way: `supabase`, `vercel` (both symlink from `/opt/ai-tools/bin/` to `../lib/node_modules/<tool>/dist/...`)

## Verification checklist

After any setup or migration, verify all of the following:

1. `which <tool>` resolves to the shared wrapper path
2. `--help` works through the wrapper
3. auth/config lands under `config/`, not an agent-specific HOME
4. cache lands under `cache/`
5. temp/runtime artifacts land under `work/`
6. the same tool works from each participating agent runtime

## Troubleshooting patterns

### Wrapper exists but command is still not found
Usually PATH was not reloaded in the current shell or agent session.

Fix pattern:
1. add a shell bootstrap to source the shared env file
2. restart the shell / desktop agent / session
3. verify `which <tool>` again

### Existing data already lives in the shared tree
Do not wipe the tree and start over blindly.

Migration pattern:
1. inspect current wrappers
2. identify which files are wrappers vs real binaries
3. preserve existing auth/config directories
4. introduce a canonical env file
5. add compatibility shims if old paths are already in use

## OAuth logins are per-agent, not shared

The shared-runtime design is correct for binaries, caches, and package managers. It is
**wrong for OAuth/subscription logins**, because those tokens differ in kind:

- API keys are static → safe to share via one env file
- OAuth `refresh_token`s are **single-use** → the first client to refresh consumes them,
  every other client holding the same chain gets `401` / `refresh_token_reused`

So when a shared wrapper sets `CODEX_HOME_DIR` (or `CLAUDE_HOME_DIR`, …) for several
agents, each agent must still establish **its own** login. Concretely for this runtime:

- Hermes keeps its tokens in `$HOME/auth.json` (`credential_pool.<provider>`), not in the
  shared tool home
- The fix for a broken Codex credential is a fresh **device-code login per agent**, not
  copying `~/.codex/auth.json` around (that recreates the shared chain and the 401 returns)
- After a re-login, **remove the dead pool entry** (`hermes auth remove <provider> <id>`).
  A dead credential left in the pool keeps being selected and re-throws 401s even though a
  healthy one sits next to it
- A re-login is only half the job: also **configure the failover chain**, so a dead
  credential degrades to a working model instead of erroring. Hermes needs this in *two*
  places — `fallback_providers` (main model) and `auxiliary.<task>.fallback_chain` (every
  aux task pinned to that provider). Recipe, verification, and the non-destructive test:
  `references/hermes-provider-failover-policy.md`, applied with
  `scripts/apply_fallback_policy.py <config> [...]`
  - Caveat: that chain covers rate-limit / quota / connection / model-incompatibility
    failures, **not auth failures on a pinned aux provider** (401 on an explicitly set
    `auxiliary.<task>.provider` hard-fails; only `provider: auto` falls back on every error
    class, and `auto` ignores the task's `model:`). See "What actually triggers the aux
    ladder" in that reference before promising a user a graceful downgrade.
- Diagnosis, exact commands, known error codes, and the **Nous Portal (`nous`) re-login**
  recipe (a logged-out `nous` credential *is* the main chat model when
  `model.provider: nous`): `references/oauth-credential-sharing-pitfalls.md`

## When this skill applies

Use this skill whenever the user wants:
- one authentication flow shared across multiple agents
- one install/update location for CLIs
- a neutral tooling root separate from Hermes/OpenClaw internals
- predictable config/cache/work locations for external tools

## Reference material

- `references/ai-tools-runtime-pattern.md` — concrete real-world layout, wrapper examples, and migration notes from a Hermes + OpenClaw shared runtime setup
- `references/node-npm-cli-installation.md` — Node/npm global packages installed with `--prefix /opt/ai-tools`, including package name discoveries (Clerk = `clerk`, Firebase = `firebase-tools`) and verification steps
- `references/oauth-credential-sharing-pitfalls.md` — why shared tool HOMEs break OAuth logins (single-use refresh tokens), diagnosis via `auth.json` `last_auth_error`, and the per-agent device-code re-login recipe
- `references/hermes-provider-failover-policy.md` — wiring and *proving* automatic provider failover in Hermes: main chain vs per-task `auxiliary.*.fallback_chain`, **which failure classes actually trigger each layer** (auth on a pinned aux provider does not), rolling a policy out across all profiles, and the authoritative "which model actually answered" check
- `scripts/apply_fallback_policy.py` — idempotent re-writer for a config's `fallback_providers` + codex-pinned aux `fallback_chain` entries (surgical line edits, timestamped backup, `yaml.safe_load` validation; validated on four configs)
