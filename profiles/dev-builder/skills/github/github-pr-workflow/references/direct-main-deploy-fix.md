# Direct-to-main deploy fix pattern

Use this when the user wants all local fixes pushed so an attached deploy system (for example Vercel) rebuilds from GitHub immediately.

## Why this exists

A deploy fix is not complete when the file is edited locally. It is only complete when:
- the relevant build/test commands pass,
- the commit is on the tracked remote branch,
- and the branch tip on GitHub matches local HEAD.

## Minimal sequence

```bash
# in the correct repo
git status --short

git branch --show-current
git remote -v

# app-specific verification before pushing
npm run typecheck
npm test -- --runInBand
npm run export:web

# commit and push
git add -A
git commit -m "fix: restore deployable production setup"
git push origin main
```

## If push is rejected

Typical error:
- `! [rejected] main -> main (fetch first)`

Safe recovery when the user's intent is to update the current default branch, not rewrite history:

```bash
git fetch origin main
git log --oneline --left-right HEAD...origin/main
git rebase origin/main
git push origin main
```

## Final verification

```bash
git status --short
git rev-parse HEAD
git rev-parse origin/main
```

Success state:
- `git status --short` returns nothing
- `git rev-parse HEAD` equals `git rev-parse origin/main`

## Example trigger

- User says: "push everything so Vercel has the latest changes"
- Recent local fix resolved a bundling/build error
- Remote default branch may have advanced since local last fetch
