# Archon on TrueNAS SCALE with containerized Hermes

Use this reference when installing or troubleshooting Archon from a Hermes profile running in Docker Compose on TrueNAS SCALE, with shared AI CLIs under `/opt/ai-tools`.

## Recommended layout

| Purpose | Path |
|---|---|
| Archon source checkout | `/opt/ai-tools/src/Archon` |
| Archon wrapper | `/opt/ai-tools/bin/archon` |
| Bun runtime/wrapper | `/opt/ai-tools/bun/bin/bun`, `/opt/ai-tools/bin/bun` |
| Archon home/config/db | `/opt/ai-tools/config/archon` |
| Archon workspaces/worktrees | `/opt/ai-tools/work/archon/...` |
| Shared Codex wrapper | `/opt/ai-tools/bin/codex` |

This follows de gebruiker's shared external CLI pattern: keep Hermes profile internals isolated, but centralize external tools and auth.

## Source install sketch

```bash
mkdir -p /opt/ai-tools/{bin,cache,config,work,src}

# Bun runtime. If the official installer needs unzip and package install is not
# available, download the linux-x64 release zip and extract it with Python zipfile.
export BUN_INSTALL=/opt/ai-tools/bun
curl -fsSL https://bun.sh/install | bash

# Archon source.
git clone --depth=1 --branch dev https://github.com/coleam00/Archon.git /opt/ai-tools/src/Archon
cd /opt/ai-tools/src/Archon
/opt/ai-tools/bun/bin/bun install
```

## Wrapper pattern

```bash
cat > /opt/ai-tools/bin/archon <<'SH'
#!/usr/bin/env bash
set -euo pipefail
source /opt/ai-tools/config/shared/env.sh
export BUN_INSTALL=/opt/ai-tools/bun
export ARCHON_HOME="/opt/ai-tools/config/archon"
export CODEX_BIN_PATH="/opt/ai-tools/bin/codex"
# Use shared Codex auth/home, not the transient Hermes profile home.
export HOME="$CODEX_HOME_DIR"
mkdir -p "$ARCHON_HOME" "$CODEX_HOME_DIR" "$AI_TOOLS_CACHE/archon"
exec /opt/ai-tools/bun/bin/bun /opt/ai-tools/src/Archon/packages/cli/src/cli.ts "$@"
SH
chmod +x /opt/ai-tools/bin/archon
```

Important: the wrapper must not `cd /opt/ai-tools/src/Archon/packages/cli` before execution. Archon discovers project-local workflows from the process cwd; forcing cwd to Archon's source makes workflows in the user's target repo invisible.

## Codex-backed global config

`/opt/ai-tools/config/archon/config.yaml`:

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

For workflows authored from Hermes, prefer explicit workflow-level provider/model unless the user requests another assistant:

```yaml
provider: codex
model: gpt-5.5
```

## Verification sequence

```bash
PATH=/opt/ai-tools/bin:$PATH archon version
PATH=/opt/ai-tools/bin:$PATH archon workflow list --json
```

Deterministic engine smoke test:

```bash
cd /opt/ai-tools/src/Archon
/opt/ai-tools/bin/archon workflow run e2e-deterministic --no-worktree "Deterministic smoke test"
```

Minimal target-repo Codex smoke workflow:

```yaml
name: hermes-codex-smoke
description: "Minimal Archon + Codex smoke test."
provider: codex
model: gpt-5.5
nodes:
  - id: simple
    prompt: "Reply with exactly: ARCHON_CODEX_OK"
    idle_timeout: 60000
  - id: assert
    bash: |
      out="$simple.output"
      echo "simple output: $out"
      case "$out" in
        *ARCHON_CODEX_OK*) echo "PASS: codex responded" ;;
        *) echo "FAIL: expected ARCHON_CODEX_OK"; exit 1 ;;
      esac
    depends_on: [simple]
```

Run from the target repo:

```bash
/opt/ai-tools/bin/archon workflow run hermes-codex-smoke --no-worktree "Run minimal Codex smoke test"
```

For real development, use:

```bash
/opt/ai-tools/bin/archon workflow run <workflow-name> --branch <branch-name> "<task>"
```

Use `--no-worktree` only for quick smoke tests or when the user explicitly asks for direct execution.
