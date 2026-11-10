# Hybrid cross-stack verification (Matt · pstack · Addy + Hermes router)

Use when a PR or feature must be audited with multiple agent-skill stacks so the user can pick the best one, or when you want a stronger combined verdict than any single lens gives.

## Why it exists

Three public agent-skill stacks genuinely differ in strength:

| Stack | Owner of | Answers | Weakest at |
|---|---|---|---|
| Matt (mattpocock/engineering) | intent, requirements, Standards-vs-Spec review, retro | "are we building the right thing, where are the gaps?" | runtime/browser proof |
| pstack (backnotprop/pstack) | deterministic verification (blast-radius, prove-it-works) | "does it actually work, reproducibly?" | spotting latent UX/spec issues |
| Addy (addyosmani-agent-skills) | browser behavior, console/network, accessibility, performance | "how does it behave in a real browser?" | finishing under tool-call pressure; cost/time |

Hermes stays the **only always-on router**. It picks which phase a risk needs and runs the skill stacks as delegated leaf agents. Never run two or three competing always-on meta-routers (e.g. pstack poteto-mode + Addy using-agent-skills + a review workflow) at once.

## Procedure

1. **Pin one benchmark revision for all stacks.** Pick one PR; record exact base + head SHAs and hand them to every stack. Then you compare *workflow capability*, not repo drift or model differences.
2. **Isolated worktree per stack**, detached at the head SHA. Do not mutate or push the PR's branch during the audit.
3. Run the stacks in a sensible order: Matt first to name the risks/gaps, then pstack to prove each accepted claim, Addy only where browser/performance evidence is relevant.
4. **Force each audit to produce evidence, not prose:** a re-runnable proof script/command for pstack, real browser/RPC assertions for Addy, a Standards-vs-Spec + retro writeup for Matt.
5. Combine the verdicts per lens — expect them to disagree. A spec-hole verdict from Matt and a "no regression proven" verdict from pstack are both true; the merged answer is "no proven regression but unfinished spec coverage" — not a contradiction.

## Pitfalls

- **Different SHAs per stack invalidate the comparison.** Benchmark every stack on the same base+head.
- **Browser/Playwright runs dirty tracked test artifacts.** After any browser run inside a worktree: `git restore -- test-results` and check `git status --short` is empty, or the worktree stops being a clean benchmark.
- **Source-string / JSX-count layout tests prove nothing about rendered behavior** and break on any refactor. Assert rendered layout or browser behavior instead; when you find one, replace it rather than extending it.
- **Do not believe a screenshot filename as evidence a modal opened.** Verify the open/empty/loading state in code or DOM before counting a screenshot.
- **A subagent that hits its tool-call limit may leave the report uncommitted and servers running.** Finish the report in the parent and stop temporary servers after measuring.
- **"Green CI" is not "mergeable" when the harness is stale.** Resolve a smoke spec that contradicts current routes before claiming green; an assertion expecting a route card that now renders is a harness caveat, not proof.
- **A timeout/stall result does not prove the prompt/command was never delivered** (shared with Herdr/agent-control: read state before retrying, never blind-resubmit).

## Deliverable shape

A verdict table / combined report per stack with: evidence path + re-run command, positives, negatives, one-line merge recommendation, and the 3-5 highest-signal findings ranked by impact. Save reports under a shared benchmark root so the user can reopen them.
