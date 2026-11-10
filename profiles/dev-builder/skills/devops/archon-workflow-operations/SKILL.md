---
name: archon-workflow-operations
description: "Use when operating Archon in de gebruiker's TrueNAS environment."
version: 1.0.0
author: Hermes Agent
license: MIT
created_by: agent
metadata:
  hermes:
    tags: [archon, truenas, workflows, software-factory]
    related_skills: [archon]
---

# Archon Workflow Operations

## When to Use

Use this when de gebruiker wants to install/configure Archon, create repo-specific Archon workflows, run them from Hermes, adopt a software-factory/control-plane stack, or operate Archon as a TrueNAS service.

## Core guidance

1. **Start with CLI mode first.** Archon CLI workflows do not require the Archon server. Use CLI runs from Hermes while designing and validating workflows.
2. **Use the shared AI tools root.** Keep Archon, Bun, and Codex wrappers under `/opt/ai-tools` so Hermes/OpenClaw-style agents share one install/auth surface.
3. **Preserve target cwd in the Archon wrapper.** Do not `cd` into the Archon source before running the CLI; otherwise repo-local `.archon/workflows` in the target repo may not be discovered.
4. **Prefer Codex-authored workflows for de gebruiker.** Many bundled Archon workflows are Claude-specific; repo workflows we create should explicitly set `provider: codex` and use de gebruiker's current preferred Codex model only after the exact shared CLI version/account combination passes a real prompt with that model. Avoid stale hard-coded model defaults.
5. **Force worktree isolation for mutating workflows.** Use `worktree.enabled: true` for feature/fix workflows; use `worktree.enabled: false` plus `mutates_checkout: false` for read-only review/preflight workflows.
6. **Validate before running.** Always run workflow/command validation before telling de gebruiker a workflow is ready.
7. **Preflight the actual container worker.** A healthy Web UI does not prove provider auth, mounted configs, GitHub access, or project test prerequisites work. Before the first real coding run, execute a temporary read-only workflow with real Claude/Codex prompt nodes and deterministic tool checks; see `references/container-provider-preflight.md`.
8. **Use constrained remote operations instead of command relay.** When Hermes can reach the Web API but not the TrueNAS Docker runtime, prefer a dedicated SSH-key account plus a narrow `archonctl` wrapper. Avoid mounting the Docker socket into Hermes or granting casual Docker-group access because both are effectively host-root. Put Compose/Dockerfile/scripts under version control; see `references/secure-remote-container-operations.md`.
9. **Check version and adapter state explicitly.** Compare the external CLI version with the persistent server version before workflow authoring or migration. Read `/api/health` `activePlatforms`; `Web` alone confirms UI/API availability but not GitHub adapter activation.
10. **Keep validation deterministic.** Mixed-provider workflows are supported per node (for example Opus planning, Sonnet implementation, Codex review), but real tests/typechecks must run in `bash:` nodes rather than being inferred by an AI reviewer.
11. **Diagnose TrueNAS bind mounts as the configured container UID/GID.** A root one-shot container can read paths that the real Archon process cannot. Inspect `.Config.User`, test every mount with `docker run --user`, repair access with targeted recursive/default ACLs rather than `chmod 777`, and verify restart-count stability plus `server_ready`. See `references/truenas-container-permissions-and-docker-access.md`.
12. **For shared `/opt/ai-tools`, standardize the external-tool UID/GID.** Claude, Codex, and gh auth files are normally `0600`; a writable shared auth home used by containers running as different UIDs causes permission drift and token-refresh failures. Prefer running every consumer of the shared wrappers as the dataset owner (de gebruiker uses `568:568`), or add narrowly targeted ACLs when that is impossible. Normalize stale files from old container UIDs before testing.
13. **Use wrappers as the only provider-auth path, but isolate forge identities per service.** Set `CLAUDE_BIN_PATH=/opt/ai-tools/bin/claude`, `CODEX_BIN_PATH=/opt/ai-tools/bin/codex`, and put the intended wrappers first on `PATH`. Keep each app's own `HOME`; let wrappers select tool-specific homes. Do not also bind the same `.claude`, `.claude.json`, or `.codex` directories into the app HOME, because duplicate access paths obscure which credential source is active and can reintroduce ownership drift. Never point Archon at Hermes' `GH_CONFIG_DIR`: use an Archon-owned GitHub App and an empty Archon-specific `gh` config/wrapper so a missing injected App token cannot fall back to Hermes' personal credential.
14. **Trace and change the whole provider-resolution chain.** A bundled workflow can explicitly pin Claude while chat or repo defaults prefer Codex. Inspect workflow-level and recursively nested node-level `provider:`, `/api/config.assistant`, and every `small`/`medium`/`large` tier. Changing only the chat/default assistant is insufficient when tiers or nodes still name Claude. Check that no workflow is active before changing install defaults because a run keeps the provider resolved at its start; prove the result with a fresh inherited-provider smoke workflow. Connect the named provider or create a separately named, validated provider adaptation when provider-specific capabilities prevent a safe port. See `references/provider-auth-and-workflow-routing.md`.
15. **Align the runtimes, not merely repositories.** Determine whether the CLI executes a source checkout and whether the server runs an official image tag or locally built source. Pin both to the same release; normally upgrade a stale CLI to a healthy newer server rather than downgrading persisted server state. See `references/cli-server-version-alignment.md`.
16. **Use the verified shared-auth pattern across containers.** Standardize UID/GID, wrappers, tool homes, context mounts, and staged provider verification. Use `sh -c` rather than a login shell for Compose `PATH` probes, and use the Bun-launched Codex wrapper when consumer images do not carry Node. See `references/shared-ai-tools-auth-runtime.md`, `templates/archon-shared-ai-tools.compose.yml`, and `scripts/verify-shared-ai-tools.sh`.
17. **Update TrueNAS Custom Apps through middleware, not rendered Compose.** Read the active structured config with `app.config`, preserve it, mutate only the required environment keys, and submit it through `app.update`; pass secret-bearing JSON on stdin. For Telegram, enforce a numeric user allowlist and verify `/api/health` includes `Telegram`. See `references/truenas-custom-app-telegram-adapter.md`.
18. **Verify bundled packs through the live server before installing files.** A workflow pack can be compiled into the Archon server image and exposed as `source: "bundled"` without appearing as loose files in the persistent dataset. Compare upstream pack entrypoints with `/api/workflows` programmatically; if none are missing, do not copy them into the dataset because duplicate names or overrides add risk. See `references/bundled-workflow-pack-verification.md`.
19. **Treat provider auth text as a classification, not proof.** Reproduce with the exact configured model, then test the shared wrapper and Codex SDK inside the same image and UID. A valid login can coexist with an Archon-formatted auth error caused elsewhere in the provider path. See `references/codex-auth-error-differential-diagnosis.md`.
20. **Preserve de gebruiker's manual upgrade control on TrueNAS.** When Archon tracks the official `:latest` image but de gebruiker wants to choose the upgrade moment, set the service `pull_policy` to `never` through `app.update`. Upgrade only with an explicit `docker pull` followed by `app.redeploy`; a redeploy alone reuses the local image. Verify the structured app config, active container image ID, health, restart count, and a Web/provider smoke after the redeploy.
21. **Drive unattended issue→PR pipelines from one cron job, one issue per run.** A scheduled intake job selects at most one eligible issue, starts `archon-ship` through the container's internal API, reads the run back, and never merges. Derive the schedule from the user's *local-hour* intent rather than a raw UTC hour, and gate a consumer job behind a demonstrably live prerequisite. See `references/scheduled-issue-to-pr-pipeline.md`.
22. **Match Archon's process HOME to the active SDK provider in source mode.** The shared `archon` wrapper currently sets `HOME` to the Codex home; source-mode Claude SDK nodes spawn the installed Claude binary directly and can therefore report `Not logged in` even when `/opt/ai-tools/bin/claude` succeeds. Preserve `ARCHON_HOME`, source the shared env, set `HOME="$CLAUDE_HOME_DIR"`, and invoke the Bun CLI directly for a Claude-pinned resume. Verify a live Claude child and workflow activity before declaring recovery.
23. **Separate the factory execution plane from its control plane.** When adopting a public “software factory” demo, identify the workflow runtime, project consumer, event database, forge ingestion, and dashboard as separate deployables before changing anything. Reuse de gebruiker's healthy Archon server and live bundled pack by default; do not install a second pinned Archon runtime merely because an upstream installer bundles one. Validate the server's authenticated workflow catalog and input schemas, run one supervised project lap with merge/deploy disabled, then add scheduling and observability. See `references/software-factory-control-plane-adoption.md`.

When de gebruiker wants an Archon pipeline to keep working GitHub issues on its own — picking one implementation-ready issue, triaging, shipping to a PR, and never merging — read `references/scheduled-issue-to-pr-pipeline.md`: the job contract, the eligible-issue selection rules, launching and reading back a run through the internal API, what to do when triage answers `NO_ACTION`, the DST-safe "local midnight" schedule pattern built on a date-printing `monitor` script, and how to gate the follower job.

When an Archon run fails, costs more than expected, or de gebruiker asks which model ran which task, read `references/archon-run-forensics-and-codex-quota.md`: how to pull a run plus its per-node model/token/duration table from the API, the measured token budget of a full `archon-ship` run, and why a just-reset Codex window is already exhausted by the run itself (the container shares one ChatGPT account with Hermes and Herdr through `/opt/ai-tools`).

When de gebruiker wants a different model per Archon task, asks which model fits which stage, or needs load moved off an exhausted provider, read `references/model-routing-and-provider-choice.md`: remap the `small`/`medium`/`large` tiers through `PATCH /api/config/tiers` (or `archon ai tier set`) because the bundled pack is image-owned and YAML edits do not survive updates; it also carries the tier→node map of the deployed pack, the provider capability matrix, whether a resumed run picks up a new mapping, and how to resume a run whose parent is a Telegram conversation.

When the question is how Archon should behave when Codex or Claude hits a usage limit — or whether it can fail over to another provider or model such as DeepSeek — read `references/provider-fallback-and-quota-resume.md`: the `workflows.autoResumeOnQuotaReset` settings block and how to verify the loader sees it, why the native detection misses Codex's "You've hit your usage limit" wording (tested against the real error string), why `fallbackModel` is Claude-only and unreachable without editing the image-owned pack, the working alternative of remapping the tiers onto the other subscription so the interrupted run resumes immediately, how to restore the previous mapping once that quota window reopens, and the current 503 on the embedded OpenCode runtime that blocks a third-party-model route.

When Archon's community OpenCode provider 503s, `archon doctor` claims the runtime is present but sessions fail with `Executable not found in $PATH: "opencode"`, or the task is to use OpenCode from Herdr, read `references/opencode-cli-in-ai-tools.md`: why the SDK spawns a CLI the image does not ship, the exact install and wrapper in the shared ai-tools dataset (so Hermes, Herdr and Archon share one config and credential store), the single app-env change that activates it, and the latency budget of the embedded server handshake.

Before assigning Archon work to the `opencode` provider (tier, alias, or per-run `--model`), read `references/archon-opencode-provider-limits.md`: tier/alias assignment and per-run overrides verify green, but a workflow node on OpenCode hangs mid-tool (empty `tool_input` + a `read` that never completes — upstream #3321/#3332), so it is not a safe failover target yet; it also covers the title-generator side-service that still calls the default assistant, orphaned `opencode serve` processes left by runtime probes, and how to cancel a hung detached run.

When a finished run must be followed by a repository action without a human in the loop — merge the PR that closes the issue and start the next ship — read `references/chaining-archon-runs.md` first. The critical points: `archon-ship` has no merge node, so merging is a separate step (and the PR body's `Closes #NNN` is what closes the issue); only branch-protection-required checks may gate the merge; a run awaiting resume is indistinguishable from a dead one unless the resume step writes an outcome marker; and the cron environment needs `GH_CONFIG_DIR` set explicitly.

When a container or CLI cannot find `node`, `npm`, `npx` or `uv`, read `references/node-and-python-runtimes-in-ai-tools.md`: wrappers in `/opt/ai-tools/bin` fix every app that mounts the dataset; verify with `sh -c` and never `sh -lc` (login shells wipe PATH); and a bare `GH_TOKEN` in a container can shadow a working `hosts.yml` token. Fine-grained PATs cannot read the Checks API at all, so CI check state needs a classic or GitHub-App token — no permission grant fixes it.

When a run burns the provider quota too fast and the question is which knob actually reduces it, read `references/token-and-quota-economics.md` — measure turns and the input/output ratio first, because the cost is context × turns, not reasoning depth.

To make a newly shipped provider model selectable (e.g. a new Codex flagship), read `references/model-aliases-and-new-models.md`: Archon's curated dropdown is not authority, aliases are patched via a wrapped `{"aliases":{...}}` body, and `archon validate workflows` plus a bogus-alias control proves resolution without burning a run.

## Common commands

```bash
cd /opt/data/workspace/<repo>
/opt/ai-tools/bin/archon workflow list --json
/opt/ai-tools/bin/archon validate commands
/opt/ai-tools/bin/archon validate workflows <workflow-name>
/opt/ai-tools/bin/archon workflow run <workflow-name> --branch feat/example "task"
/opt/ai-tools/bin/archon workflow run <workflow-name> --branch feat/example --detach "task"
/opt/ai-tools/bin/archon workflow status
/opt/ai-tools/bin/archon workflow runs
/opt/ai-tools/bin/archon workflow get <run-id> --verbose
```

## Repo scaffolding pattern

Create this in each target repo:

```text
.archon/config.yaml
.archon/commands/
.archon/workflows/
.archon/scripts/
```

Add `.gitignore` runtime exclusions:

```gitignore
.archon/state/
.archon/.env
```

Good starter workflows:

- `<repo>-review`: read-only review, no code changes.
- `<repo>-preflight`: deterministic typecheck/test/migration checks.
- `<repo>-safe-feature`: plan → implement → validate → review in a worktree.

## Researching and adapting Cole workflows

When de gebruiker asks for concrete Cole Medin/coleam00 workflows, do **live GitHub/YouTube discovery** instead of relying only on the local Archon defaults. Use `references/cole-medin-workflow-research.md` for the proven search pattern, useful repos, and porting guidance.

Best patterns to adapt for coding projects:

- issue → classify → smoke-validate → investigate/plan → implement → validate → review/fix
- idea/PRD → plan → implement → validate → PR/review
- UI feature → explore → plan → design UI → integrate → validate → browser smoke
- large feature → PRD/story loop with one validated story per iteration
- refactor → impact analysis → ordered refactor plan → execute with behavior-preservation checks

When driving the Archon server headlessly over HTTP (or building/adopting a reusable factory consumer over the bundled SDLC pack), read `references/headless-http-api-and-software-factory.md`: resolve codebases dynamically, shape inputs from each workflow's live schema, make runs dry by default, require a human-applied readiness label before mutating-stage execution, fail diagnostics and unsupported harness checks closed, edit factory-owned docs in the template (not the project), derive deploy authority from the repository's real CI, and account for Cloudflare's Python User-Agent blocking plus linked-worktree/template-cache installer pitfalls.

When de gebruiker wants to reproduce a public AI-software-factory dashboard or “mission control” stack, read `references/software-factory-control-plane-adoption.md`: it separates the runtime from the dashboard, gives the safe adoption order for an existing Archon server, explains the shared-Postgres/Realtime requirement, and defines the supervised-pilot gate before loops, scheduling, merge, or deploy automation.

## TrueNAS/server decision

A separate Archon container/server is **optional**, not required for CLI workflow runs. Add it only when de gebruiker wants GitHub webhooks, Web UI/dashboard, Telegram/Slack/Discord adapters, or an always-on Archon daemon independent of Hermes.

For browser access, prefer exposing Archon through Cloudflare Zero Trust (e.g. `https://example.com`) rather than raw LAN/public port access. See:

- `references/hermes-truenas-archon-setup.md` for wrapper/config/container notes.
- `references/truenas-web-ui-github-adapter.md` for Web UI startup, Codex env extraction, Cloudflare/reverse-proxy notes, and GitHub webhook setup.
- `references/truenas-docker-deployment.md` for TrueNAS Apps bind-mount paths, Docker entrypoint workarounds, shared `ai-tools` mounts, and `gh`/`GH_TOKEN` verification.
- `references/truenas-custom-app-telegram-adapter.md` for securely enabling Telegram on an already-running TrueNAS Custom App through `midclt`, including allowlisting and verification.

## Server/GitHub workflow visibility

When using the GitHub adapter or Web UI server, commit and push repo-local `.archon/` workflows/commands before expecting the server to see them. CLI runs read from the current local working directory, including uncommitted changes; server-side runs read from Archon's workspace clone synced from remote GitHub.

### First Web UI workflow: bundled before custom

If a project is already visible in the Web UI, first confirm that the bundled `archon-fix-github-issue` appears under **Start a new run**. Use it for a small, clearly scoped smoke issue before creating repo-local workflow files. Include the repository's canonical verification command and explicitly prohibit deploy/merge in the run prompt.

Check the bundled workflow's provider/model metadata: a bundled issue workflow may use Claude even when the user's preferred custom workflows use Codex. Only create a repo-local override after the end-to-end path works or when provider, validation, draft-PR, or safety constraints need to be enforced.

See `references/web-ui-first-project-workflow.md` for the UI flow, preflight checklist, prompt template, and bundled-versus-custom decision.

## Troubleshooting boundary: Archon vs Hermes profiles

Archon and Hermes can emit similarly worded authentication errors while running in separate containers/processes. Before changing credentials, identify the failing runtime from the user's stated source and log prefix:

- `@archon/server`, Archon Web UI, workflow or codebase clone → inspect the Archon container.
- Hermes Telegram agent, named profile such as `health-coach`, or Hermes gateway log → inspect that Hermes profile and gateway.

Do not carry an Archon diagnosis into a Hermes profile merely because the message says `Provider authentication failed`. For Hermes failures, inspect profile-local `auth.json`, credential-pool status, gateway/agent logs, then run a profile-specific CLI smoke test. See `references/auth-runtime-boundaries.md`.

## Telegram deliverables

When de gebruiker asks for Docker Compose or another multi-line config through Telegram, create and attach the real `.yml`/config file instead of relying only on a long code block. Keep the chat response to the download link, required path substitutions, and short verification steps.

## Pitfalls

- If bare `archon` is not on `PATH`, use `/opt/ai-tools/bin/archon` explicitly rather than treating Archon as unavailable.
- If Archon strips target repo `.env*` keys at boot, that is expected safety behavior. Put Archon-owned env in `ARCHON_HOME/.env` or repo `.archon/.env`, not top-level app `.env`.
- A token stored in an Archon data-folder `.env` is not injected unless Compose declares `env_file:` or equivalent explicit environment wiring. Recreate/redeploy after env changes; a process restart can retain the old container environment (in the TrueNAS UI: Stop → Start, not Restart). A variable injected via `env_file` does not appear in the Apps UI environment list, so search the rendered compose, not the UI, before concluding it is unset.
- Updating a shared mounted CLI or wrapper does not guarantee that Archon's long-lived provider singleton reloads it. Adding/removing an unrelated diagnostic service may leave the main service unchanged; explicitly redeploy/recreate the Archon service before the final end-to-end smoke test.
- For GitHub CLI inside Archon, expose both binary and auth config: mount shared `ai-tools`, put its wrapper first on `PATH`, and set `GH_CONFIG_DIR`. Avoid empty Compose substitutions that override `env_file` values.
- Never rely on a fine-grained PAT for CI check state on this host: it cannot read the Checks API and no permission grant fixes that. Check what else reads the variable, then drop `GH_TOKEN` so `gh` falls back to the classic token in `hosts.yml`, and recreate the container so the env-file change applies.
- Separate storage responsibilities: Archon DB/config/home belongs in its dedicated dataset; shared Claude/Codex/GitHub CLIs and auth stay in `ai-tools`; context remains in `ProductivityCenter`.
- DAG node types are mutually exclusive: do not put `command:` and `prompt:` on the same node. Use a command node by itself for `$ARGUMENTS`, or use an inline `prompt:` when you need to combine upstream node output like `$plan.output`.
- In bash nodes, avoid double-quoting Archon substitutions such as `"$node.output"`; assign with `out=$node.output` because Archon injects shell-quoted strings and validation warns on the double-quoted form.
- Avoid capturing setup-state failures like missing Bun/unzip as durable negatives. Capture the working install/wrapper pattern instead.
- Do not dump the full Docker `.Config.Env` during diagnosis; select only required keys because provider and GitHub credentials can be present.
- A TrueNAS `docker` group that reports `builtin: true` and `immutable: true` cannot be managed through the normal Members/Auxiliary Groups controls. Verify middleware metadata first, then prefer a TrueNAS-managed sudo rule for `/usr/bin/docker`; never use an unmanaged `usermod` workaround.
- In remote zsh scripts, avoid `path` as a variable name because it mutates the shell's `PATH` array; use `src` or `mount_path`.
- Do not infer that a checked-out deployment overlay is live. Read the running container's Compose labels and TrueNAS `app.config`; Custom App rendered files under `/mnt/.ix-apps` are generated and should not be edited directly.
- Do not equate “not present as loose files in the dataset” with “not installed.” Bundled packs are server-owned; verify the live catalog and exact upstream/server name sets before writing anything.
- A Telegram bot cannot initiate a private conversation before the user presses **Start**. Verify adapter startup separately, then require an inbound `/start` or test request for true end-to-end acceptance.
- `GET /api/workflows/runs/<id>` can answer with an empty `{"metadata": {}}` while the run is alive; it is not proof of a missing run. Enumerate `GET /api/workflows/runs?limit=200` and filter client-side before reporting any run's status.
- `POST /api/workflows/<workflow>/run` accepting with `{"accepted":true,"status":"started"}` is only acceptance and may return no run ID. Read `/api/workflows/runs?limit=...` back and match workflow name, codebase, launch time and message/target; do not require the launch conversation ID to equal the persisted run conversation because orchestration may create a child conversation.
- Cron schedules run in UTC. "Midnight local time" is not a fixed UTC hour; resolve it through a local-date `monitor` script instead of picking an offset by hand.
- A cron job's `monitor`/`script` path is relative to the profile's `scripts/` directory; absolute paths are rejected.
- For Archon watchdogs running on the same LAN, prefer the direct TrueNAS API endpoint and retain the Cloudflare URL as a fallback. Add bounded curl retries (`--retry-all-errors`) so one DNS, tunnel, or edge failure does not generate a false alarm.
- Launch every Archon workflow run from Hermes with `terminal(background=true, notify=true)` — never `nohup`/`setsid`/`disown`, which the terminal tool refuses, and never a foreground call, which is killed when the turn or session is interrupted. A killed run leaves its row `running` with no process behind it, which then blocks the next resume; see the recovery sequence in `references/provider-fallback-and-quota-resume.md`.
- `archon workflow resume` accepts only `failed` and `paused` rows. A row left `running` by an interrupted process must be `abandon`ed first, and the `abandon` can only be undone by writing `status='failed'` back into `remote_agent_workflow_runs` — so prefer the launch pattern above over the recovery sequence.
- A run that failed at its first node has no completed nodes, and `workflow resume` rejects it outright: start a fresh `workflow run` instead of trying to repair the row.
- Registering a project in the Archon Web UI does not prove the forge can clone it. On a private repo the earlier `Authentication failed` shows up as a codebase row with `default_branch: null`, `ai_assistant_type: null`, and `updated_at` still equal to `created_at` — the initial clone/scan never completed. `GET /api/codebases` and compare to a healthy row (`default_branch: main`, assistant type set) before declaring the project ready to run; a passing `consumer.py doctor` only proves the repo is *registered*, not that it clones.
- When porting an upstream workflow, never infer compatibility from an older local CLI or from remembered field support. Fetch the exact deployed release source when possible, validate each candidate definition through the live server's `/api/workflows/validate`, then run that exact release's `validate workflows`, `validate commands`, and `workflow test` against the project. Adapt only the fields those authoritative checks reject; queue-era `with:`, `returns:` and approval shapes may be valid on newer releases even when an older CLI warns or cannot discover nested workflows.
- Project repos live under `/opt/project`, outside `HERMES_WRITE_SAFE_ROOT` (`/opt/data`): `write_file` refuses those paths and a terminal write triggers an approval prompt that can time out. Write repo files (e.g. `.archon/` workflows) via a `terminal` heredoc and expect the approval, or ask de gebruiker to extend the safe root to include `/opt/project` before a long authoring session.
