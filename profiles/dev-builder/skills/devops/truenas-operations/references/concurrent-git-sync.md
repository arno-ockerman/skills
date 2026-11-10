# Concurrent Git syncs on a shared TrueNAS dataset

## Failure signature

A scheduled sync fails with:

```text
fatal: Unable to create '<repo>/.git/index.lock': File exists.
Another git process seems to be running
```

An absent lock by the time of inspection does not prove it was stale. It often indicates a short-lived race.

## Diagnose before deleting

1. Inspect `.git/index.lock` metadata.
2. Check for active Git processes and lock users with `lsof` or `fuser` when available.
3. Check repository integrity/state:

```bash
git -C <repo> status --short --branch
git -C <repo> fsck --no-dangling
git -C <repo> diff --check
```

4. Enumerate every scheduler that can touch the repository, including different Hermes profile cron stores and a default/global cron store.
5. Compare schedules in the repository's local timezone; jobs with different UTC expressions can still collide at local midnight.
6. Inspect all referenced sync scripts. Duplicate implementations are a race signal even if only one appears in the active profile's cron tool.

Only remove `index.lock` after confirming no process owns it and no Git operation is active.

## Durable fix: one shared transaction lock

Every writer must use the same lock path and hold it over the complete fetch/add/commit/rebase/push transaction:

```bash
REPO=/path/to/repo
SYNC_LOCK="$REPO/.git/repository-sync.lock"

exec 9>"$SYNC_LOCK"
flock -w 180 9 || {
  echo "ERROR: timed out waiting for repository sync lock" >&2
  exit 1
}

# Complete Git transaction follows while fd 9 remains open.
```

Why this shape:

- A lock around only `git commit` leaves races in `git add`, rebase, and push.
- `flock` is released automatically on process exit/crash.
- Keeping the coordination file under `.git/` avoids worktree noise.
- The same lock path must be adopted by every duplicate script; otherwise serialization is illusory.

Reducing to a single scheduled job is simpler when delivery and ownership allow it. A shared lock remains useful defense-in-depth when multiple automation paths are legitimate.

## Verification

1. Syntax-check every modified shell script with `bash -n`.
2. Start both sync implementations concurrently using a controlled subprocess harness.
3. Require both exit codes to be zero.
4. Verify repository state:

```bash
git -C <repo> status --short --branch
test "$(git -C <repo> rev-parse HEAD)" = \
     "$(git -C <repo> rev-parse origin/main)"
```

5. Confirm no rebase/merge state and no `index.lock` remain.

The important lesson is to reproduce the concurrency after the fix, not merely run each script sequentially.
