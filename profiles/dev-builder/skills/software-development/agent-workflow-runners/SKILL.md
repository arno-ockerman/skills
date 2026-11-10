---
name: agent-workflow-runners
description: Set up and operate external AI workflow runners (Archon-style DAG/CLI workflow systems) from Hermes, especially in containerized/shared-tool environments.
version: 1.0.0
created_by: agent
---

# Agent Workflow Runners

Use this skill when de gebruiker wants Hermes to install, configure, verify, or operate an external workflow runner such as Archon so that we can author workflows together and let the runner execute them.

This is a class-level companion to tool-specific skills. If a dedicated tool skill exists, load it first; then use this skill for deployment/runtime patterns that are specific to Hermes, Docker/TrueNAS, shared CLI roots, or cross-agent auth.

## Triggers

- "set up Archon on TrueNAS / Docker Compose"
- "install a workflow runner so we can make workflows"
- "make Hermes run Archon workflows"
- "configure shared CLI/auth for workflow agents"
- "workflow runner cannot see my repo workflows"
- "use Codex/Claude auth from a shared tool install"
- "audit or compare multiple external agent-skill stacks (Matt / pstack / Addy) on one PR"
- "operate Herdr to drive coding agents in shared/TrueNAS workboxes"

## Core approach

1. **Keep Hermes internals isolated.** Do not collapse Hermes profiles into one shared `$HOME`.
2. **Centralize external CLI tooling.** Put workflow-runner source, wrappers, config, cache, and work directories under `/opt/ai-tools`.
3. **Expose stable wrappers.** Users and agents should call `/opt/ai-tools/bin/<tool>` rather than source-tree paths or profile-local installs.
4. **Pin runner home/config explicitly.** Set the tool's home/config env vars in the wrapper so Docker/container home detection does not send state to transient or read-only locations.
5. **Prefer explicit provider/model in workflows.** If Hermes is authenticated to Codex, author workflows with `provider: codex` and the desired model unless the workflow intentionally needs Claude/Pi/OpenCode/Copilot features.
6. **Verify in layers:** CLI version → workflow discovery → deterministic/no-AI workflow → minimal AI provider smoke test → real workflow in an isolated branch/worktree.

## Archon notes

For de gebruiker's TrueNAS/Hermes setup, see `references/archon-truenas-hermes.md`.

For a TrueNAS SCALE Custom App where Archon owns its own dataset but reuses shared Claude/Codex auth, skills, and ProductivityCenter context, use `references/truenas-archon-custom-app.md` and the copy-ready `templates/truenas-archon-custom-app.yml`.

Key gotcha: Archon discovers project-local `.archon/workflows` from the caller's current working directory. A wrapper that `cd`s into the Archon source before launching the CLI will make target-repo workflows invisible.

## Herdr + multi-stack verification

Herdr is a terminal multiplexer for coding agents and pairs well with this skill's "operate external runners from Hermes" scope. For driving Herdr panes/agents locally or on de gebruiker's TrueNAS `herdr-workbox` (SSH port 2223, user `agent`, key gate via `SSH_PUBLIC_KEYS`), see `references/herdr-agent-orchestration.md`.

For auditing one benchmark PR across multiple external agent-skill stacks (Matt = spec/review/retro, pstack = deterministic proof, Addy = browser/performance) with Hermes as the only router, see `references/hybrid-stack-verification.md`. The same SHA-pinning, worktree-isolation and evidence rules there apply to every external runner.

## Verification checklist

- `PATH=/opt/ai-tools/bin:$PATH <runner> version` works.
- The runner's config/home path is under `/opt/ai-tools/config/...`, not a Hermes profile's transient home.
- The runner can list bundled/default workflows.
- From a target git repo, the runner can discover a repo-local `.archon/workflows/*.yaml` workflow.
- A deterministic/no-AI workflow passes before testing paid/authenticated AI runs.
- A minimal AI smoke workflow confirms the selected provider can respond.
- Real development runs use branch/worktree isolation by default.

## Pitfalls

- **Do not save transient install failures as permanent rules.** Capture the workaround, not "tool X is broken".
- **Do not run interactive credential setup through Hermes tool calls.** Use separate terminal/browser flows for secrets where possible, then verify non-secret status afterward.
- **Do not default to `--no-worktree` for real work.** It is useful for smoke tests only; use branch/worktree isolation for development.
- **Do not assume bundled workflows match the configured provider.** Inspect provider fields; many defaults may be hard-coded for Claude or other assistants.
