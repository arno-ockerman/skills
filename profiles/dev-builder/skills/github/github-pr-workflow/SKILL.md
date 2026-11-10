---
name: github-pr-workflow
description: "GitHub PR lifecycle: branch, commit, open, CI, merge."
version: 1.1.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Pull-Requests, CI/CD, Git, Automation, Merge]
    related_skills: [github-auth, github-code-review]
---

# GitHub Pull Request Workflow

Complete guide for managing the PR lifecycle. Each section shows the `gh` way first, then the `git` + `curl` fallback for machines without `gh`.

## Prerequisites

- Authenticated with GitHub (see `github-auth` skill)
- Inside a git repository with a GitHub remote

### Quick Auth Detection

```bash
# Determine which method to use throughout this workflow
if command -v gh &>/dev/null && gh auth status &>/dev/null; then
  AUTH="gh"
else
  AUTH="git"
  # Ensure we have a token for API calls
  if [ -z "$GITHUB_TOKEN" ]; then
    if [ -f ~/.hermes/.env ] && grep -q "^GITHUB_TOKEN=" ~/.hermes/.env; then
      GITHUB_TOKEN=$(grep "^GITHUB_TOKEN=" ~/.hermes/.env | head -1 | cut -d= -f2 | tr -d '\n\r')
    elif grep -q "github.com" ~/.git-credentials 2>/dev/null; then
      GITHUB_TOKEN=$(grep "github.com" ~/.git-credentials 2>/dev/null | head -1 | sed 's|https://[^:]*:\([^@]*\)@.*|\1|')
    fi
  fi
fi
echo "Using: $AUTH"
```

### Extracting Owner/Repo from the Git Remote

Many `curl` commands need `owner/repo`. Extract it from the git remote:

```bash
# Works for both HTTPS and SSH remote URLs
REMOTE_URL=$(git remote get-url origin)
OWNER_REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]||; s|\.git$||')
OWNER=$(echo "$OWNER_REPO" | cut -d/ -f1)
REPO=$(echo "$OWNER_REPO" | cut -d/ -f2)
echo "Owner: $OWNER, Repo: $REPO"
```

---

## 1. Branch Creation

This part is pure `git` — identical either way:

```bash
# Make sure you're up to date
git fetch origin
git checkout main && git pull origin main

# Create and switch to a new branch
git checkout -b feat/add-user-authentication
```

Branch naming conventions:
- `feat/description` — new features
- `fix/description` — bug fixes
- `refactor/description` — code restructuring
- `docs/description` — documentation
- `ci/description` — CI/CD changes

## 2. Making Commits

Use the agent's file tools (`write_file`, `patch`) to make changes, then commit:

```bash
# Stage specific files
git add src/auth.py src/models/user.py tests/test_auth.py

# Commit with a conventional commit message
git commit -m "feat: add JWT-based user authentication

- Add login/register endpoints
- Add User model with password hashing
- Add auth middleware for protected routes
- Add unit tests for auth flow"
```

Commit message format (Conventional Commits):
```
type(scope): short description

Longer explanation if needed. Wrap at 72 characters.
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `ci`, `chore`, `perf`

### Safe staging and cleanup before commit

After running builds, Playwright, exports, or other tooling that may create local artifacts, do **not** combine file deletion with the commit command as one shell line. Treat cleanup as a separate step because deleting generated directories (for example browser caches or build outputs) is a destructive action that may require explicit user confirmation.

Preferred sequence:
1. Inspect `git status --short` first.
2. Stage only the intended source/test files with explicit paths.
3. Commit the code changes.
4. Only then handle generated local artifacts (`.playwright-browsers/`, export output, caches, etc.) in a separate step.

Pitfall: a single command like `rm -rf <generated-dir> && git add ... && git commit ...` can get blocked by safety policy before the commit happens, even when the code itself is ready to ship. Keep destructive cleanup isolated so release commits are not coupled to optional local housekeeping.

### Commit identity preflight

Before committing, verify that git author identity is configured in the current repo or globally:

```bash
git config --get user.name || true
git config --get user.email || true
git config --global --get user.name || true
git config --global --get user.email || true
```

If identity is missing, prefer a repo-local fix over a global one so you do not mutate unrelated repos:

```bash
# Reuse the last author seen in this repo when appropriate
git log -1 --pretty=format:'%an <%ae>'

git config user.name "Hermes Agent"
git config user.email "hermes@local"
```

Pitfall: `git commit` can fail late with `Author identity unknown` even after staging succeeded. For "commit everything" requests, run the identity preflight before the commit command so you do not have to re-diagnose a preventable failure at the end of the flow.

## 3. Pushing and Creating a PR

### Push the Branch (same either way)

```bash
git push -u origin HEAD
```

### Safe direct-to-main sync for deploy fixes

When the user explicitly wants changes pushed straight to the default branch so GitHub/Vercel can redeploy immediately, do a verification-first push instead of blindly sending commits:

1. Confirm you are in the correct repo/worktree before any git action.
2. Run the release-relevant checks first (for example `npm run typecheck`, the focused test command, and the production web export/build) so you do not ship a broken default branch.
3. Commit locally.
4. Push once.
5. If push is rejected because remote is ahead, use:

```bash
git fetch origin main
git rebase origin/main
git push origin main
```

6. After pushing, verify both that the worktree is clean and that local `HEAD` equals `origin/main`.

This pattern is especially useful for hotfixes where the real goal is "get the corrected revision onto GitHub so Vercel rebuilds it".

### Create the PR

**With gh:**

```bash
gh pr create \
  --title "feat: add JWT-based user authentication" \
  --body "## Summary
- Adds login and register API endpoints
- JWT token generation and validation

## Test Plan
- [ ] Unit tests pass

Closes #42"
```

Options: `--draft`, `--reviewer user1,user2`, `--label "enhancement"`, `--base develop`

**With git + curl:**

```bash
BRANCH=$(git branch --show-current)

curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$OWNER/$REPO/pulls \
  -d "{
    \"title\": \"feat: add JWT-based user authentication\",
    \"body\": \"## Summary\nAdds login and register API endpoints.\n\nCloses #42\",
    \"head\": \"$BRANCH\",
    \"base\": \"main\"
  }"
```

The response JSON includes the PR `number` — save it for later commands.

To create as a draft, add `"draft": true` to the JSON body.

## 4. Monitoring CI Status

### Check CI Status

**With gh:**

```bash
# One-shot check
gh pr checks

# Watch until all checks finish (polls every 10s)
gh pr checks --watch
```

**With git + curl:**

```bash
# Get the latest commit SHA on the current branch
SHA=$(git rev-parse HEAD)

# Query the combined status
curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/commits/$SHA/status \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"Overall: {data['state']}\")
for s in data.get('statuses', []):
    print(f\"  {s['context']}: {s['state']} - {s.get('description', '')}\")"

# Also check GitHub Actions check runs (separate endpoint)
curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/commits/$SHA/check-runs \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for cr in data.get('check_runs', []):
    print(f\"  {cr['name']}: {cr['status']} / {cr['conclusion'] or 'pending'}\")"
```

### Poll Until Complete (git + curl)

```bash
# Simple polling loop — check every 30 seconds, up to 10 minutes
SHA=$(git rev-parse HEAD)
for i in $(seq 1 20); do
  STATUS=$(curl -s \
    -H "Authorization: token $GITHUB_TOKEN" \
    https://api.github.com/repos/$OWNER/$REPO/commits/$SHA/status \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['state'])")
  echo "Check $i: $STATUS"
  if [ "$STATUS" = "success" ] || [ "$STATUS" = "failure" ] || [ "$STATUS" = "error" ]; then
    break
  fi
  sleep 30
done
```

## 5. Auto-Fixing CI Failures

When CI fails, diagnose and fix. This loop works with either auth method.

### Step 1: Get Failure Details

**With gh:**

```bash
# List recent workflow runs on this branch
gh run list --branch $(git branch --show-current) --limit 5

# View failed logs
gh run view <RUN_ID> --log-failed
```

**With git + curl:**

```bash
BRANCH=$(git branch --show-current)

# List workflow runs on this branch
curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runs?branch=$BRANCH&per_page=5" \
  | python3 -c "
import sys, json
runs = json.load(sys.stdin)['workflow_runs']
for r in runs:
    print(f\"Run {r['id']}: {r['name']} - {r['conclusion'] or r['status']}\")"

# Get failed job logs (download as zip, extract, read)
RUN_ID=<run_id>
curl -s -L \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/actions/runs/$RUN_ID/logs \
  -o /tmp/ci-logs.zip
cd /tmp && unzip -o ci-logs.zip -d ci-logs && cat ci-logs/*.txt
```

### Step 2: Fix and Push

After identifying the issue, use file tools (`patch`, `write_file`) to fix it:

```bash
git add <fixed_files>
git commit -m "fix: resolve CI failure in <check_name>"
git push
```

### Step 3: Verify

Re-check CI status using the commands from Section 4 above.

### Auto-Fix Loop Pattern

When asked to auto-fix CI, follow this loop:

1. Check CI status → identify failures
2. Read failure logs → understand the error
3. Use `read_file` + `patch`/`write_file` → fix the code
4. `git add . && git commit -m "fix: ..." && git push`
5. Wait for CI → re-check status
6. Repeat if still failing (up to 3 attempts, then ask the user)

## 6. Merging

**With gh:**

```bash
# Squash merge + delete branch (cleanest for feature branches)
gh pr merge --squash --delete-branch

# Enable auto-merge (merges when all checks pass)
gh pr merge --auto --squash --delete-branch
```

**With git + curl:**

```bash
PR_NUMBER=<number>

# Merge the PR via API (squash)
curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/merge \
  -d "{
    \"merge_method\": \"squash\",
    \"commit_title\": \"feat: add user authentication (#$PR_NUMBER)\"
  }"

# Delete the remote branch after merge
BRANCH=$(git branch --show-current)
git push origin --delete $BRANCH

# Switch back to main locally
git checkout main && git pull origin main
git branch -d $BRANCH
```

Merge methods: `"merge"` (merge commit), `"squash"`, `"rebase"`

### Enable Auto-Merge (curl)

```bash
# Auto-merge requires the repo to have it enabled in settings.
# This uses the GraphQL API since REST doesn't support auto-merge.
PR_NODE_ID=$(curl -s \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['node_id'])")

curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/graphql \
  -d "{\"query\": \"mutation { enablePullRequestAutoMerge(input: {pullRequestId: \\\"$PR_NODE_ID\\\", mergeMethod: SQUASH}) { clientMutationId } }\"}"
```

## 7. Complete Workflow Example

```bash
# 1. Start from clean main
git checkout main && git pull origin main

# 2. Branch
git checkout -b fix/login-redirect-bug

# 3. (Agent makes code changes with file tools)

# 4. Commit
git add src/auth/login.py tests/test_login.py
git commit -m "fix: correct redirect URL after login

Preserves the ?next= parameter instead of always redirecting to /dashboard."

# 5. Push
git push -u origin HEAD

# 6. Create PR (picks gh or curl based on what's available)
# ... (see Section 3)

# 7. Monitor CI (see Section 4)

# 8. Merge when green (see Section 6)
```

## Absorbed Workflows

This umbrella also covers adjacent GitHub operations that previously lived as separate micro-skills. Keep the PR lifecycle as the spine, then load the relevant subsection below instead of switching skills.

### Authentication and environment bootstrap

Use `scripts/gh-env.sh` as the canonical helper for exporting GitHub auth state into the current shell. This umbrella now owns the auth bootstrap material that used to live in `github-auth`.

Choose the auth path in this order:
1. `gh auth status` already works → use `gh`
2. `gh` exists but is unauthenticated → `gh auth login` then `gh auth setup-git`
3. No `gh` → configure git HTTPS credentials or SSH keys

Minimum checks:

```bash
git --version
gh --version 2>/dev/null || echo "gh not installed"
gh auth status 2>/dev/null || echo "gh not authenticated"
git config --global credential.helper 2>/dev/null || echo "no git credential helper"
```

For API fallbacks, prefer `GITHUB_TOKEN` from the environment; if absent, extract from `~/.git-credentials` only as a fallback. Always configure `git config --global user.name` and `git config --global user.email` before commit/push workflows.

### Reviewing code and PRs

PR review is part of the same GitHub change-management class. Use this umbrella for both local pre-push review and formal GitHub review submission.

Review sequence:
1. `git diff main...HEAD --stat` for shape
2. `git log main..HEAD --oneline` for commit intent
3. Review file-by-file with `git diff main...HEAD -- <path>` plus `read_file`
4. Scan for debug prints, secrets, TODOs, conflict markers
5. Present findings grouped as **Critical / Warnings / Suggestions / Looks Good**

For formal review output, use `references/review-output-template.md`.

### Issues and triage

Issue creation/triage belongs under the same umbrella because PRs, issues, and fixes form one GitHub maintenance loop.

Common operations:
- List/search issues: `gh issue list`, `gh issue view`, `gh issue list --search ...`
- Create issues from a bug/feature report
- Add/remove labels, assign owners, comment, close/reopen

Reusable templates now live here:
- `templates/bug-report.md`
- `templates/feature-request.md`

### Repository management

Repository creation, forking, cloning, remotes, and releases are the upstream setup stage for PR work. Use this umbrella when the user needs to create a repo, fork, sync a fork, inspect repo metadata, or adjust repo settings before or around PR work.

#### Source-of-truth repo migration / bootstrap

When the user identifies a new GitHub repo as the source of truth for an existing project, treat it as an active migration task, not just a note:
1. Clone or open the target repo and inspect whether it is empty or already contains files.
2. Copy the relevant project subtree into the target repo root using the target repo's intended structure, excluding generated artifacts, local stores, virtualenvs, caches, and secrets.
3. Search copied docs/config for old absolute paths or old repo names and patch them to the new source-of-truth location.
4. Add or update `.gitignore` for project-local artifacts before staging.
5. Run the target repo's real validation path from inside the new repo, plus one representative acceptance flow if the project has CLI/runtime behavior.
6. Commit and push to the target repo, then verify the remote branch points at the pushed commit. If git credentials live outside the process HOME, set the correct HOME only for git network operations rather than changing repo contents.
7. Record only the durable source-of-truth repo/location as memory; do not store one-off commit SHAs or migration progress.

Reference material moved here:
- `references/github-api-cheatsheet.md`
- `references/direct-main-deploy-fix.md` — verification-first pattern for pushing hotfixes to the default branch so GitHub-triggered deploys rebuild the corrected revision

### Consolidation rule of thumb

If the task is fundamentally "operate on a GitHub repo and its contribution workflow," stay in this umbrella. Only break out to another skill when the task is no longer GitHub-centric.

### Pre-commit verification and codebase sizing

Two formerly separate micro-skills belong under the same GitHub change-management umbrella because they answer the questions that naturally happen just before or during a PR:

#### Pre-commit verification

Use this workflow before `git commit`, `git push`, or `gh pr create` when the user wants a real quality gate instead of a surface review.

1. Capture the diff: `git diff --cached`, then `git diff` if nothing is staged.
2. Run focused security scans on added lines for secrets, shell injection, unsafe eval/exec, dangerous deserialization, and SQL-string interpolation.
3. Run the repo's real validation path: tests, lint, and type checks as available.
4. Compare against baseline failures when the repo already has debt; only new failures block the PR.
5. If the change is substantial, use an independent reviewer (`delegate_task`) with only the diff and scan findings.
6. If verification fails, fix only the reported issues and re-run the same gate.

Keep the review verdict grouped as:
- **Critical** — security or correctness blockers
- **Warnings** — regressions, flaky areas, missing tests
- **Suggestions** — non-blocking cleanup or follow-up

#### Codebase sizing and repository inspection

When the user asks "how big is this repo?" or wants language/LOC ratios before planning or reviewing, keep that inside this umbrella rather than switching to a separate micro-skill.

Default command:

```bash
pygount --format=summary \
  --folders-to-skip=".git,node_modules,venv,.venv,__pycache__,.cache,dist,build,.next,.tox,.eggs,vendor,third_party" \
  .
```

Use codebase inspection to support PR work such as:
- scoping risky areas before review
- estimating blast radius of a refactor
- identifying dominant languages/toolchains in unfamiliar repos
- comparing app code vs generated/vendor code

Pitfalls preserved from the absorbed micro-skill:
- always exclude dependency/build directories or pygount becomes noisy and slow
- markdown and docs-heavy files skew toward comments by design
- for very large repos, narrow with `--suffix` instead of scanning everything at once

## Useful PR Commands Reference

| Action | gh | git + curl |
|--------|-----|-----------|
| List my PRs | `gh pr list --author @me` | `curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$OWNER/$REPO/pulls?state=open"` |
| View PR diff | `gh pr diff` | `git diff main...HEAD` (local) or `curl -H "Accept: application/vnd.github.diff" ...` |
| Add comment | `gh pr comment N --body "..."` | `curl -X POST .../issues/N/comments -d '{"body":"..."}'` |
| Request review | `gh pr edit N --add-reviewer user` | `curl -X POST .../pulls/N/requested_reviewers -d '{"reviewers":["user"]}'` |
| Close PR | `gh pr close N` | `curl -X PATCH .../pulls/N -d '{"state":"closed"}'` |
| Check out someone's PR | `gh pr checkout N` | `git fetch origin pull/N/head:pr-N && git checkout pr-N` |
