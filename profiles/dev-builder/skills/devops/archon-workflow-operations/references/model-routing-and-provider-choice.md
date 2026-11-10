# Routing models per SDLC stage through settings (no YAML edits)

Use when the user wants a different model per Archon task, wants to move load off an exhausted provider, or asks which model fits which stage. Covers the settings-only levers, the tier→node map of the deployed pack, and provider capabilities.

## The rule: settings, never the pack

The bundled sdlc pack is **image-owned** (`/app/packages/.../bundled`, staged per run into the run's `workflow-source/bundled/`). Editing it is overwritten by the next image update, so per-node `model:`/`effort:` edits do not survive. The durable levers live in the server's data dataset: `ARCHON_HOME=/.archon` → `/.archon/config.yaml` (mounted from the archon data dataset).

Settings surface (all ungated on solo installs):

```bash
# HTTP
PATCH /api/config/tiers      {"tiers":{"small":{provider,model,effort},"medium":{...},"large":{...}}}
PATCH /api/config/aliases    {"aliases":{"@name":{provider,model,effort}}}
PATCH /api/config/assistants {"assistants":{"codex":{model,modelReasoningEffort},...}}

# CLI (same file, equivalent)
archon ai tier set large codex gpt-5.6-sol --effort medium [--scope user|install]
archon ai tier list --json
archon ai alias set @mini pi minimax/MiniMax-M3
```

Because the pack references **tier keywords** (`model: large`/`medium`/`small`), remapping a tier changes every node that uses it, across every workflow, with zero YAML changes — and the mapping survives image updates. Per-tier `effort` is supported too, so reasoning depth can be tuned per tier without touching a node.

`GET /api/config` returns both `tiers` (what actually resolves) and `tierDefaults` (the intended baseline); they can silently diverge after a provider remap — `tiers.medium` was once left on `claude/sonnet` while `tierDefaults.medium` said `codex/gpt-5.6-terra`. Read `tiers`, not `tierDefaults`, to see what a stage will actually run. de gebruiker's canonical all-Codex mapping is small=`gpt-5.6-luna`, medium=`gpt-5.6-terra`, large=`gpt-5.6-sol`.

**One-run override without touching settings:** `archon workflow run <wf> --model large=claude/opus --model medium=claude/sonnet`. Note `--model` and `--inputs` are mutually exclusive with `--resume`; a resumed run also ignores *supplied* bindings, but see below.

## Does a resumed run pick up a new tier mapping?

Yes, when the run was started without explicit bindings. `executor.ts` does:

```
resolvedModelOverrides = persistedModelBindings?.overrides ?? callerResolvedModelOverrides ?? resolveRunModelOverrides(...)
acquiredAiProfile      = applyResolvedRunModelOverrides(baseAiProfile, resolvedModelOverrides)  // {...base.aliases, ...overrides.tiers, ...overrides.aliases}
```

A run started with no `--model` stamps `overrides: {}`, so the resumed process merges **nothing** over the live profile and re-resolves tiers from the current `config.yaml`. Only bindings *supplied on the resume call* are refused, and the user gets told so. So: patch the tiers first, then resume, and the remaining nodes run on the new mapping.

Resume across a telegram/web parent: `POST /api/workflows/runs/{id}/resume` returns 400 (`Cannot resume from web UI: the run's parent conversation is not a web conversation`) whenever the parent is telegram/cli. Use the CLI inside the container instead, which shares the server DB via `ARCHON_HOME=/.archon`:

```bash
ssh -F <ssh-config> truenas-archon "sudo -n /usr/bin/docker exec -e ARCHON_HOME=/.archon archon sh -lc 'cd /home/appuser && /opt/ai-tools/bun/bin/bun /app/packages/cli/src/cli.ts workflow resume <run-id> --cwd <run working_path> --detach --json'"
```

The container image's CLI lives at `/app/packages/cli/src/cli.ts` (bun at `/opt/ai-tools/bun/bin/bun`); the `/opt/ai-tools/bin/archon` wrapper is the wrong path there because it exports `ARCHON_HOME=/opt/ai-tools/config/archon` (the Hermes-side CLI home). `--cwd` must be the run's `working_path` (its own worktree) or the CLI refuses with "Not in a git repository". Read the run with `workflow get <id> --cwd <worktree>` to confirm the worktree and artifacts are still live before resuming.

## Which stage runs on which tier (deployed 0.10.1 pack)

Authoritative source: `GET /api/workflows`, which exposes each workflow's `model` plus per-node `model`. The deployed pack differs from newer branches — read the server, never a clone.

- **large** — `archon-plan` (plan), `archon-implement` (record-start / implement / assert-changed). In a ship run this is **plan + implement + the corrections-loop fix**.
- **medium** — `archon-triage`, `archon-investigate`, `archon-pr`, all ten `archon-review` nodes (the six lenses + synthesize), `archon-validate`, and deliver's `classify` / `sync-pr-body`.
- **small** — barely reached by ship; used by other workflows for classification (smart-pr-review classify, ralph detect-input, workflow-builder extract-intent, remotion summary).

Measured token shares for one ship run (see the forensics reference): implement 69%, review lenses 16.5%, plan 6.6%, synthesize 3.2%, PR 2.1%, triage 1.7%, classify 0.5%. So the `medium` tier carries ~20% of the tokens and the `large` tier ~76%.

A consequence worth stating: `plan` and `implement` share one tier, so a settings-only mapping cannot give them different models. Choose, or use a per-run `--model large=...` override.

## Effort: check before recommending it

Nodes in this pack declare no `effort:`, so `assistants.codex.modelReasoningEffort` (default `medium` in `/api/config`) governs every Codex node, and tier `effort` governs the rest. A run's `node_started` events therefore already show `effort: medium` everywhere — lowering to `low` is the only step down, and it trades reasoning depth on the work that matters most. Prefer moving token volume to a different provider over downgrading effort. Ladders differ per provider: Codex accepts the whole `EFFORT_LADDER` (minimal→persistent); Claude `low..max`; Copilot `low..xhigh`; unsupported rungs clamp *down*.

## Provider capabilities (from `GET /api/providers`)

| capability | claude | codex | opencode | pi | copilot |
|---|---|---|---|---|---|
| hooks / skills / agents | ✓✓✓ | ✗✗✗ | ✗✗✓ | ✗✓✗ | ✗✓✓ |
| mcp | ✓ | ✓ | ✗ | ✗ | ✓ |
| toolRestrictions / sandbox | ✓✓ | ✗✗ | ✓✗ | ✓✗ | ? |
| effortControl | ✓ | ✓ | ✗ | ✓ | ? |
| costControl | ✓ | ✗ | ✗ | ✗ | ? |
| **fallbackModel** | ✓ | ✗ | ✗ | ✗ | ? |
| structuredOutput | enforced | enforced | enforced | best-effort | ? |
| builtIn | ✓ | ✓ | ✗ | ✗ | ✗ |

Claude is the most capable provider in the matrix and the only one with a fallback model besides Pi/Copilot; Codex is the thinnest on capability but the cheapest/fastest. That asymmetry is the argument for putting the *judgment* stages (plan, review, synthesize) on Claude and the *volume* stages wherever tokens are cheapest.

## OpenCode for Archon

Available in the image — `archon doctor --full` reports `OpenCode runtime: embedded runtime SDK present (module resolves; server not started)`. It is driven through an **embedded runtime SDK** (`createOpencode` spawning a local server with a random password), not a CLI binary, so there is no `OPENCODE_BIN_PATH` to set. Model refs use OpenCode's own `provider/model` form (e.g. `anthropic/claude-sonnet-4-5`, `minimax/...`, `zai/...`), and OpenCode's own provider auth must be configured — `assistants.opencode` is empty by default. Treat it as a third, subscription-independent pool (useful when both ChatGPT and Claude windows are tight), not as a capability upgrade: no hooks, no skills, no MCP, no effort control, no cost control.
