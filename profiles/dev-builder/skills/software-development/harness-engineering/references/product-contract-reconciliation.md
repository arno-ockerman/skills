# Product-contract reconciliation

Use this when production behavior, ADRs/PRDs, generated issues, and an in-flight implementation PR disagree.

## Outcome

Produce one explicit compatibility baseline, a decision-complete remaining scope, and a dependency graph whose frontier—not the whole backlog—is safe for agents.

## Procedure

1. **Read every authority source.** Inspect current production/main behavior, accepted ADRs, approved PRDs, parent issue and comments, child issues, and the full draft PR diff/tests. Record contradictions without resolving them silently.
2. **Freeze the delivered baseline.** Mark already-shipped tickets as historical/product baseline. Remove or relabel stale future-tense execution waves and estimates so agents do not reimplement deployed work.
3. **Ask only contract-changing questions.** Surface choices that alter observable behavior, lifecycle, privacy, time boundaries, grouping, rollout, or schema. Record the owner's answers verbatim as product decisions before assigning readiness.
4. **Slice vertically.** Each child issue must deliver a narrow end-to-end behavior across authoritative backend, persistence, UI, and tests. Avoid backend/UI/test-only horizontal tickets unless an expand-contract migration makes that unavoidable.
5. **Declare evidence.** Require exact deterministic commands and the correct seam: real callable/rules/emulator tests for authentication, transactions, authorization, time, and rollback; pure-helper or mocked-client tests do not prove those behaviors.
6. **Publish in dependency order.** Create native sub-issues and native `blocked by` relationships where the tracker supports them. Keep textual blocker references too for portability.
7. **Expose only the frontier.** Apply `ready-for-agent` only when requirements are resolved, blockers are merged, and base CI is green. Apply `blocked` to dependency-complete specifications that cannot start yet. Promote them later after read-back verification.
8. **Quarantine stale implementation work.** Keep a useful stale PR draft and clearly mark it blocked/reference-only. List concrete defects and the replacement slices. Do not stack new commits onto it when its contract or branch base is obsolete; port useful code selectively from current main.
9. **Verify external state.** Read back every child issue, labels, sub-issue list, dependency list, parent reconciliation note, and stale-PR title/status/comment. Programmatically compare the exact child count and blocker graph before reporting completion.

## Parent issue rule

Keep the parent as the outcome tracker. Prefer a clearly titled reconciliation comment over rewriting historical source material when traceability matters. Close the parent only after all children merge, required evidence is green, and superseded implementation PRs are closed.

## Readiness distinction

- `needs-decision`: product behavior remains unresolved.
- `blocked`: decisions are complete, but a dependency or base gate is incomplete.
- `ready-for-agent`: decisions are complete, dependencies are merged, base CI is green, and deterministic validation is named.

A ticket can be well written and still not be ready.
