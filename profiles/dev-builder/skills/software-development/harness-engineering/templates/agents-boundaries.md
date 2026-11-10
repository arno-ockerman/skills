# AGENTS.md

This file defines operational boundaries for coding agents in this repository. Keep detailed architecture in linked documentation; keep this file short, explicit, and testable.

## Always do

- Read the relevant issue/spec and inspect existing code before editing.
- Use the repository's locked dependency/bootstrap commands.
- Make the smallest change that satisfies the acceptance criteria.
- Run the cheapest relevant checks during iteration.
- Before completion, run the declared final gate and report its real output.
- Preserve or add tests for changed behavior.
- Read back generated/configuration artifacts and inspect `git diff`.

## Never do

- Never commit credentials, tokens, private keys, production data, or local environment files.
- Never delete, weaken, skip, or rewrite tests solely to make a gate pass.
- Never deploy or mutate production systems/data without explicit authorization.
- Never use destructive Git operations or force-push shared branches.
- Never silently expand scope beyond the issue/spec.

## Ask first

Ask before:

- production or release deployment;
- data migration, backfill, deletion, or security-rule change;
- broad dependency upgrades or large lockfile churn;
- destructive cleanup or irreversible external side effects;
- changing public APIs, schemas, billing behavior, or authentication boundaries not required by the spec.

## Gate ladder

### Gate 1 — fast inner loop

```bash
# Replace with repository commands; target seconds, not minutes.
<typecheck>
<lint>
<unit-tests>
```

### Gate 2 — changed-code quality

```bash
<diff-coverage>
<security-scan>
<mutation-or-independent-review>
```

### Gate 3 — system confidence

```bash
<integration-or-e2e>
```

### Gate 4 — release only

```bash
<production-build-or-mobile-release-build>
```

## Retry and escalation

- Maximum autonomous repair attempts: `<N>`.
- After the limit, stop and report the failing gate, relevant logs, attempted fixes, and recommended human decision.
- Record duration, iterations, token/cost data when the harness exposes them.

## Repository-specific facts

- Runtime/toolchain: `<versions>`
- Bootstrap: `<locked install commands>`
- Canonical final verification: `<command>`
- Architecture entry points: `<links, not a full architecture dump>`
- Generated/binary paths to exclude from default context: `<paths>`
