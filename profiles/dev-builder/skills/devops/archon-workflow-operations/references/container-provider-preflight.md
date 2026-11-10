# Archon container provider and project preflight

Use this before running a real coding workflow in a persistent Archon Docker deployment, especially when the Hermes session cannot access the Docker socket.

## Goal

Verify the runtime from *inside Archon's workflow worker*, not from the Hermes host:

- repository checkout and required project files
- GitHub CLI authentication and repository access
- Claude and Codex provider authentication
- provider/model selection at node level
- deterministic build/test prerequisites
- mounted-home ownership and permissions

A healthy Web UI or `/api/health` response proves only that the server is alive; it does not prove worker tools, credentials, or project validation can run.

## Preferred probe pattern

Create a temporary read-only workflow, validate it, run it against the target codebase, inspect run events, then delete the workflow. Use:

```yaml
name: archon-container-preflight
worktree:
  enabled: false
mutates_checkout: false
nodes:
  - id: tools
    bash: |
      for c in git gh node npm npx bun uv java firebase claude codex; do
        command -v "$c" || true
      done

  - id: github
    bash: |
      gh auth status
      gh repo view OWNER/REPO --json nameWithOwner,defaultBranchRef,url

  - id: claude-smoke
    provider: claude
    model: opus
    allowed_tools: []
    prompt: "Reply with exactly: CLAUDE_OK"

  - id: codex-smoke
    provider: codex
    model: gpt-5.6-sol
    prompt: "Reply with exactly: CODEX_OK"
```

Add project-specific checks for lockfiles, package managers, Java, browser caches, emulators, and disk space. Diagnostic bash nodes should deliberately end with `exit 0` when their purpose is to collect multiple findings; otherwise the first non-zero probe can hide stdout in a failed-node event.

## Web API route pattern

When Docker exec is unavailable but the Archon Web API is reachable:

1. `POST /api/workflows/validate` with `{ "definition": <object> }`.
2. `PUT /api/workflows/<name>?source=global` to install the temporary workflow.
3. `POST /api/conversations` with the target `codebaseId`.
4. `POST /api/workflows/<name>/run` with `conversationId` and a message.
5. Read `/api/dashboard/runs?codebaseId=<id>` and `/api/workflows/runs/<run-id>`.
6. `DELETE /api/workflows/<name>?source=global` after verification.

Same-origin browser `fetch` is useful when Cloudflare blocks generic script clients. Never leave a temporary diagnostic workflow installed.

## Runtime identity and mounted auth

Always compare the worker's actual `uid`, `gid`, `HOME`, and `PATH` with ownership and modes of:

- `$HOME/.claude`
- `$HOME/.codex/config.toml` and auth files
- `$HOME/.config/gh`
- shared `/opt/ai-tools` config directories

A mounted config may exist and still be unusable when a `0600` file belongs to another UID. Fix the host dataset ownership to the container runtime UID/GID, or run the container with the UID/GID that owns the mounted files. Recreate the container after mount or user changes.

Do not assume shared wrapper configuration proves Archon's built-in provider works. Archon may invoke its packaged provider binary directly, which reads `$HOME/.codex` or `$HOME/.claude` rather than wrapper-specific environment. Verify each provider with a real prompt node.

## Mixed-provider workflow pattern

Per-node providers are supported:

```yaml
- id: plan
  provider: claude
  model: opus

- id: implement
  provider: claude
  model: sonnet
  depends_on: [plan]

- id: review
  provider: codex
  model: gpt-5.6-sol
  depends_on: [implement]
```

Use deterministic `bash:` nodes for actual validation (`npm run verify`, tests, typecheck). Codex can review the diff and interpret real validation output, but should not replace execution of the checks. A strong cycle is: Opus plan → Sonnet implement → bash validation → Codex review/fix → final bash validation → draft PR.

## Project validation prerequisites

Derive prerequisites from the repository's agent instructions and canonical verify command. For a Node/Firebase/Playwright project this commonly includes:

- Node plus npm/npx
- Java required by Firebase emulators
- project dependencies in root and functions package
- Playwright OS libraries and matching browser build
- Firebase CLI

Build OS-level dependencies into the image. Install project dependencies in the workflow/worktree. Do not treat presence of a CLI binary as proof that its auth or runtime dependencies work.