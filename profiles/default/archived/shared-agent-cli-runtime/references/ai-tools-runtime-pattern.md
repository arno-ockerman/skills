# Shared `/opt/ai-tools` runtime pattern (Hermes + OpenClaw)

## Scenario

A shared tooling root was used so Hermes and OpenClaw could reuse:
- one installation location for CLIs
- one authentication state per tool
- one cache/work layout

The concrete root was:
- `/opt/ai-tools`

## Implemented structure

Canonical shared env:
- `/opt/ai-tools/config/shared/env.sh`

Compatibility shim for older wrappers:
- `/opt/ai-tools/work/env.sh`

Health check:
- `/opt/ai-tools/config/shared/doctor.sh`

Debug helper:
- `/opt/ai-tools/bin/tool-env`

Documentation:
- `/opt/ai-tools/README.md`

## Wrapper outcomes

Wrappers were normalized for:
- `gh`
- `claude`
- `codex`
- `gog`
- `summarize`

Observed patterns:
- `gh` used a real binary already in `/opt/ai-tools/bin/gh-real`
- `claude` and `codex` were wrappers around binaries under `/opt/ai-tools/work/npm-prefix/bin/...`
- older wrappers sourced `/opt/ai-tools/work/env.sh`, so a compatibility shim avoided breakage during migration

## Important environment nuance

In this Hermes environment:
- terminal-session HOME may be `/opt/data/home`
- the Unix account home may be `/opt/data`

This is exactly why wrapper-controlled env and tool-specific HOME variables are better than trusting the ambient shell HOME.

## Practical bootstrap pattern

A shell bootstrap was added so new shells automatically source the shared env file:
- `/opt/data/home/.bashrc` (bash)
- `/opt/data/home/.profile` (POSIX `/bin/sh`, used by Hermes terminal sessions)

Pattern:

```bash
if [ -f /opt/ai-tools/config/shared/env.sh ]; then
  . /opt/ai-tools/config/shared/env.sh
fi
```

This helps future shells see `/opt/ai-tools/bin` first in PATH. Both files should exist for full coverage (interactive bash + login/non-interactive sh).

## Validation caveat

If wrapper files are created successfully but `claude` / `codex` still show `command not found`, the likely cause is not the wrapper content but a shell/session PATH reload issue. Restart the shell or agent runtime and verify with:

```bash
which gh
which claude
which codex
/opt/ai-tools/config/shared/doctor.sh
```

## Reusable lesson

When migrating an already-populated shared tool root:
1. inspect current wrappers before changing them
2. preserve existing auth/config directories
3. make one canonical env file
4. add a compatibility shim for legacy source paths
5. update wrappers to use the canonical env
6. only then reload PATH and validate
