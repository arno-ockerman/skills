---
name: harness-engineering
description: "Design, audit, teach, and improve coding-agent harnesses: repository context, AGENTS.md boundaries, deterministic gates, observability, retry limits, cost controls, and transfer across web/mobile projects."
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [harness-engineering, coding-agents, agents-md, quality-gates, ci, observability]
    category: software-development
---

# Harness Engineering

Use this class-level skill when the user wants to understand, audit, design, teach, or build the control system around coding agents—not merely ask an agent to implement code. The harness includes context assembly, repository instructions, tools, permissions, workspace isolation, deterministic verification, CI feedback, budgets, retries, and human escalation.

## Core model

Keep these layers distinct:

- **Model:** proposes text/actions from the context it receives.
- **Harness:** controls context, tools, permissions, lifecycle, feedback, budget, and stop conditions.
- **Gate:** an external reproducible decision such as an exit code, policy, test, coverage threshold, or security finding.

If the same unconstrained agent both creates the change and freely decides whether it is good enough, that is feedback—not an independent gate.

## Operating sequence

1. **Establish the mission and transfer target.** Name the practice repository, eventual target stack, weekly budget, and objective exit criteria.
2. **Audit before redesigning.** Inspect existing `AGENTS.md`/`CLAUDE.md`, scripts, CI workflows, lockfiles, tests, generated data, large files, and current agent-review workflows.
3. **Bootstrap deterministically.** Install from lockfiles before timing gates. Distinguish environment/bootstrap failures from code failures.
4. **Measure warm commands independently.** Time typecheck, lint, unit tests, builds, Functions/backend builds, and E2E separately. Do not infer a fast inner loop from one monolithic `verify` command.
5. **Inventory context risks.** Exclude vendor/generated output, then report both discovery hazards (large binaries/exports) and actual textual prompt hazards (large source/instruction files).
6. **Classify repository boundaries.** Rewrite instructions into `always do`, `never do`, and `ask first`; identify contradictions between docs and CI.
7. **Probe observability safely.** Verify CLI version/auth first; use no-tools/plan mode, no session persistence, structured output, a debug file, and a small hard budget for context inspection.
8. **Build a gate ladder.** Cheap deterministic checks first; expensive E2E/mobile/build/deploy checks later. Gates must run outside free model discretion.
9. **Close the loop with limits.** Feed CI failures back to the worker, cap retries, log iterations/tokens/duration/cost, then escalate to a human.
10. **Close asynchronous review gates.** Dispatching an independent review is not completion: wait for its findings before the first commit when it is a declared pre-commit gate. If feedback lands after a PR update, resolve it in a focused commit and rerun CI against the new head SHA. Adjudicate every finding against the repository's authority chain before implementing it — see `references/acting-on-review-findings.md`.
11. **Reconcile drifted epics into a real execution frontier.** Separate deployed baseline from remaining work, resolve product decisions with the owner, publish narrow vertical sub-issues, encode native blocking edges, and apply `ready-for-agent` only to tickets whose dependencies are already complete. Keep stale implementation PRs as clearly blocked reference material rather than stacking more work onto a branch built from the wrong contract.
12. **Verify and teach via retrieval.** An artifact existing is not evidence the user learned. Require the user to explain boundaries and identify repo-specific context risks without reading the audit.

## Repository audit rules

- Record the baseline commit and whether the working tree was clean.
- Capture initial failures and successful post-bootstrap timings; both are useful evidence.
- Prefer `npm ci`/locked installs in reproducible environments over unconstrained dependency resolution.
- Never run broad auto-fix commands for dependency/security findings during a baseline audit. Record them and scope a separate task.
- Treat `git diff --check`, file existence, HTML/local-link checks, and read-back verification as artifact gates.
- Do not edit `AGENTS.md` blindly when teaching: first present the classification, ask the learner to attempt it, then review and apply.
- Treat repository instruction files as approval-gated artifacts. Keep their edit separate from unrelated work; if approval expires, never bypass the guard or switch tools—continue safe work and retry only after fresh explicit approval.
- Make product authority explicit in repository instructions: production behavior and accepted ADRs are the compatibility baseline; approved PRDs may intentionally change it; tickets decompose decisions; implementation plans remain subordinate. Conflicts and open product decisions must stop implementation.

## Support files

- Read `references/repo-audit-and-boundaries.md` for the detailed audit, timing, context-inventory, and observability procedure.
- Read `references/eslint-existing-debt-gate.md` when introducing a real lint gate into a repository whose first scan reveals substantial existing debt.
- Read `references/product-contract-reconciliation.md` when a shipped baseline, stale epic, generated tickets, and an in-flight draft PR disagree.
- Read `references/acting-on-review-findings.md` when implementing reviewer or bot feedback on a PR: collecting all comment channels, adjudicating VALID/INVALID against the authority chain, interaction effects of a narrowed predicate, and attributing a failing local suite honestly.
- Read `references/runtime-context-audit.md` when a context meter looks unexpectedly large or an agent session approaches its model window.
- Copy and tailor `templates/agents-boundaries.md` when restructuring repository agent instructions.
- Run `scripts/repo-context-inventory.py <repo>` for a deterministic JSON inventory of context-heavy files and directories.

## Pitfalls

- **Timing before bootstrap:** produces misleading failures and may cause package runners to download similarly named but wrong tools.
- **One giant verify command:** deterministic can still be too slow for the inner loop; split gates by cost and purpose.
- **Fixing all lint debt while adding the gate:** baseline current violations explicitly, block new violations, and clean debt in separately scoped work.
- **Flat-config ignores mixed with other options:** ESLint global ignores should live in their own config object; adding `linterOptions`, `files`, or rules can cause generated output to be scanned and baselined.
- **Trusting a polluted suppression file:** after correcting ignores, regenerate bulk suppressions from a clean file; pruning may retain entries for files that are now ignored.
- **Counting raw repository size as prompt context:** separate binary/export discovery noise from source files an agent may actually read.
- **Confusing context capacity with context consumption:** a lone `272k context` label can be the provider-enforced window; require a used/max value, percentage, or request-token telemetry before calling it usage.
- **Blaming memory for context growth without measurement:** fixed prompts and compact user memory are often minor; aggregate active history by role/tool because terminal, file-read, diff, and loaded-skill outputs commonly dominate.
- **Trusting configured compression instead of observed compression:** verify the effective provider-aware threshold and inspect whether the summarizer actually committed a smaller context; fallback auth, quota, or output-budget failures can leave an oversized session unchanged.
- **Architecture prose without permissions:** repository descriptions do not substitute for explicit side-effect boundaries.
- **Documentation/CI drift:** compare runtime versions, package-manager commands, and required gates in both places.
- **Instruction-mandated duplicate of a declared gate:** when the repository instructions order the agent to run the full suite before finishing, and CI already enforces that same suite as a required check, every run pays for it twice — and each run's output re-enters the context and is re-sent on every later turn, so the cost compounds beyond the wall-clock. Count the agent's own check invocations in a run's tool log; several runs of the same full suite is the signature. Narrow the instruction to the fast inner loop, let CI own the expensive gate, and confirm the redundancy against the CI workflow before proposing it — removing a local duplicate of a CI job costs no coverage.
- **Making the agent provision its own runtime:** when the environment lacks a runtime a declared gate needs, the agent downloads it mid-run into a temp directory — spending turns and context on setup unrelated to the task, and leaving the download behind. Put the runtime on `PATH` once, at the version the CI workflow pins, so no run has to fetch it.
- **Treating AI review failure as a code-gate failure:** inspect deterministic checks separately; a review action can fail with permission denials when it has read-only PR/issue scopes but its plugin tries to publish comments. Follow `ask first` before expanding workflow authorization.
- **Verbose probe before auth preflight:** verify non-secret auth status first so a failed probe is not mistaken for an observability limitation.
- **Saving setup failures as durable constraints:** capture the reproducible preflight/fix, never “tool X does not work.”
- **Labelling blocked tickets ready:** a complete specification is not enough; `ready-for-agent` also requires all blocking dependencies merged and base CI green. Label only the current execution frontier and promote dependants after verified blocker completion.
- **Repairing a stale mega-PR in place:** when its product contract and branch base are obsolete, mark it blocked/reference-only, extract validated vertical slices from current main, and close it only after the replacement path is proven.
- **Doing every student exercise for them:** build scaffolding and feedback loops, but preserve retrieval practice for core concepts.

## Verification checklist

- [ ] Mission, practice repo, transfer target, time budget, and exit criteria recorded.
- [ ] Existing instructions, scripts, CI, tests, and review workflows inspected.
- [ ] Dependencies bootstrapped from lockfiles.
- [ ] Warm durations measured per command with real exit codes.
- [ ] Context hazards split into binary/generated and textual/source categories.
- [ ] `always` / `never` / `ask first` gaps documented.
- [ ] CLI observability probe uses bounded permissions, persistence, and cost.
- [ ] Gate ladder separates cheap inner-loop checks from expensive checks.
- [ ] Retry limit, telemetry, and human escalation are explicit.
- [ ] Artifacts are read back and learner understanding is demonstrated objectively.
