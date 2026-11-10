# Provider runtime diagnosis

## Identity and credentials

Run probes through the same container, user, wrapper, and HOME as the server. Useful checks:

```bash
ps -eo pid,ppid,user,args
stat -c '%U:%G %u:%g %a %d:%i %n' /path/to/credentials
```

A host path and container path may expose the same inode under different names. Numeric UID/GID and inode identity are more reliable than usernames.

## Cgroup memory probe

```bash
for f in \
  /sys/fs/cgroup/memory.current \
  /sys/fs/cgroup/memory.peak \
  /sys/fs/cgroup/memory.max \
  /sys/fs/cgroup/memory.events \
  /sys/fs/cgroup/memory.events.local \
  /sys/fs/cgroup/memory.swap.current \
  /sys/fs/cgroup/memory.swap.max
do
  printf '\n--- %s\n' "$f"
  test -r "$f" && cat "$f"
done
```

Inventory processes before intervention:

```bash
ps -eo pid,ppid,pgid,sid,user,rss,etime,args --sort=-rss
```

Group related emulators/workers by command and PGID. Long age is a clue, not permission to kill.

## Evidence-to-action table

| Evidence | Conclusion | Action |
|---|---|---|
| Real provider request fails as app UID | Credential/provider-account problem | Re-authenticate as app UID, then repeat the real request |
| Real request succeeds; only an older native session says auth failed | Stale provider session | Start a genuinely new native session rather than resuming it |
| Real request succeeds; `oom_kill` rises; runtime records OOM | Container limit killed provider | Stop confirmed stale workloads or raise the container limit with host headroom |
| Failure starts exactly at server restart | Interrupted non-persistent turn | Retry after restart; do not relabel it as auth failure |
| One tool command fails while provider stays alive | Tool/command failure | Inspect command stderr and exit status; do not restart provider |
| Provider log ends during a tool call and canonical run state says transport failure | Provider subprocess disappeared | Correlate cgroup counters and process-exit evidence before choosing restart or memory remediation |

## Safe recovery

1. Record the failed thread/run/session IDs and current worktree.
2. Inspect the worktree diff because edits may precede the crash.
3. Resolve the proven root cause.
4. Ensure no provider turn is active.
5. Restart the managed service once if required.
6. Verify server health and version.
7. Execute a short provider turn and read the canonical run status.
8. Resume implementation only after the provider path is proven.
