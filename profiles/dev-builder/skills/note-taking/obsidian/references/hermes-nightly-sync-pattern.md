# Hermes nightly vault/context sync pattern

Session-derived pattern for a Git-backed Obsidian/AI-context repo that should sync to GitHub every day at local midnight.

## Working shape

### Real repo
- Parent folder was not the correct automation target.
- Correct repo lived as a nested repo:
  - `/opt/ai-context/ProductivityCenter`

### Parent cleanup
- Parent `.git` was archived instead of deleted outright so recovery stayed possible.
- Example archival move:
  - `/opt/ai-context/.git` -> `/opt/ai-context/.git.backup-YYYYMMDD-HHMMSS`

### Real sync script
- Store under Hermes scheduler scripts dir.
- Example:
  - `/opt/data/profiles/dev-builder/scripts/sync-productivitycenter.sh`

Core logic used:
1. `export HOME=/opt/data`
2. `cd` into the real repo
3. `git config core.filemode false`
4. `git fetch origin main`
5. if local changes exist:
   - `git add -A`
   - commit only if staged diff is non-empty
6. compute ahead/behind with `git rev-list --left-right --count HEAD...origin/main`
7. if behind > 0: `git pull --rebase --autostash origin main`
8. recompute ahead/behind
9. if ahead > 0: `git push origin main`
10. print output only when meaningful sync activity occurred

## Timezone workaround
Inline schedule like:

```text
CRON_TZ=Europe/Brussels 0 0 * * *
```

was rejected by Hermes cron in this session.

Reliable workaround:
- schedule hourly: `0 * * * *`
- gate execution inside a wrapper script:

```bash
if [ "$(TZ=Europe/Brussels date +%H:%M)" != "00:00" ]; then
  exit 0
fi

exec /opt/data/profiles/dev-builder/scripts/sync-productivitycenter.sh
```

## Resulting cron shape
- `no_agent=true`
- wrapper script referenced by filename from the scheduler scripts dir
- hourly schedule
- silent on no-op runs
- actual sync occurs only at Brussels midnight, including DST changes

## Why this pattern is worth reusing
- avoids scheduler timezone feature assumptions
- keeps user-facing delivery quiet
- survives DST automatically
- preserves a clean commit/rebase/push order
