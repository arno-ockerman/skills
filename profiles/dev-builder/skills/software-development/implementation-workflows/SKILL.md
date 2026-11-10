---
name: implementation-workflows
description: "Use when the user needs a software-delivery workflow choice: plan, spike, debug, strict TDD, or exploratory web-app QA."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [software-development, workflow, planning, debugging, testing, spike]
    related_skills: [subagent-driven-development, requesting-code-review, github-pr-workflow]
---

# Implementation Workflows

## Overview

This is the class-level umbrella for the common software-delivery modes that used to be split across narrow micro-skills: planning-only work, feasibility spikes, root-cause debugging, and strict TDD execution.

Use this skill when the real question is **"which development workflow should I apply right now?"** A human maintainer would keep these as labeled subsections of one delivery playbook, not as disconnected one-session fragments.

## Workflow selector

Choose the subsection by task shape:

| Situation | Subsection |
|---|---|
| User wants a plan instead of implementation | Plan mode |
| User wants to test feasibility or compare approaches before building | Spike mode |
| Something is broken or failing unexpectedly | Systematic debugging |
| User wants implementation with tests-first discipline | Strict TDD |
| User wants exploratory QA of a web app, public surface, or critical user flow | Web app QA / dogfood |

You can chain them in that order as needed:
**spike → plan → TDD → debugging → QA dogfood**.

## 1. Plan mode

Use when the user wants a plan, not execution.

Core rules:
- do not implement product code
- do not mutate project files except the plan artifact itself
- inspect the repo read-only as needed
- deliver a concrete markdown plan saved under `.hermes/plans/`

Recommended plan contents:
- goal
- current context and assumptions
- proposed approach
- bite-sized execution steps
- exact file paths likely to change
- validation commands and expected outcomes
- risks and open questions

Plan-writing standards preserved from the absorbed skill:
- tasks should be small enough to execute in a few focused minutes
- include exact file paths, not vague references
- include concrete verification commands
- if code is discussed, show the intended test targets and likely implementation shape

## 2. Spike mode

Use when the user wants to learn whether something is possible before committing to a production build.

Core loop:
1. decompose the idea into 2-5 feasibility questions when needed
2. do minimal research to choose an approach
3. build a disposable prototype per question
4. record a verdict: VALIDATED, PARTIAL, or INVALIDATED

Rules preserved from the absorbed spike material:
- spikes are throwaway by design
- bias toward something observable (CLI, page, endpoint, or focused test)
- keep dependencies and setup minimal
- when comparing approaches, run parallel variants if the work is substantial
- end each spike with a written recommendation for the real build

## 3. Systematic debugging

Use for bugs, failing tests, broken integrations, performance issues, or any unexpected behavior.

The debugging law:

```text
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Four phases:
1. **Root cause investigation** — read errors, reproduce, inspect recent changes, gather evidence, trace data flow
2. **Pattern analysis** — compare with working examples and references
3. **Hypothesis testing** — make the smallest possible test of one theory at a time
4. **Implementation** — write the regression test, fix the root cause, verify the whole path

Preserved pitfalls:
- do not stack speculative fixes
- do not "just try one quick change" before understanding the failure
- after repeated failed fixes, question the architecture instead of escalating guesswork
- use the lightest debugger that reveals the needed state

## 4. Strict TDD

Use for new features, bug fixes, behavior changes, and most refactors unless the user explicitly waives TDD.

The TDD law:

```text
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

Cycle:
1. write one failing test for one behavior
2. run it and watch it fail for the expected reason
3. write the minimum code to pass
4. run the test again and then the broader suite
5. refactor only while keeping tests green

Preserved rules:
- if code was written before the test, delete it and restart from tests
- a test that passes immediately proves little; fix the test
- behavior beats implementation-detail testing
- edge cases and regression coverage matter, not just happy-path validation

## 5. Web app QA / dogfood

Use when the user wants an exploratory QA pass against a web app, public launch surface, checkout/auth flow, onboarding path, marketing page, or release-critical browser path.

Default workflow:
1. Define scope and output directory.
2. Build a lightweight sitemap of pages and flows to test.
3. For each page/flow, navigate, inspect DOM/snapshot, visually inspect layout, exercise interactive elements, and check console errors after navigation and significant interactions.
4. Capture evidence for every issue: URL, repro steps, expected vs actual behavior, screenshot path, and console output when relevant.
5. De-duplicate and classify findings by severity and category.
6. Produce a structured report with executive summary, issue table, per-issue repros, and testing notes.

Support files moved here from the former `dogfood` skill:
- `references/web-app-qa-issue-taxonomy.md` — severity/category taxonomy
- `templates/web-app-qa-report-template.md` — final report structure

Pitfalls:
- Do not call exploratory QA done without checking the browser console.
- Do not just list visual impressions; exercise forms, buttons, links, empty states, invalid inputs, and keyboard navigation where in scope.
- Evidence matters: include screenshots or exact console errors for every substantive bug.

## Common sequencing patterns

### Credential-blocked backend MVP

When a production backend/project/credentials are not available yet but the user wants fast progress, do not stop at docs or say "waiting on credentials". Build a runnable local access layer with a swappable adapter, verify the real user flow locally, and prepare seed/runbook artifacts for the real backend. See `references/credential-blocked-backend-mvp.md` for the reusable pattern.

### Local CLI-backed CRM/context capture

When the user provides raw people/contact notes for a local CRM MVP, do not just summarize them back. Search existing contacts first, then capture contact status, latest interaction, durable memories, and explicit follow-ups. Verify with aggregate counts plus a real CRM query such as due follow-ups or a contact briefing. If follow-up due dates are human-entered naive strings, add/keep regression coverage for naive-vs-aware datetime comparisons. See `references/local-crm-capture-and-followup-datetime.md` for the detailed pattern and fix.

### Supabase-backed CRM continuation

When a local CRM capture later needs to become the real Personal CRM, first verify the canonical repo and backend (`supabase-rest`) before claiming data is in Supabase. If the previous capture was local-only, migrate via the CLI into Supabase, then verify with health counts plus a real briefing query. Add the next smallest CRM capability via TDD rather than jumping to UI. See `references/supabase-backed-crm-continuation.md` for the detailed pattern.

### Credential-unblocked hosted backend bootstrap

When the user provides a hosted backend URL/project ref and credentials, move from planning to a real remote-backed MVP: store secrets only in `.env`, link the provider CLI, push reproducible migrations, seed stable tenant/auth records, expose API grants, implement a swappable remote adapter, verify with non-destructive real commands, then commit only safe artifacts. See `references/hosted-backend-cli-bootstrap.md` for the detailed checklist.

### Feature work
1. Start in **Plan mode** if the user wants design before execution.
2. Move to **Strict TDD** for implementation.
3. Use **Systematic debugging** only when the TDD cycle exposes confusing failures.

### Risky idea or unfamiliar stack
1. Start with **Spike mode**.
2. If validated, convert findings into **Plan mode** output.
3. Implement with **Strict TDD**.

### Production bug
1. Start with **Systematic debugging**.
2. Once root cause is understood, fix via **Strict TDD** with a regression test.

## Pitfalls

- creating a new micro-skill for one delivery phase instead of using this umbrella
- mixing planning and implementation in the same step when the user asked for a plan only
- keeping spike artifacts as production code without a fresh implementation pass
- proposing fixes before root-cause evidence exists
- claiming TDD when the test never failed first

## Verification checklist

- [ ] Chose the subsection that matches the user’s real workflow need
- [ ] Kept the deliverable aligned with that mode (plan, spike artifact, diagnosis, or test-first code)
- [ ] Used exact file paths and concrete commands when producing instructions
- [ ] Preserved verification steps rather than stopping at prose
- [ ] Switched modes deliberately instead of blending them accidentally
