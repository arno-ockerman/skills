# Introducing ESLint into a repository with existing debt

Use this when Week 1/audit proves the repository has no lint gate and the first ESLint run finds too many violations to fix safely in the current scope.

## Goal

Create a deterministic gate that blocks new lint violations without mixing hundreds of unrelated refactors into the harness change.

## Procedure

1. Add ESLint and the stack-specific plugins with a lockfile-preserving package-manager command.
2. Create the real intended configuration first; do not weaken rules merely to get green.
3. Configure generated/vendor/export directories as **global ignores**.
   - With ESLint flat config, keep the global-ignore object separate. Adding `linterOptions`, `files`, or rules to that same object can turn it into a scoped config and allow generated output back into the scan.
4. Run lint once without suppressions and record the actual existing error/warning count.
5. Correct configuration false positives before baselining, especially runtime globals and legitimate CommonJS scripts.
6. Promote warnings that must block CI to errors if the gate uses `--max-warnings=0`; ESLint bulk suppressions primarily baseline violations at error severity.
7. Generate `eslint-suppressions.json` with `eslint . --suppress-all` and commit it. Existing debt is now explicit while new violations still fail.
8. Remove stale `eslint-disable` comments rather than trying to baseline them. Unused-disable diagnostics are not normal suppressible rule findings.
9. If an early baseline accidentally scanned `dist/` or generated output, regenerate from a clean `{}` after fixing global ignores. Do not trust `--prune-suppressions` to remove entries for files that are now ignored.
10. If a monolithic baseline generation or `eslint .` gate exceeds memory, generate/run it in several explicit non-overlapping source scopes. Each baseline process merges into the same suppression file and releases memory on exit. Keep one aggregate `npm run lint` command and verify that every intended source/root area remains covered.
11. Add scripts such as:
    - `typecheck`: `tsc --noEmit`
    - scoped lint commands with a shared `--cache --cache-location .eslintcache`
    - aggregate `lint`: all explicit scopes in sequence
    - `verify:fast`: typecheck → lint → unit tests
12. Measure cold and warm fast-gate wall time separately. Use the warm run for the inner-loop target, retain cold CI timing as operational evidence, and ignore the shared cache file in Git.
13. Create a separate named CI fast job and make expensive build/E2E verification declare `needs: fast-gate`.
14. Prove independence twice:
    - locally, pass a violating snippet over ESLint stdin and assert a non-zero exit without mutating the worktree;
    - on the PR, commit one tiny deliberate violation, record that the fast job fails and the dependent expensive job is skipped, then remove it in a follow-up commit and prove both jobs pass.
15. Preserve failed and repaired CI run URLs in the learning artifact; never merge the deliberately broken revision.

## Verification

- `npm ci` can reproduce the install from the lockfile.
- `npm run lint` exits 0 on the baseline.
- A newly introduced lint violation exits non-zero.
- Generated output does not appear in `eslint-suppressions.json`.
- The suppression file represents current source debt only.
- The fast CI job is a separate named required check and runs before expensive verification.

## Branch protection

- Let the fast check run at least once so its exact GitHub check context exists.
- Read current protection first and preserve unrelated settings.
- Require the exact fast-job check name with strict/up-to-date checks; read protection back after the write.
- In a solo repository, required status checks plus admin enforcement can protect `main` without requiring an approving human review.

## Keep model review separate

An AI review workflow is feedback, not the deterministic gate. Diagnose it independently when typecheck/lint/tests are green. Review plugins that post comments typically need `pull-requests: write` and sometimes `issues: write`; read-only permissions can yield `permission_denials` and `is_error:true` without any code failure or published review. Expanding workflow permissions is an authorization change, so follow repository `ask first` boundaries before editing it.

## Trade-off

A baseline is technical-debt accounting, not a cleanup. Track debt reduction separately and never increase suppressions casually in feature PRs.
