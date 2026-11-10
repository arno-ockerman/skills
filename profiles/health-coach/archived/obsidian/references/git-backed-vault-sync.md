# Git-backed vault sync

This note absorbs the former `git-backed-vault-sync` skill as session-specific operational detail under the Obsidian umbrella.

## Durable lessons

### Effective HOME vs passwd home
In one working Hermes environment:
- runtime `HOME` in terminal/script context: `/opt/data/home`
- passwd home for user `hermes`: `/opt/data`

Git HTTPS credentials had been stored under the passwd home, so automation initially failed to see them. The durable lesson is not the exact path values; it is the verification pattern:
1. inspect runtime `HOME`
2. inspect passwd home for the service user
3. locate `.gitconfig` / `.git-credentials`
4. export the correct `HOME` in the automation script if needed
5. retest `git fetch` in the same context the cron job uses

## Filemode-noise mitigation
A mounted note vault produced mass `100644 -> 100755` mode-only changes. Setting:

```bash
git config core.filemode false
```

stopped automation from generating useless commits.

## Safe sync shape
Recommended script order:
1. verify repo and remote
2. `git fetch origin`
3. if `git status --porcelain` non-empty:
   - `git add -A`
   - commit only if staged diff is non-empty
4. compute ahead/behind with:

```bash
git rev-list --left-right --count HEAD...origin/main
```

Interpretation:
- first number = ahead
- second number = behind

5. if behind > 0: `git pull --rebase origin main`
6. recompute ahead/behind
7. if ahead > 0: `git push origin main`

## Hermes cron detail
For `cronjob(..., no_agent=true, script=...)`, the script must be placed in the scheduler script directory and referenced by filename, not an arbitrary absolute path.

## Reporting pattern
Good user-facing completion report:
- auth verified
- fetch / dry-run push verified
- script path
- cron job name / id / schedule
- whether no-op runs stay silent
