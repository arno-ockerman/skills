# Shared AI tools authentication across containers

Use this when Hermes, OpenClaw, Archon, or other TrueNAS containers should share Claude Code, Codex CLI, GitHub CLI, and `/opt/ai-context` while retaining isolated application homes.

## Architecture

- Keep each application `HOME` private.
- Mount one dataset at `/opt/ai-tools` and one context dataset at `/opt/ai-context` in every consumer.
- Put wrappers first on `PATH`: `/opt/ai-tools/bin`.
- Wrappers select tool-specific homes:
  - Claude: `/opt/ai-tools/config/claude/home`
  - Codex: `/opt/ai-tools/config/codex/home`
  - gh: `GH_CONFIG_DIR=/opt/ai-tools/config/gh`
- Set direct binary overrides where the caller supports them:
  - `CLAUDE_BIN_PATH=/opt/ai-tools/bin/claude`
  - `CODEX_BIN_PATH=/opt/ai-tools/bin/codex`
- Do not additionally bind `.claude`, `.claude.json`, or `.codex` into the app home. Duplicate credential paths obscure which source is active.

External CLI auth is distinct from an agent framework's internal provider credential store. For example, Hermes' profile-local `auth.json` is not automatically replaced by Codex CLI auth. Do not symlink framework state wholesale merely to centralize CLI auth.

## Ownership invariant

OAuth/auth files are commonly mode `0600`, so all consumers of the writable shared tool homes should run external tools as the same UID/GID. de gebruiker's shared dataset uses `568:568`. Normalize stale files from prior container UIDs and retain restrictive modes; do not use `chmod 777`.

`stat` may display `UNKNOWN UNKNOWN` inside a minimal image when UID 568 has no passwd entry. Numeric ownership, readability, and successful tool execution are authoritative.

## Runtime-independent Codex wrapper

The npm Codex launcher has a `#!/usr/bin/env node` shebang. A shared wrapper can avoid requiring Node in every consumer image by launching the installed JS entry with the shared Bun runtime:

```bash
#!/usr/bin/env bash
set -euo pipefail
source /opt/ai-tools/config/shared/env.sh
export HOME="$CODEX_HOME_DIR"
mkdir -p "$HOME" "$AI_TOOLS_CACHE/codex"
CODEX_JS="/opt/ai-tools/work/npm-prefix/lib/node_modules/@openai/codex/bin/codex.js"
test -f "$CODEX_JS" || { printf 'Codex launcher not found: %s\n' "$CODEX_JS" >&2; exit 127; }
exec /opt/ai-tools/bun/bin/bun "$CODEX_JS" "$@"
```

This pattern was verified with `codex login status` against the shared ChatGPT login. Keep the npm package and Bun version centrally managed.

## Shell-probe pitfall

Use `docker exec ... sh -c`, not `sh -lc`, when verifying Compose `PATH`. A login shell may run `/etc/profile` and replace the configured path, producing false negatives from `command -v` even though the server process sees the wrappers correctly.

## GitHub single-source cleanup

`gh auth status` can show both `GH_TOKEN` and shared `hosts.yml`; environment tokens take precedence. To make shared `hosts.yml` the sole source:

1. Set `GH_CONFIG_DIR` and `GITHUB_CONFIG_DIR` to `/opt/ai-tools/config/gh`.
2. Optionally centralize Git credential-helper config with `GIT_CONFIG_GLOBAL=/opt/ai-tools/config/git/config` and run `gh auth setup-git` once.
3. Verify `gh repo view` and `git ls-remote`.
4. Only then remove duplicate `GH_TOKEN`/`GITHUB_TOKEN` entries from app-local env files and recreate the container.

## Verification sequence

1. Container identity and mounts.
2. `command -v` for all wrappers using `sh -c`.
3. File readability without printing secrets.
4. `claude auth status`, `codex login status`, `gh auth status`. Note that Claude can still report `loggedIn: true` while its OAuth access token is expired; treat status as metadata, not proof.
5. `gh repo view OWNER/REPO`.
6. Real minimal Claude/Codex prompt calls. A fixed-token Claude prompt is mandatory before declaring subscription auth healthy because it exposes stale/expired OAuth sessions.
7. Archon-level chat or temporary prompt-node smoke test.
8. Only then run a mutating issue-to-PR workflow.

A healthy `/api/health` proves the server is alive, not that provider credentials or worker tools function.

## TrueNAS Compose handling

- Pin an Archon release tag; avoid `latest` when CLI/server compatibility matters.
- Start from the currently accepted TrueNAS Custom App Compose and change the minimum necessary fields.
- If the UI reports generic `custom_compose_config_string / Invalid YAML`, validate the exact pasted text, remove markdown fences/BOM/tabs, and use a conservative Compose style. TrueNAS may wrap Compose semantic errors as YAML errors.
- See `templates/archon-shared-ai-tools.compose.yml` and `scripts/verify-shared-ai-tools.sh`.
