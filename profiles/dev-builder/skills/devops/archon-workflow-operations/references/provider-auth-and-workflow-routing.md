# Archon provider authentication and workflow routing

Use this when an Archon Web chat says it is not logged in to an AI provider, or a DAG fails at its first AI node and skips the downstream graph.

## Diagnose provider routing before credentials

1. Identify the runtime: an Archon Web UI/workflow error belongs to the Archon container, not a Hermes profile.
2. Inspect the workflow YAML/metadata for explicit `provider:` and `model:` values. Workflow-level or node-level provider selection outranks the chat default.
3. Inspect `GET /api/config` (non-secret) to see `assistant`, assistant models, and `small`/`medium`/`large` tier mappings.
4. Treat a first-node authentication failure as a provider-readiness problem until proven otherwise. For example, a `parse-request` AI node can fail before a valid GitHub issue URL is ever fetched; downstream skips are then expected DAG behavior.
5. Do not infer that Codex readiness satisfies a bundled workflow pinned to Claude, or vice versa.

## Credential repair options

### Per-user Web UI (preferred)

In **Settings → Agents**, open the agent named by the workflow and connect its vendor credential:

- Claude Code → `anthropic` → subscription login or API key.
- Codex → `openai` → subscription login or API key.

The agent card must show `Ready`. Per-user credentials take precedence over install-wide environment credentials for that user's runs.

### Install-wide Docker credential

For a solo install, put the provider credential in the Archon-owned env file imported by Compose. For Claude this is typically one of:

```env
CLAUDE_CODE_OAUTH_TOKEN=...
CLAUDE_API_KEY=...
```

Never pass secrets in chat, argv, logs, or a committed file. Confirm Compose declares `env_file:`. Recreate the container after env changes; a plain restart retains the old container environment.

## Chat defaults versus workflow providers

Provider selection must be audited as a precedence chain:

1. node-level `provider:` (including nodes nested in `loop`, `loop_group`, and sub-DAG structures),
2. workflow-level `provider:`,
3. configured model tier provider for `small`/`medium`/`large`,
4. install/user default assistant.

- Changing **Defaults → Chat runs on** affects newly created conversations; an existing conversation keeps the assistant selected when it was created.
- Changing only the default assistant is insufficient when one or more tiers still map to another provider.
- Changing the chat default or tiers does not override an explicit workflow/node `provider:`.
- A workflow resolves its provider when the run starts. Check `/api/health` for `runningWorkflows: 0` before changing defaults, or let existing runs finish and use a fresh run for verification.
- If the operator wants Codex but a bundled workflow is Claude-pinned, either connect Claude for that workflow or create a repo-local Codex adaptation under a new name. Do not overwrite the bundled workflow.
- Before porting, inspect for provider-specific hooks, sub-agents, tool restrictions, skills, session behavior, and model aliases. In particular, do not assume Codex enforces `allowed_tools`/`denied_tools`; unsupported capability warnings mean those restrictions are ignored.

## Changing install-wide routing through the API

Read `GET /api/config`, preserve the previous values for rollback, then update both surfaces:

```http
PATCH /api/config/assistants
Content-Type: application/json

{"assistant":"codex"}
```

```http
PATCH /api/config/tiers
Content-Type: application/json

{"tiers":{
  "small":{"provider":"codex","model":"<verified-model>","effort":"medium"},
  "medium":{"provider":"codex","model":"<verified-model>","effort":"medium"},
  "large":{"provider":"codex","model":"<verified-model>","effort":"medium"}
}}
```

Use only model IDs that pass a real fixed-token prompt with the exact mounted CLI/account first. Read `GET /api/config` back after both writes; if the tier update fails after the assistant update, restore both prior values rather than leaving a split configuration.

Audit the live workflow catalog programmatically rather than by eye: flatten nested node collections and report workflow-level providers, explicit node providers, and tier-valued models. Keep explicitly pinned bundled workflows separate from workflows that inherit config.

## Verification sequence

1. Run a minimal real CLI/SDK prompt with no tools, expecting a fixed token such as `CLAUDE_OK` or `CODEX_OK`.
2. Run a temporary read-only workflow that omits both `provider:` and `model:` so it exercises inherited routing. Use a real registered repository (or a scratch repository with an initial `main` commit/default branch), run `archon validate workflows <name>`, and require logs showing `workflow_provider_resolved`, the expected `providerSource`, provider/model, and fixed token.
3. Start a new chat and verify the configured default provider responds.
4. From the actual Archon worker, verify `gh auth status` and repository access; provider auth can hide the next GitHub failure.
5. For a workflow that failed on its first node with no useful artifacts, prefer a fresh run after repair. Resume is more valuable when upstream work completed.
6. Keep mutations gated: draft PR only, no deploy, merge, or production migration during the smoke run.
7. Remove the temporary workflow, scratch repository/workspace, and any auto-registered codebase record; verify each target is gone.

## Useful non-secret checks

```bash
curl -fsS https://ARCHON_HOST/api/health
curl -fsS https://ARCHON_HOST/api/config
```

Inside the Archon container:

```bash
which claude || true
which codex || true
gh auth status
gh repo view OWNER/REPO --json nameWithOwner,defaultBranchRef,url
```

Binary presence is not authentication proof; the fixed-token AI prompt is the provider proof.
