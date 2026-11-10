---
name: autonomous-maintenance-jobs
description: "Use when scheduled agents turn live signals into PRs."
version: 1.0.0
metadata:
  hermes:
    tags: [automation, cron, observability, pull-requests, ci, safety]
    category: software-development
---

# Autonomous Maintenance Jobs

Operate scheduled agents that inspect live operational signals, deduplicate existing work, implement bounded fixes, and deliver reviewable pull requests without unintended production changes.

## Procedure

### 1. Define the action contract before scheduling

Write the loop explicitly:

```text
collect → sanitize → deduplicate → diagnose → implement → verify → publish → read back
```

State which external writes are allowed. Default to PRs and issue updates only; prohibit merge, production deployment, database writes, and resolving monitoring incidents unless the user authorizes them separately. Encode these boundaries in workflow conditions and permissions, not only in the prompt.

### 2. Make cadence and retries deterministic

Use a stable monitor key for each intended cycle so scheduler retries and DST-safe polling do not repeat work. Persist enough continuity to recognize already-triaged fingerprints, existing issues, and active PRs. Treat collection as retryable and every write as idempotent.

### 3. Probe credentials without exposing them

Load credentials from the profile-local secret store, never from the product repository. Probe the exact read endpoint before enabling code changes; an upload token can authenticate while lacking issue/event read scope. Print only non-secret status and sanitize operational payloads before they reach files, logs, PR bodies, or agent context.

### 4. Establish a writable isolated workspace

Treat the canonical repository as read/fetch source. Before the first edit:

1. fetch the current base branch;
2. create a dedicated git worktree below the configured write-safe root;
3. confirm the chosen path is inside that root;
4. confirm `git status --short` is clean;
5. read repository mission and agent instructions from the worktree.

If a file mutation is denied, do not bypass the guard with shell or Python writes. Recreate the worktree under the permitted root, reapply the exact edit with file tools, and verify the resulting diff. A later successful workaround does not erase an earlier failed mutation unless the pushed PR demonstrably contains the intended file change.

### 5. Deduplicate before implementation

Fetch current live findings and check open/merged PRs and issues before branching. Group findings by shared root cause rather than event count. Update an automation-owned branch only when its base and intent still match; never overwrite a human-owned or unrelated branch. Create no empty PR when existing work already covers the finding.

### 6. Implement evidence-backed fixes

Require representative sanitized events, release/environment/platform classification, and a plausible application call path before changing code. For noise filters, use the signature visible at the actual interception point, not a processed or source-mapped representation that exists only after upload. Add a control test proving legitimate application errors with similar text remain reportable.

Run focused regression tests first, then the repository's deterministic typecheck, lint/diff, build/export, migration checks, and broad suite as applicable. Report only commands actually executed and preserve existing safety gates.

### 7. Keep CI green without mutating shared backends

Separate frontend preview creation from shared backend deployment. Pull-request workflows may build an isolated preview, but shared functions, migrations, and production resources must be guarded for approved main-branch or manual runs, for example:

```yaml
- name: Deploy shared backend functions
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

Never cancel an entire workflow merely to prevent one deployment step. GitHub marks pending and conditionally skipped jobs as cancelled failures, which leaves an otherwise-correct PR unstable. Change the workflow policy first, push a new head, and let the replacement run finish normally.

### 8. Verify the published state, not the narrative

Before reporting completion:

1. confirm the actual PR worktree is clean;
2. confirm local HEAD equals the remote branch head;
3. confirm the PR head equals that commit;
4. confirm every intended file appears in the PR diff;
5. inspect the latest check run, not an older cancelled run;
6. verify each sensitive step is `skipped` or `success` for the intended reason;
7. read back the PR body after updating it.

A successful tool call is not proof of external state. Historical cancelled runs remain visible in GitHub; distinguish them from the current head's checks.

### 9. Report for human review

Return a concise Dutch summary containing the current unresolved count, root-cause groups fixed or queued, PR/issue URLs, exact verification results, skipped side effects, and blockers. Never describe a cancelled job as a code failure, and never call a PR green while its current head still has pending or failing required checks.

## Pitfalls

- **Writing outside the safe root:** file tools reject the mutation, and later prose can falsely imply it landed; create the editable worktree in the permitted root first.
- **Cancelling CI to enforce policy:** cancellation turns unrelated pending jobs red; encode skip conditions in the workflow and rerun on a new head.
- **Preview coupled to backend deployment:** a harmless frontend preview can mutate shared production services; split or guard the backend step.
- **Reading stale checks:** GitHub preserves old runs; always match checks to the PR's current head SHA.
- **Trusting a generated report:** verify remote branch, PR files, checks, and body directly before delivery.
- **Filtering processed-only signatures:** runtime hooks often see minified/pre-upload frames; test the representation observed at that hook.
