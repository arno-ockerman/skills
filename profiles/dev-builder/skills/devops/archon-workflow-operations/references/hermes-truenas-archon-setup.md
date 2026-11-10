# Hermes / TrueNAS Archon setup notes

Use this when de gebruiker wants Archon workflows from the Hermes `dev-builder` profile running inside a TrueNAS SCALE Docker Compose app.

## Recommended MVP setup

For workflow authoring and agent-triggered runs from Hermes, an always-on Archon server/container is not required. The Archon CLI can run workflows directly, including detached background runs:

```bash
cd /opt/data/workspace/<repo>
/opt/ai-tools/bin/archon workflow run <workflow> --branch feat/example --detach "task"
/opt/ai-tools/bin/archon workflow status
/opt/ai-tools/bin/archon workflow runs
/opt/ai-tools/bin/archon workflow get <run-id> --verbose
```

Use this first because it is simpler, already fits Hermes tool execution, and avoids extra TrueNAS service complexity.

## Shared tool-root pattern

In de gebruiker's setup, keep Archon in the shared AI tools root instead of inside one Hermes profile home:

```text
/opt/ai-tools/src/Archon          # Archon source clone
/opt/ai-tools/bin/archon          # stable wrapper
/opt/ai-tools/bin/bun             # Bun wrapper
/opt/ai-tools/bin/codex           # shared Codex wrapper
/opt/ai-tools/config/archon       # ARCHON_HOME
/opt/ai-tools/work/archon         # workspaces/worktrees/smoke repos
```

The wrapper should set the shared environment before calling Archon:

```bash
#!/usr/bin/env bash
set -euo pipefail
source /opt/ai-tools/config/shared/env.sh
export BUN_INSTALL=/opt/ai-tools/bun
export ARCHON_HOME="/opt/ai-tools/config/archon"
export CODEX_BIN_PATH="/opt/ai-tools/bin/codex"
export HOME="$CODEX_HOME_DIR"
mkdir -p "$ARCHON_HOME" "$CODEX_HOME_DIR" "$AI_TOOLS_CACHE/archon"
exec /opt/ai-tools/bun/bin/bun /opt/ai-tools/src/Archon/packages/cli/src/cli.ts "$@"
```

Do not `cd` to the Archon source inside the wrapper before executing the CLI; doing so causes repo-local workflows in the target cwd not to be discovered. Calling the absolute `src/cli.ts` while preserving cwd lets Archon discover `.archon/workflows` in the target repo.

## Global Archon config for Codex

Use Codex by default in de gebruiker's Hermes setup:

```yaml
botName: Archon
defaultAssistant: codex
assistants:
  codex:
    model: gpt-5.5
    modelReasoningEffort: medium
    webSearchMode: disabled
    codexBinaryPath: /opt/ai-tools/bin/codex
paths:
  workspaces: /opt/ai-tools/work/archon/workspaces
  worktrees: /opt/ai-tools/work/archon/worktrees
concurrency:
  maxConversations: 3
```

Many bundled Archon workflows specify `provider: claude`; for workflows we author for de gebruiker, explicitly set:

```yaml
provider: codex
model: gpt-5.5
modelReasoningEffort: medium
webSearchMode: disabled
```

## When to add a dedicated Archon container/server

A separate TrueNAS Archon container is optional, not required for CLI workflow runs. Add it when de gebruiker wants any of:

- GitHub issue/PR webhooks starting workflows autonomously
- Archon Web UI or dashboard
- Telegram/Slack/Discord Archon adapters
- a durable always-on Archon daemon independent of Hermes sessions

For such a container, mount the same shared volumes Hermes uses so Archon can see repos and shared auth:

```text
/opt/ai-tools
/opt/data/workspace
/opt/ai-context
```

Only mount `/var/run/docker.sock` if Archon itself must start Docker runners/containers. Treat that as root-equivalent host access on TrueNAS.

## Repo workflow pattern

For a target repo, create:

```text
.archon/config.yaml
.archon/commands/
.archon/workflows/
.archon/scripts/
```

Add `.gitignore` entries for runtime-only files:

```gitignore
.archon/state/
.archon/.env
```

Good starter workflows:

- `<repo>-review`: read-only review, `worktree.enabled: false`, `mutates_checkout: false`
- `<repo>-preflight`: deterministic typecheck/test/migration checks, no AI
- `<repo>-safe-feature`: plan -> implement -> validate -> review with `worktree.enabled: true`

For mutating workflows, force worktree isolation with:

```yaml
worktree:
  enabled: true
```

## Validation sequence

Before declaring setup done:

```bash
/opt/ai-tools/bin/archon version
cd /opt/data/workspace/<repo>
/opt/ai-tools/bin/archon workflow list --json
/opt/ai-tools/bin/archon validate commands
/opt/ai-tools/bin/archon validate workflows <workflow-name>
```

Then run one safe read-only smoke workflow with `--no-worktree` to verify Archon can read the repo and Codex can respond.
