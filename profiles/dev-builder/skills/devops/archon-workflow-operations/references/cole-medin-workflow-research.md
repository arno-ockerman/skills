# Cole Medin / coleam00 workflow research patterns

Use when de gebruiker asks for concrete Cole Medin/coleam00 Archon workflows or examples to adapt for a coding project.

## Search approach that worked

1. Query Cole's GitHub repos, not only the local Archon checkout:
   - `https://api.github.com/users/coleam00/repos?per_page=100&sort=updated`
2. For promising repos, inspect the recursive tree for `.archon`, `workflow`, `workflows`, `commands`, and `.claude` paths:
   - `https://api.github.com/repos/<owner>/<repo>/git/trees/HEAD?recursive=1`
3. Fetch raw workflow YAML files from `raw.githubusercontent.com` and read the actual DAG shape.
4. Use YouTube search as a discovery layer for concepts/video titles, but verify implementation details in GitHub files whenever possible.

## Repos with useful workflow patterns

### `coleam00/Archon`

Useful files:
- `.archon/workflows/defaults/archon-idea-to-pr.yaml`
- `.archon/workflows/defaults/archon-plan-to-pr.yaml`
- `.archon/workflows/defaults/archon-feature-development.yaml`
- `.archon/workflows/defaults/archon-ralph-dag.yaml`
- `.archon/workflows/defaults/archon-piv-loop.yaml`
- `.archon/workflows/defaults/archon-refactor-safely.yaml`
- `.archon/workflows/experimental/archon-fix-github-issue-codex.yaml`

Coding-app patterns to adapt:
- idea → plan → implement → validate → PR → review → fix
- existing plan/PRD → implement → validate → PR
- GitHub issue → classify → smoke-validate issue claims → investigate/plan → implement → validate → review/fix/report
- PRD/story loop: implement one story per iteration, validate before committing
- safe refactor: scan → impact analysis → ordered refactor plan → execute with validation → behavior preservation review

### `coleam00/Archon` — the SDLC pack (current reference pack, replaces `defaults/`)

`defaults/` is deprecated; `packages/workflows/src/defaults/bundle-index.json` ships only `defaults` (deprecation window) and `sdlc`. Read `.archon/workflows/sdlc/<primitive>/` before authoring anything new. Primitives: `triage`, `investigate`, `plan`, `validate`, `implement`, `review`, `deliver`, `pr`, `ship`, `upkeep`, plus (on `cleanup/sdlc-workflows-only`, not `main`) `backlog`, `discoveries`, `merge-queue`, `lifecycle`, `deploy`, `regress`, `verify-runtime`, `verify-runtime-suite`.

Composition rule of the pack: `archon-ship` = triage → (investigate | plan | direct) → deliver → outcome; `archon-lifecycle` = ship + runtime verification + holdout + repair + discoveries + merge + deploy. Advisory workflows (`triage`, `plan`, `investigate`, `upkeep`) declare `mutates_checkout: false` and must leave the checkout untouched.

For issue planning and GitHub publication specifically, see `references/archon-sdlc-pack-and-backlog-intake.md` (`archon-backlog` slices a PRD into issues; `ship` picks them up).

### `coleam00/ai-software-factory`

The consumer that pins the SDLC pack. `template/factory/pack.json` holds `integration_revision_required` (an Archon SHA), `source_directory: .archon/workflows/sdlc`, per-workflow `default_inputs` such as the `state_labels` map, and the workflow entry list. `template/factory/consumer.py` is a thin CLI over `archon workflow run/get/approve/cancel`; scheduling stays outside the pack.

Pattern worth copying: a PRD becomes issues via `archon-backlog`, then a systemd-timer tick runs one composed `archon-lifecycle` over the oldest untouched issue, with merge approval and discovery publication defaulting to human-gated.

### `coleam00/skills` — the PRD/planning skills (Claude plugin `skills@cole-medin`, v1.3.1, 35 skills)

Install: `/plugin marketplace add coleam00/skills` then `/plugin install skills@cole-medin` (plugin skills are namespaced, e.g. `/skills:piv-implement`); or editable files via `npx skills add coleam00/skills --skill <name>`.

The planning chain, in order:

1. `plan-create-prd` — interactive, problem-first PRD interview. Enforces: problem grounded in evidence, a hypothesis with a separate RIGHT and WRONG condition, outcome-shaped metrics, explicit non-goals, open questions named (`TBD — needs validation` instead of invented requirements), and **no engineering decisions**. Writes `<kebab-slug>.prd.md` (docs/, else repo root) — never a hardcoded `PRD.md`, so a second PRD does not overwrite the first. Sections: problem · evidence · thesis · hypothesis · target user/JTBD · MVP · success metrics · non-goals · open questions.
2. `plan-architecture` — the HOW/spec the PRD deliberately left open (libraries+versions, data model, security boundaries, testing architecture, error handling, project structure).
3. `plan-create-stories` — PRD → tickets, `--platform jira|github`. For GitHub it uses `gh issue create` with acceptance criteria as a markdown checklist and a `phase-N` label, creates missing labels with `gh label create`, and prints the proposed list for confirmation before anything is written. Before publishing to a tracker it expects PRD sections "Implementation Phases" and "User Stories".
4. The PIV loop: `prime-*` → `piv-plan-implementation` → `piv-implement` → `piv-validate` → `piv-review-changes`/`piv-review-pr` → `piv-commit` → `piv-create-pr`; `piv-slice-epic` cuts an epic into PIV-sized tickets; `piv-run-full-loop` runs the loop unattended.

Relation to Archon: `archon-backlog` is the workflow translation of steps 1–3 (`slice-backlog.md` states the planner "decomposes the way `plan-create-stories` does"), so a PRD written with `plan-create-prd` is directly the input shape `archon-backlog` expects. `coleam00/build-dark-factory` (in the same repo) takes a PRD and builds the dark factory around it.

### `coleam00/frontend-mix`

Useful file:
- `.archon/workflows/archon-build-frontend-mixed.yaml`

Pattern:
- explore repo → plan architecture/copy → UI design → integration → validation → fix-validation → browser smoke → deploy/summary

Good to adapt for UI-heavy app work: landing pages, dashboards, onboarding flows, screen redesigns, and branded UI.

### `coleam00/archon-idea-to-wo`

Useful file:
- `.archon/archon-idea-to-wo.yaml`

Pattern:
- raw idea → foundation questions → scope/approach → approval → risk/decomposition → approval → work orders → final review

Good to adapt before coding large/vague features.

### `coleam00/ai-transformation-workshop`

Useful file:
- `.archon/workflows/archon-secure-fix-github-issue.yaml`

Pattern:
- GitHub issue → classify → investigate/plan → implement → security/quality scan → remediate → PR

Good to adapt for security-sensitive apps. If SonarQube is not configured, start with project-native gates such as typecheck, tests, migrations check, and dependency audit; add Sonar later.

### Other workflow repos found

- `coleam00/adversarial-dev`: generator/evaluator harness pattern for building from scratch with adversarial quality gates.
- `coleam00/ai-content-factory`: static worker-pool loops with atomic claim scripts; useful for scalable parallel processing workflows.
- `coleam00/archon-video-generation-workflow` and `coleam00/hyperframes-ai-video-generation`: specialist workflow examples, useful mainly for media-generation pipeline structure rather than app feature coding.

## YouTube discovery queries

Useful queries:
- `Cole Medin Archon workflows`
- `Cole Medin AI coding workflow Archon`
- `coleam00 archon coding agent workflow`

Videos that surfaced as relevant concept sources:
- `The OFFICIAL Archon Guide - 10x Your AI Coding Workflow`
- `Pi Coding Agent + Archon: Build ANY AI Coding Workflow`
- `The True Power of AI Coding - Build Your OWN Workflows`
- `The Next Evolution of AI Coding Is Harnesses - Here's How to Build Them`
- `My COMPLETE Agentic Coding Workflow to Build Anything`
- `I Taught My Second Brain to Run Multi-Agent Coding Workflows`

## Porting guidance for project-specific app workflows

For an existing application, prefer adapting patterns into project-specific workflows rather than copying Cole workflows unchanged:

1. Force the provider/model that is actually configured for de gebruiker's environment.
2. Add repo-specific architecture rules and domain constraints to command files.
3. Replace generic validation with exact project commands.
4. Keep mutating workflows in worktree isolation.
5. Use deterministic `bash` nodes for tests, typechecks, migrations, and audits.
6. Reserve interactive workflows for setups where the Archon server/web/chat adapter can handle approval gates smoothly.

**Server schema is authoritative, not the skill docs (verified Nov 2026):** the `archon` skill's reference pages (`variables.md`, `parameter-matrix.md`, `workflow-dag.md`) LAG the deployed server. de gebruiker's 0.13.2 server DOES support `with:` on nodes (483 uses in its own 25 workflows), `$INPUTS.<name>` (345 uses), workflow-level `returns:` (22 uses) and per-node `mutates_checkout` (471 uses) — so Cole's pinned-revision `archon-backlog.yaml` can be ported near-verbatim. When unsure whether a field exists, scan the server's own workflows (`GET /api/workflows` and grep for the field) instead of trusting the skill references. A `$nodeId.output.field` on a schemaless script producer resolves only if the script prints a JSON object with that key (errors to stderr, JSON to stdout). Validate with `/opt/ai-tools/bin/archon validate workflows <name>` from inside the repo (the bundled `archon-smart-pr-review` shows a pre-existing missing-MCP error — ignore it, check only your workflow's own line).
