---
name: create-verification-skill
description: "Use when a repo lacks real product verification."
disable-model-invocation: true
version: 1.0.0
author: Lauren Tan; adapted for Hermes
license: MIT
source: https://github.com/cursor/plugins/tree/main/pstack/skills/create-verification-skill
metadata:
  hermes:
    tags: [verification, harness, e2e]
    related_skills: [maintain-verification-skill, principle-prove-it-works]
---

# Create a Verification Skill

## When to Use

Load when a repository lacks one repeatable way to launch, drive, observe, and clean up the real product.

Create a repository-local Hermes skill at `.hermes/skills/verify-<app>/`. It must let a future agent launch the product, exercise it through a real user-facing interface, capture proof, and clean up safely. Write for an agent reading it cold.

## 1. Interview the repository

Discover from source before asking the user:

- **Surface:** web UI, CLI/TUI, desktop, API, mobile, library, or several surfaces.
- **Run:** exact documented startup/build commands, ports, environment, migrations, seed data, and authentication.
- **Drive:** existing Playwright/Cypress tests, browser/CDP, PTY/tmux helpers, CLI commands, or HTTP endpoints. Prefer existing harnesses.
- **Observe:** screenshots, accessibility snapshots, terminal transcripts, response bodies, logs, exit codes, database or filesystem state.
- **Isolate:** safe ports, data directories, accounts, profiles, and concurrent-run limits.

If the repository does not build or start, fix the baseline first when in scope, otherwise report the blocker precisely. Do not generate instructions against a broken, unverified base.

## 2. Generate `.hermes/skills/verify-<app>/SKILL.md`

Include valid frontmatter with `name: verify-<app>` and a concise trigger description. Ground every section in the repository—leave no placeholders.

- **Launch:** exact commands from empty disposable state to usable state, readiness condition, ownership marker, and teardown.
- **Doctor:** a read-only check for process, expected version/build, owned port/data, and valid auth.
- **Drive:** exact stable selectors, prompts, routes, or commands. Prefer accessibility roles and names over coordinates.
- **Evidence:** capture both action and resulting state; verify persistent/external effects through a second read. Use test/dry-run modes only after observing what they really skip.
- **Cleanup:** stop only processes started by the run and remove disposable state without deleting evidence.
- **Helpers:** document every helper invocation and make scripts executable.

## 3. Seed the feature map

Create `.hermes/skills/verify-<app>/features/README.md` and one file for each of the top 3–5 user-facing features. Follow `references/feature-map-example/`.

Each feature file uses these four H2 sections:

1. `Sub-features`
2. `How to get to it (user POV)`
3. `Driving it with <harness>`
4. `Gotchas`

Do not weaken a journey because seed data or a prerequisite is missing. Record the concrete gap instead.

## 4. Prove the generated skill

Execute its own instructions end to end:

1. Launch.
2. Doctor.
3. Drive one mapped feature.
4. Capture evidence.
5. Clean up.
6. Confirm the evidence survived cleanup and no process or disposable state leaked.

Fix failures and repeat. A generated skill that has not been exercised is a draft, not a deliverable. If verification used a stand-in environment, list what remains unverified on the real target.

## 5. Hand off maintenance

Tell the user to load `maintain-verification-skill` periodically or after user-facing changes.