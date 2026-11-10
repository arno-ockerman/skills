# Coding-agent service containers on TrueNAS

Use for durable coding-agent services on TrueNAS.

## When to Use

Use this procedure for T3 Code and similar long-running agent servers that need shared repositories and CLI wrappers, provider authentication, moving release channels, or remote/mobile access.

## Architecture decision

1. Inspect the live process, PID 1/supervisor, mounts, listening port, service definition, and persistent state.
2. If the daemon has an independent update cadence or resource profile, deploy it as a separate TrueNAS Custom App. Share datasets, not another app's image filesystem or supervisor lifecycle.
3. Mount the shared tool root and project root at stable paths. Run as the dataset's consuming UID/GID (commonly `568:568`) and put wrapper directories first on `PATH`.
4. Persist the service's own base directory, package cache, remote-link state, and exact last-known version.
5. Give it a healthcheck, `restart: unless-stopped`, a graceful stop period, and a memory limit sized for the provider subprocess plus builds/tests. Do not mount the Docker socket.

A reusable T3 Compose starter is in `templates/t3code-truenas-compose.yaml`.

## Manual nightly updates

When the operator prefers controlled upgrades, pin an exact nightly in Compose:

```yaml
T3_VERSION: 0.1.3-nightly.YYYYMMDD.BUILD
```

Upgrade by editing only that value and saving the TrueNAS app. Verify the endpoint reports the intended exact version. Roll back by restoring the previous value. Do not add a moving `nightly` tag, scheduled restart, or host update script unless the operator explicitly requests automation.

## Shared CLI runtime and GitHub authentication

Put `/opt/ai-tools/bin` first on `PATH` and set `BASH_ENV=/opt/ai-tools/config/shared/env.sh`, so non-interactive Bash commands inherit the shared Claude, Codex, gh, and OpenCode configuration. Start with `/bin/bash -c`, not `sh -lc` or `bash -lc`: a login shell can replace `PATH` through `/etc/profile` and hide every shared wrapper.

T3 invokes `git` directly for background status fetches. A successful `gh auth status` does not authenticate ordinary Git by itself. Configure T3's persistent HOME at startup:

```bash
git config --global credential.https://github.com.helper \
  '!/opt/ai-tools/bin/gh auth git-credential'
```

Verify with an authenticated `git ls-remote` as the service UID; do not stop at `gh auth status`.

## Provider authentication

Provider status commands are insufficient when stale tokens can still report logged-in state.

1. Run login as the exact service UID, for example `docker exec -u 568:568 -it <container> ... auth login`.
2. Verify owner/mode of the credential file without printing its contents.
3. Execute a real minimal provider request as the same UID and require the expected response.
4. Restart the agent server only after the real request succeeds.

## T3 Connect

Keep `T3CODE_HOME` on a persistent dataset. After the service is healthy:

```bash
docker exec -u 568:568 -it t3code /bin/bash -c \
  'exec npx --yes "t3@$T3_VERSION" connect link --headless'
docker restart t3code
```

Then verify reachability, not only authorization:

```bash
docker exec -u 568:568 t3code /bin/bash -c \
  'exec npx --yes "t3@$T3_VERSION" connect status --json'
```

`connect login` authorizes the CLI but does not enable remote access; use `connect link` for the environment. Run `connect publish` separately when mobile activity notifications are wanted.

A managed outbound tunnel does not require publishing the service port to the internet. Keep any local fallback bound to `127.0.0.1`, or expose it only through the operator's existing identity-aware tunnel/Tailscale route.

## Generic provider-turn failure triage

When the provider works from a direct CLI call but the server reports a generic turn/transport failure:

1. Read the provider event log and server trace for the exact failed turn.
2. Check the projected run status and terminal failure, not just the last visible UI message.
3. Inspect cgroup counters:

```bash
cat /sys/fs/cgroup/memory.current
cat /sys/fs/cgroup/memory.peak
cat /sys/fs/cgroup/memory.max
cat /sys/fs/cgroup/memory.events
```

If `oom_kill` increased and the trace records an OOM-killed agent scope, authentication is no longer the problem. Stop stale workloads or raise/isolate the service memory limit, then retry from the existing worktree after inspecting partial changes: the provider may have edited files before being killed.

## Verification gate

- container is healthy and supervised independently;
- endpoint reports the intended exact version;
- provider real-request smoke test passes as the service UID;
- remote-link status reports reachable when remote access is required;
- cgroup memory has operating headroom and `oom_kill` does not increase during a representative turn;
- persistent state and exact-version fallback survive a container recreate;
- rollback to a prior exact version is documented and tested.