# Repository audit and boundary procedure

Use this reference for Week-1-style harness audits and before changing repository-level agent instructions.

## 1. Preflight

Record:

- repository root, remote, branch, baseline commit, and working-tree status;
- package managers and lockfiles, including nested backend/functions packages;
- runtime versions documented in the repo versus versions used by CI;
- existing `AGENTS.md`, `CLAUDE.md`, hooks, permissions, workflows, review agents, and canonical verify scripts.

Do not modify instructions or CI yet.

## 2. Bootstrap versus code health

Run the declared checks once to expose prerequisite failures, then install deterministically from lockfiles and rerun. Label failures explicitly:

- bootstrap/tooling failure;
- source/type/test failure;
- infrastructure/emulator failure;
- credential/external-service failure.

This prevents treating missing dependencies as broken product code. Beware package runners that download a same-named package when the intended local binary is absent.

## 3. Warm timing table

Measure each command separately with elapsed seconds and real exit code:

| Layer | Typical command | Why separate it |
|---|---|---|
| Typecheck | `tsc --noEmit` | fast structural feedback |
| Lint | repository lint script | policy/style correctness |
| Unit tests | test runner in CI mode | behavior feedback |
| Frontend build | production build | bundler/integration feedback |
| Backend build | nested package build | separate dependency graph |
| E2E | emulator/browser suite | expensive system confidence |

Keep cold install timing separate from warm gate timing. A monolithic `verify` command can remain the final gate while still being inappropriate for every retry.

## 4. Context inventory

Exclude obvious generated/vendor directories (`.git`, `node_modules`, `dist`, `build`, coverage, emulator data, test reports). Report:

1. largest individual files;
2. largest top-level directories;
3. size/count by extension;
4. large textual source/instruction files separately from binary/export artifacts.

Interpretation:

- large binaries and database exports are discovery/noise hazards;
- large TS/TSX/translation/instruction files are direct prompt-budget hazards;
- high context cost is not automatically an architecture defect, but it should shape targeted reads and later module boundaries.

Use `scripts/repo-context-inventory.py` for the deterministic inventory.

## 5. Three-tier boundary review

Classify every repository instruction:

### Always do

Cheap, universal, repeatable obligations: locked bootstrap, scoped tests, typecheck, format, read-back verification.

### Never do

Normally forbidden actions: commit secrets, bypass/remove tests to get green, destructive Git, production data mutation, silent force-push, uncontrolled deployment.

### Ask first

Legitimate but side-effecting or scope-dependent actions: production deploys, migrations/backfills, security-rule changes, broad dependency upgrades, lockfile churn, destructive cleanup.

Check for documentation/CI contradictions. Descriptive architecture prose is useful but does not replace operational boundaries.

## 6. Bounded observability probe

Before paying for inference, verify CLI version and non-secret auth status. Then prefer:

- print/non-interactive mode;
- tools disabled or explicit allowlist;
- plan/default permission mode;
- no session persistence for the probe;
- JSON or stream-JSON output;
- debug output to a disposable file;
- a small hard budget;
- a trivial prompt with no repository modifications.

Summarize system initialization, loaded tools/skills/instructions, token usage, cache usage, duration, and cost. Do not persist credentials or full sensitive prompt payloads in the skill library.

## 7. Artifact and learning verification

Artifact gates:

- audit document exists and names baseline commit;
- command table contains exit codes and durations;
- local links/templates parse;
- `git diff --check` is clean;
- any written configuration is read back.

Learning gates:

- learner explains model/harness/gate without notes;
- learner classifies representative actions into the three tiers;
- learner names the repository's top context risks from memory.

Do not mark the learning exit criterion complete merely because the teacher created the files.
