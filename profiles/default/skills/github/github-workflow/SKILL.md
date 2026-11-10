---
name: github-workflow
description: "Complete GitHub workflow: auth, repos, issues, PRs, code review, CI/CD, releases. Use when working with GitHub in any capacity — cloning, creating, reviewing, merging, or automating."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Git, Authentication, Pull-Requests, Issues, CI/CD, Releases, Code-Review, Repository-Management]
    related_skills: [hermes-agent, plan, requesting-code-review]
---

# GitHub Workflow — Complete Reference

This umbrella skill covers the entire GitHub lifecycle. All sections share the same auth detection pattern (gh CLI first, curl fallback) and repo detection logic. Use the `gh-env.sh` helper to auto-configure environment variables.

## Quick Start: Auth Detection

```bash
source "${HERMES_HOME:-$HOME/.hermes}/skills/github/github-workflow/scripts/gh-env.sh"
# Sets: GH_AUTH_METHOD, GITHUB_TOKEN, GH_USER, GH_OWNER, GH_REPO, GH_OWNER_REPO
```

The script handles: gh CLI OAuth, .env token, git credential store, and extracts owner/repo from the current git remote.

---

## 1. Authentication

### Methods
- **HTTPS + Personal Access Token** (portable, no SSH config) — `git config --global credential.helper store`
- **SSH Keys** — `ssh-keygen -t ed25519`, add to GitHub, `git config --global url."git@github.com:".insteadOf "https://github.com/"`
- **gh CLI** — `gh auth login` (interactive) or `echo $TOKEN | gh auth login --with-token`

### Scopes Needed
- `repo` — full repository access (read, write, push, PRs)
- `workflow` — trigger/manage GitHub Actions
- `read:org` — organization repos

### Verify
```bash
gh auth status  # or: curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
```

---

## 2. Repository Management

### Clone
```bash
git clone https://github.com/owner/repo.git
# or: gh repo clone owner/repo [-- --depth 1]
```

### Create
```bash
gh repo create my-project --public --clone
# or via API: curl -X POST -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user/repos -d '{"name":"my-project","private":false}'
```

### Fork & Sync
```bash
gh repo fork owner/repo --clone
git remote add upstream https://github.com/owner/repo.git
git fetch upstream && git merge upstream/main  # keep fork updated
```

### Settings & Secrets
```bash
gh repo edit --description "..." --enable-wiki=false --add-topic "tag1,tag2"
gh secret set API_KEY --body "value"
gh secret list
```

### Releases
```bash
gh release create v1.0.0 --title "v1.0.0" --generate-notes
gh release create v1.0.0 ./dist/binary --notes "Changelog"
gh release list
```

### GitHub Actions
```bash
gh workflow list
gh run list --limit 10
gh run view <RUN_ID> --log-failed
gh run rerun <RUN_ID> [--failed]
gh workflow run ci.yml --ref main
```

---

## 3. Issues

### View & Search
```bash
gh issue list [--state open] [--label bug] [--assignee @me] [--search "text"]
gh issue view 42
```

### Create
```bash
gh issue create --title "Bug: ..." --body "## Description\n..." --label "bug,backend" --assignee "user"
# Templates in: templates/bug-report.md, templates/feature-request.md
```

### Manage
```bash
gh issue edit 42 --add-label "priority:high" --remove-label "needs-triage"
gh issue edit 42 --add-assignee @me
gh issue comment 42 --body "Investigating..."
gh issue close 42 [--reason "completed|not_planned"]
gh issue reopen 42
```

### Triage Workflow
1. `gh issue list --label "needs-triage"` → 2. View & categorize → 3. Label & assign → 4. Comment with triage notes

---

## 4. Pull Request Workflow

### Branch & Commit
```bash
git checkout main && git pull origin main
git checkout -b feat/description
git add . && git commit -m "feat(scope): description\n\n- Detail 1\n- Detail 2\n\nCloses #42"
```

### Push & Create PR
```bash
git push -u origin HEAD
gh pr create --title "feat: ..." --body "## Summary\n- ...\n\nCloses #42" [--draft] [--reviewer user1,user2]
```

### Monitor CI
```bash
gh pr checks                    # one-shot
gh pr checks --watch           # polls every 10s
```

### Auto-Fix CI Failures
1. `gh run list --branch <branch> --limit 5` → find failed run
2. `gh run view <RUN_ID> --log-failed` → read errors
3. Fix with file tools → `git add . && git commit -m "fix: resolve CI failure" && git push`
4. Re-check with `gh pr checks --watch`

### Merge
```bash
gh pr merge --squash --delete-branch          # cleanest for features
gh pr merge --auto --squash --delete-branch   # merge when green
```

---

## 5. Code Review

### Local (Pre-Push)
```bash
git diff main...HEAD --stat          # scope
git diff main...HEAD                 # full diff
# Check for: debug statements, secrets, large files, merge markers, TODO/FIXME
```

### Review PR on GitHub
```bash
gh pr view 123
gh pr diff 123 [--name-only]
gh pr checkout 123                  # check out locally for full review
```

### Leave Comments
```bash
# General comment
gh pr comment 123 --body "Overall looks good"

# Inline comment (requires HEAD SHA)
HEAD_SHA=$(gh pr view 123 --json headRefOid --jq '.headRefOid')
gh api repos/$GH_OWNER/$GH_REPO/pulls/123/comments \
  --method POST -f body="Simplify this" -f path="src/file.py" -f commit_id="$HEAD_SHA" -f line=45 -f side="RIGHT"
```

### Submit Formal Review
```bash
gh pr review 123 --approve --body "LGTM!"
gh pr review 123 --request-changes --body "See inline comments."
gh pr review 123 --comment --body "Suggestions only."
```

### Review Output Format
Use the structure from `references/review-output-template.md`:
```
## Code Review Summary
**Verdict: [Approved ✅ | Changes Requested 🔴 | Reviewed 💬]**

### 🔴 Critical (blocks merge)
- **file.py:line** — Issue. Suggestion: fix.

### ⚠️ Warnings (should fix)
- **file.py:line** — Issue.

### 💡 Suggestions (non-blocking)
- **file.py:line** — Improvement.

### ✅ Looks Good
- Positive observations.
```

---

## 6. API Reference (curl Fallbacks)

All operations work without `gh` using the GitHub REST API. The `gh-env.sh` script sets up `GITHUB_TOKEN`, `GH_OWNER`, `GH_REPO`. See `references/github-api-cheatsheet.md` for the complete endpoint table.

Key endpoints:
- Repos: `GET/POST/PATCH/DELETE /repos/{owner}/{repo}`
- PRs: `GET/POST /repos/{owner}/{repo}/pulls`, `PUT /pulls/{num}/merge`, `POST /pulls/{num}/reviews`
- Issues: `GET/POST /repos/{owner}/{repo}/issues`, `POST /issues/{num}/labels`
- CI: `GET /repos/{owner}/{repo}/actions/runs`, `GET /commits/{sha}/status`, `GET /commits/{sha}/check-runs`
- Releases: `GET/POST /repos/{owner}/{repo}/releases`
- Secrets: `GET /repos/{owner}/{repo}/actions/secrets`, `PUT /secrets/{name}` (requires encryption)

---

## 7. Templates & References

All templates and reference files live in this skill's support directories:

| File | Purpose |
|------|---------|
| `templates/pr-body-feature.md` | Feature PR body template |
| `templates/pr-body-bugfix.md` | Bugfix PR body template |
| `templates/bug-report.md` | Issue bug report template |
| `templates/feature-request.md` | Issue feature request template |
| `references/review-output-template.md` | Code review summary format |
| `references/ci-troubleshooting.md` | Common CI failure patterns & fixes |
| `references/conventional-commits.md` | Commit message format guide |
| `references/github-api-cheatsheet.md` | Complete REST API endpoint table |
| `scripts/gh-env.sh` | Auth + repo detection helper (source this first) |

---

## Common Pitfalls

| Problem | Solution |
|---------|----------|
| `git push` asks for password | GitHub disabled password auth — use PAT as password or switch to SSH |
| `remote: Permission denied` | Token missing `repo` scope — regenerate with correct scopes |
| `Authentication failed` | Cached creds stale — `git credential reject` then re-auth |
| SSH connection refused | Use SSH over HTTPS port: `Host github.com` + `Port 443` + `Hostname ssh.github.com` in `~/.ssh/config` |
| Credentials not persisting | Check `git config --global credential.helper` — must be `store` or `cache` |
| Multiple GitHub accounts | Use SSH host aliases in `~/.ssh/config` or per-repo credential URLs |
| `gh: command not found` | Use git-only auth method above — no installation needed |

---

## When to Use Each Section

| Task | Section |
|------|---------|
| First-time GitHub setup | 1. Authentication |
| Clone/create/fork repo | 2. Repository Management |
| Manage releases, secrets, Actions | 2. Repository Management |
| Create/triage/assign issues | 3. Issues |
| Branch, commit, push, open PR | 4. Pull Request Workflow |
| Monitor/fix CI | 4. Pull Request Workflow |
| Merge PR | 4. Pull Request Workflow |
| Review code (local or PR) | 5. Code Review |
| Use API directly (no gh) | 6. API Reference |