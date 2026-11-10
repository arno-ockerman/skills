# Acting on review findings

Use when a PR or branch has review feedback — from bots, human reviewers, or an agent reviewer — and the job is to decide what is real and land the fixes. This is the consuming half of step 10: a review gate is only closed when its findings have been adjudicated and verified, not when the review was requested.

## 1. Get a working checkout, then collect every channel

Work in a fresh clone of the branch rather than the user's existing checkout: those often sit on another branch with uncommitted work you must not disturb.

```bash
git -c credential.helper='!/path/to/gh auth git-credential' \
  clone --quiet https://github.com/$OWNER/$REPO.git /tmp/pr-review
git -C /tmp/pr-review fetch origin "$BRANCH"
git -C /tmp/pr-review checkout -B "$BRANCH" "origin/$BRANCH"
```

The `-c credential.helper` form matters when `gh` is authenticated but git has no configured helper: git answers `could not read Username for 'https://github.com'`, which reads like a broken token and is not one. Using it per-command avoids mutating the user's global git config. When the process `HOME` is not the account's real home (cron, container exec), also point gh at the auth that already exists instead of re-authenticating: `export GH_CONFIG_DIR=<dir holding hosts.yml>`.

Findings arrive in three separate places, and missing one changes the verdict:

```bash
gh api "repos/$OWNER/$REPO/pulls/$N/comments?per_page=100"   # inline, with diff hunks
gh api "repos/$OWNER/$REPO/issues/$N/comments?per_page=100"  # review summaries
gh pr view "$N" --json reviews                               # review bodies + state
```

Bot summary comments usually restate the inline findings — dedupe on `path:line` before counting, or you will believe there are more issues than exist. Record the head SHA the review was written against; a finding predating the current head may already be addressed.

## 2. Adjudicate against the authority chain, not the reviewer's confidence

Automated reviewers cite authoritative-looking sources and still get them wrong. Read the precedence order out of the repository's own instruction file first, then check each claim against it. The order is usually:

accepted ADR > approved PRD > enforced rules/config > issue acceptance criteria > code comment

Give a verdict per finding (VALID / INVALID) plus the source that settles it. Do not implement a finding on the strength of the reviewer's citation alone, and do not treat the reviewer's severity label as evidence.

## 3. A finding that contradicts a test is a decision, not a bug

If the code you are told to change carries a test **and** an explanatory comment asserting the opposite behaviour, a previous review round most likely put it there deliberately — possibly to hold a privacy or product boundary.

Escalate instead of implementing: present what the reviewer claims, what the existing test and comment assert, and the trade-off, then let the owner choose. Silently inverting a deliberate decision is the failure mode. Where two review rounds contradict each other, that is itself the finding to report.

## 4. Check the interaction effects of every predicate you change

Narrowing a condition can widen behaviour somewhere else. Before editing a shared authorization or validation helper:

- grep every caller of the helper;
- look for other conditions that currently pass only *because of* the bug you are removing.

A guard that refuses a group "by accident" starts permitting that group the moment the accidental condition goes away. When a fix removes an accidental exclusion, make the intended exclusion explicit in the same change and record why in a comment — otherwise the fix opens the hole it was meant to close.

## 5. Do not trust a derived read-model's freshness for authorization

A value written by an asynchronous trigger or background rebuild can still describe the state that was just superseded. Authorizing from it without a freshness check grants access on stale data — which silently breaks any requirement that a relationship change *revoke* immediately.

Prefer the live source of truth for the grant, and use the derived model only to widen beyond it once it is known to be current. If the derived record stores the input it was built from, compare that against current state to decide whether it is still true; if it does not, that field is the fix (add it where the record is written).

## 6. Verify locally before pushing, and attribute the failures honestly

Run the repository's own validation path, not a subset you invented. Two things decide whether a local red is your fault:

- **Mirror the environment that will judge you.** Many runners default `retries: 0` outside CI and 2 or more inside it, at single-worker concurrency; serial-mode suites turn timing noise into hard failures. Set the CI flag (`CI=1`) so the local run matches the gate.
- **A/B against the untouched head.** Save the diff (`git diff > /tmp/fix.patch`), restore the base (`git checkout -- .`), rebuild, and run the *same* suite there. If it also fails — especially at a *different* point — the environment is unreliable and you have no evidence against your change. Restore with `git apply`.
- **Copy the fixture and service set from the project's own runner script** rather than choosing your own subset. A missing emulator, database, or service surfaces as a confusing failure in an unrelated suite, which reads as your regression.
- **Read the run summary, not just the failure.** A serial-mode block (`describe.serial`) aborts at its first failure, and the report then lists the remainder as "did not run" — those tests were never measured, so you cannot conclude the rest is fine, and *which* test fails can move between runs. Never present a serial suite as "only one test failing".
- **Execute any test you added before pushing it.** A fixture you hand-rolled can misdescribe what the code actually writes — an async writer or trigger sets fields a by-hand fixture never guessed — and the resulting failure looks like a defect in the code under test. An unrun new suite is unverified work, not coverage.
- **Widen the worktree scope when the fix is in the repo, not the PR.** If review feedback turns out to require a change the PR does not carry, say so and get agreement before expanding what the branch touches.

When a suite is flaky locally, say so plainly and let CI adjudicate. Never report green on a run you did not get green, and never attribute a failure to your change on evidence you do not have. If the change is not pushed at the end, say explicitly what is staged and where, so the owner can review it.

## 7. Leave provenance in the code

For each non-obvious finding you act on, put a short comment where the change lives explaining what the condition protects. The next review round reads the code, not the PR thread, and will re-raise any rule it cannot see a reason for.
