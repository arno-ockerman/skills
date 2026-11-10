# Installing the OpenCode CLI in the shared ai-tools dataset

Use when a task needs the `opencode` CLI (Archon's community provider, or Herdr), or when Archon reports `Executable not found in $PATH: "opencode"`.

## Why Archon's OpenCode provider fails out of the box

`GET /api/providers/opencode/credentials` → **503 "Embedded OpenCode runtime unavailable"**. The real error, from `acquireEmbeddedRuntime`: **`Executable not found in $PATH: "opencode"`**.

Archon bundles `@opencode-ai/sdk`, whose `createOpencodeServer` does `launch('opencode', ['serve', ...])` — it spawns the **opencode CLI as a separate process**, then parses `opencode server listening on http://...` from its stdout. The published `ghcr.io/coleam00/archon` image ships the SDK but **not** the CLI, so the provider can never start. `archon doctor --full` still reports "embedded runtime SDK present (module resolves)" because that check only probes the module, never a spawn.

There is no `OPENCODE_BIN_PATH`. `PATH` is the only lever, and it must be set on the server process — a symlink into `/usr/local/bin` does not survive an image update.

## The install (three files, ai-tools conventions)

The binary comes from npm's platform package (a standalone ELF, no node needed):

```bash
V=1.18.31   # match or exceed the @opencode-ai/sdk major
curl -fsSL -o /tmp/oc.tgz "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-$V.tgz"
tar xzf /tmp/oc.tgz -C /tmp
install -m755 /tmp/package/bin/opencode /opt/ai-tools/bin/opencode-real
```

Pick the package by platform (`opencode-linux-arm64`, `opencode-darwin-arm64`, …); the container here is Debian trixie + glibc on x86_64, so plain `opencode-linux-x64` is right (the `-musl` variants are for Alpine).

Wrapper at `/opt/ai-tools/bin/opencode`, following the `codex`/`claude` pattern exactly:

```bash
#!/usr/bin/env bash
set -euo pipefail
source /opt/ai-tools/config/shared/env.sh
export HOME="$OPENCODE_HOME_DIR"
mkdir -p "$HOME" "$AI_TOOLS_CACHE/opencode" "$AI_TOOLS_CONFIG/opencode""$AI_TOOLS_CACHE/npx"
if [[ -f "$AI_TOOLS_CONFIG/opencode/token.env" ]]; then
  source "$AI_TOOLS_CONFIG/opencode/token.env"
fi
exec /opt/ai-tools/bin/opencode-real "$@"
```

Add to `/opt/ai-tools/config/shared/env.sh`, next to the other `*_HOME_DIR` lines:
`export OPENCODE_HOME_DIR="$AI_TOOLS_CONFIG/opencode/home"` — plus `"$OPENCODE_HOME_DIR"` and `"$AI_TOOLS_CACHE/opencode"` in the `mkdir -p` block.

Keys go in `/opt/ai-tools/config/opencode/token.env` (chmod 600), sourced by the wrapper only — not by `shared/env.sh`, so they enter OpenCode's environment and no other tool's:

```bash
export OPENCODE_API_KEY="<OpenCode Zen / Go key>"
export DEEPSEEK_API_KEY="<DeepSeek key>"
```

To copy keys out of another profile's `.env` without printing them, parse and write with Python in one step, then verify by printing **lengths** only.

## Why this is the right home

`/opt/ai-tools` is the shared dataset, bind-mounted read-write into Archon, Hermes and Herdr. Because the wrapper pins `HOME`, all three share one config (`~/.config/opencode/opencode.json`) and one credential store (`~/.local/share/opencode/auth.json`) — the same mechanism the codex/claude wrappers use. Files written on the host are immediately live in the container (verified: the wrapper ran inside Archon with no extra env and reported the credentials).

## Activating it in Archon

The only thing Archon needs is `opencode` on the server process's `PATH`. `execContext.kind` defaults to `host` and the run worktrees are host paths, so the shared mount is reachable.

The container's default `PATH` is `/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games` — no `/opt/ai-tools/bin`, even though `CODEX_BIN_PATH`/`CLAUDE_BIN_PATH` are set explicitly (those providers resolve by path, so they never needed it). When adding it to the TrueNAS app's environment block, set the whole value: `PATH=/opt/ai-tools/bin:/usr/local/bin:/usr/bin:/bin`. Do **not** rely on `docker exec -e PATH=...` for a diagnosis being wrong — but do note that `sh -lc` (login shell) resets `PATH`, so use `sh -c` when testing.

Credentials need no app env at all: the wrapper exports them itself.

## Verifying

```bash
# binary + wrapper reachable
/opt/ai-tools/bin/opencode --version
# credentials — expect "Environment: DeepSeek, OpenCode Go"
/opt/ai-tools/bin/opencode providers list
opencode models | grep -E '^(opencode-go|deepseek)/'
# a real turn per provider
opencode run -m opencode-go/deepseek-v4-flash "Reply with exactly: OK"
opencode run -m opencode-go/gpt-5.6-luna "Reply with exactly: OK"
```

Then the decisive one — the embedded runtime Archon actually uses, and its latency budget:

```bash
# in the container, PATH containing /opt/ai-tools/bin
bun /app/packages/providers/src/community/opencode/runtime.ts  # via a small script:
#   acquireEmbeddedRuntime() -> client.provider.list()
```

`createOpencodeServer` uses a **5 s default timeout** for the spawn+listen handshake. Measured here: **2425 ms**, plus a `probeOpencodeRuntimeModule()` that returns true. So it fits, but the margin is thin on a loaded host — if it ever times out, retry before assuming the install is broken.

## Model references

OpenCode resolves models from the models.dev catalogue through its embedded server, using `<provider-id>/<model-id>`. The ids that matter here: `opencode-go` (env `OPENCODE_API_KEY`, the subscription pool) and `deepseek` (env `DEEPSEEK_API_KEY`). Both were driven end to end. `opencode-go/gpt-5.6-luna` is notable — it reaches a model that the Codex CLI provider reports as usage-limited, on a separate quota.
