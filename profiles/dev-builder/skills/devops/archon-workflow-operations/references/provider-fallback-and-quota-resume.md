# Provider fallback and quota-resume in Archon

Use when the question is "what happens when Codex or Claude hits its limit, and how do we fail over to another provider/model".

## The three mechanisms, and which actually fire

| mechanism | surface | survives image update | fires for Codex usage limit |
|---|---|---|---|
| `config.workflows.autoResumeOnQuotaReset` | settings (`config.yaml`) | ✓ (data dataset) | **no** — pattern mismatch |
| `fallbackModel` | workflow/node YAML in the pack | ✗ overwritten | n/a — Claude-only capability |
| external watcher (cron script) | outside Archon | ✓ | ✓ (reads the real quota API) |

### 1. Native quota auto-resume

Global setting, default **off**, no HTTP route (only `assistants`/`tiers`/`aliases` are exposed by `PATCH /api/config/*`, and the per-run layer `workflows` schema is not writable through the settings API) — so it is a `config.yaml` edit:

```yaml
workflows:
  autoResumeOnQuotaReset: true
  quotaFallbackDelayMs: 300000   # 5 min, used when the reset time cannot be parsed
  quotaMaxAttempts: 3            # max scheduled resumes
  quotaDeadlineMs: 21600000      # 6 h ceiling from the first failure
```

`loadGlobalConfig()` merges it over the defaults (`autoResumeOnQuotaReset: false`, `quotaMaxAttempts: 1`, `quotaDeadlineMs: 24h`); `loadConfig()` then lets a repo `.archon/config.yaml` override the global one. Verify the loader actually sees it (do not trust the file edit alone):

```bash
ssh -F <ssh-config> truenas-archon "sudo -n /usr/bin/docker exec -w /app archon /opt/ai-tools/bun/bin/bun /tmp/verify.mjs"
# verify.mjs: import { loadGlobalConfig } from '/app/packages/core/src/config/config-loader.ts';
#             console.log(JSON.stringify((await loadGlobalConfig(true)).workflows))
```

Import by **absolute path to the `.ts` file** (`/app/packages/core/src/config/config-loader.ts`); the `@archon/core/...` specifier does not resolve from `/tmp` even with cwd `/app`.

Behaviour (`scheduleQuotaResume` in `dag-executor.ts`): finds a failed node whose error satisfies `isQuotaExhaustionError`, computes a resume instant from the error text, then schedules a durable resume bounded by attempts and deadline. It **skips entirely when `execContext.kind === 'container'`** (host worktrees are fine; the default context is `{kind: 'host'}`).

**The Codex gap.** `QUOTA_EXHAUSTION_PATTERNS` is `['session limit', 'usage limit reached', 'credit exhaustion', 'credit balance']`, and `extractQuotaResetAt` only parses `usage limit reached|<epoch 10-13 digits>` or `resets in <N> min|hour`. A real Codex failure reads:

```
SDK returned codex_turn_failed — You've hit your usage limit. Upgrade to Pro (…)
… or try again at Sep 18th, 2026 12:04 AM.
```

Tested against that exact string: all four patterns return **false**, and neither reset form parses. So enabling the setting does **not** rescue a Codex-exhausted run — no `quota_resume_scheduled` event is ever emitted. The user-facing formatter (`error-formatter.ts`) does normalise the same event into "⚠️ AI usage limit reached", but that is the display path; the stored node error keeps the raw wording. Worth reporting upstream: add the Codex wording to the pattern list. A drafted issue body with the full evidence table and verified line numbers sits at `/opt/data/workspace/archon-issue-codex-quota-pattern.md`.

**The pattern fix alone still does not resume Codex.** `extractQuotaResetAt` parses only two forms by design (its own comment: "Parse only provider reset forms that carry an unambiguous instant/duration") — `usage limit reached|<epoch>` and `resets in <N> min|hour`. Codex says "try again at Sep 18th, 2026 12:04 AM" (ordinal day, month name, 12-hour clock, no timezone) and Claude says "resets 3:20pm (UTC)"; neither parses. `quotaFallbackDelayMs` is the designed answer for exactly this, but it has **no default**, so with a default config either provider logs `quota_resume_skipped{reason: 'reset_unavailable'}` and schedules nothing. Set it whenever `autoResumeOnQuotaReset` is enabled, or the setting is inert for real-world wordings.

**Why the test suite misses it:** the drift guard at `executor-shared.test.ts:1016` asserts that every `detectCreditExhaustion` output classifies FATAL — but `detectCreditExhaustion` only produces the *Claude* wordings, since Codex failures arrive as raw SDK error text. Any 'every provider wording' guard in this repo must enumerate real Codex strings separately.

Confirm the gap by calling the classifier with the real string instead of reasoning about it — it settles the question in one shot:

```bash
# /opt/ai-tools/work/probe-match.ts
const shared = await import('/app/packages/workflows/src/executor-shared.ts');
console.log(shared.isQuotaExhaustionError(realErrorText));   // false
console.log(shared.extractQuotaResetAt(realErrorText));      // null
# run it: cd /app && /opt/ai-tools/bun/bin/bun /opt/ai-tools/work/probe-match.ts
```

The same probe shows what *would* match: `You've hit your session limit · resets 12:30pm` → `true`, and `usage limit reached|1789758027` → `true` with reset `19:00:27 UTC`. So the classifier is a known-good mechanism that simply lacks Codex's dialect.

### Which gate actually blocks, and how to tell

`scheduleQuotaResume` has three silent-or-loud exits in order: (1) `autoResumeOnQuotaReset !== true` → silent; (2) `execContext.kind === 'container'` → writes `quota_resume_skipped{reason:'container_unsupported'}`; (3) no failed node satisfies `isQuotaExhaustionError` → silent. Exit (3) writes nothing, so an empty event log is ambiguous between (1) and (3) — resolve it by printing the loaded policy (`loadGlobalConfig(true).workflows`), which here returns `autoResumeOnQuotaReset: true`, leaving (3) as the blocker.

The persisted-event list is the whitelist in `packages/workflows/src/store.ts` — `quota_resume_scheduled/triggered/exhausted/skipped` **are** on it, so their absence really does mean the function never got past the pattern check. A read-only SQLite query settles it across every run at once:

```python
sqlite3.connect('file:/.archon/archon.db?mode=ro', uri=True)
# SELECT event_type, COUNT(*) FROM remote_agent_workflow_events GROUP BY event_type
```

Claude, by contrast, **is** recognised: `detectCreditExhaustion` normalises session-limit output into a string containing `session limit`, which matches. That claim rests on the classifier call above, not on an observed resume — a DB-wide check shows **no `quota_resume_*` event has ever been persisted on this install**, because Claude's earlier failures predate the setting being enabled. Note it also needs `quotaFallbackDelayMs`: Claude's `resets 12:30pm` does not parse either, so without the fallback it exits at `reset_unavailable`. So this setting protects the Claude half of a tier split in principle, and the Codex half never.

### 0. Switch the tiers to the other subscription — the recovery to use first

When one provider's window is exhausted and the other subscription is live, do not wait for a reset and do not start a second run: remap the tiers onto the live provider and resume the interrupted run. A resumed run started **without** `--model` bindings re-resolves every not-yet-run node from the current `config.yaml`, so the remaining nodes run on the new mapping while the already-completed nodes stay skipped (`node_skipped_prior_success`) — the work done before the failure is preserved.

```bash
/opt/ai-tools/bin/archon ai tier set small  <provider> <model> --effort <low>
/opt/ai-tools/bin/archon ai tier set medium <provider> <model> --effort <medium>
/opt/ai-tools/bin/archon ai tier set large  <provider> <model> --effort <medium>
/opt/ai-tools/bin/archon ai tier list --json      # read effective back, do not trust the set output
```

Then resume with the environment that makes the target provider authenticate (for Claude from the Hermes host: `CLAUDE_USE_GLOBAL_AUTH=true CLAUDE_BIN_PATH=/opt/ai-tools/bin/claude`, plus `GH_CONFIG_DIR` for the GitHub nodes).

The routes are **not** interchangeable, so check before switching — cost, which stages share a tier, and operator preference decide it, not convenience:

- The `large` tier carries plan + implement, so it is where quality matters most; move it to the strongest available model.
- `plan` and `implement` share one tier, so a settings-only mapping cannot split them.
- When the interrupted run's failure is on a *shared* tier, the whole remaining graph moves with it.
- **Restore the previous mapping** once the original window reopens (`archon ai tier list --json` shows each tier's `default` next to `configured`), so later runs use the preferred mix again. The tier mapping is install-wide state, and leaving it switched silently changes every subsequent run.

Setting a tier is not proof the model is usable: probe the exact configured model with a fixed-token prompt before resuming, because a model name can be accepted by the config layer and still rejected by the provider at request time.

### 0b. Recovering a run that an interrupted process left `running`

A run whose CLI process dies mid-node (a killed background task, a stopped app) leaves its row `running` with nothing behind it, and `archon workflow resume` then refuses with "Cannot resume run with status 'running'". `abandon` clears it but sets a terminal state that resume also refuses ("Only failed or paused runs can be resumed"). The recovery that works:

1. `archon workflow abandon <run-id> --json` — clears the orphaned `running` row.
2. Write the row back to resumable directly (no CLI surface for this):

```python
sqlite3.connect('<ARCHON_HOME>/archon.db').execute(
    "UPDATE remote_agent_workflow_runs SET status='failed', completed_at=datetime('now'), metadata=? WHERE id=?",
    ('{"error":"recovered: process interrupted mid-resume"}', run_id))
```

3. Resume normally; completed nodes are skipped by `prior_success`.

Two limits: a run that failed at its **first** node has no completed nodes, and resume refuses it ("no completed nodes and no interactive-loop state") — start a fresh `workflow run`, reusing the branch/worktree. And an `abandon` that is not followed by step 2 leaves the run permanently unresumable, so always finish the sequence.

The reliable way to avoid all of this is to launch the run as a tracked background process (`terminal(background=true, notify=true)`) rather than with shell background wrappers or a foreground call.

### 2. fallbackModel — not usable here

`fallbackModel` exists as a workflow/node YAML field with a config-layer equivalent, but the capability matrix gates it: `fallbackModel: true` for **claude only**; codex, opencode and pi are all false. The pack never sets it, and it is not part of the settings surface, so it cannot be reached without editing the image-owned pack. Do not offer it as the fix.

### 3. External watcher — what actually handles Codex today

Because the native detection misses Codex's wording, an outside watcher is the reliable route: poll `account/rateLimits/read` (see `coding-agent-clis` → `references/shared-skills-and-codex-limits.md`), wait for `ordinaryUsageAllowed: true` or the `resetsAt` instant, then resume with `workflow resume <id> --cwd <run worktree> --detach --json` over SSH. Make it re-poll instead of trusting a single clock reading, and have it exit quietly (no resume, no spend) when the window is still shut.

**Implemented:** `~/profiles/dev-builder/scripts/archon-quota-watchdog.py`, on cron `*/15`. It reads `GET /api/workflows/runs?limit=N`, keeps the runs whose `metadata.error` carries a quota signal, waits for the window, then resumes each one with its own `working_path`. Details that matter:

- **Classify on the run record, not the events.** `metadata.error` is populated for failed runs (`failWorkflowRun` stores `{error}`); `working_path` rides in the same list response, so one call yields both. Never derive the worktree from a path convention — one project used `worktrees/archon-ship-<ts>` while another used `worktrees/archon/thread-<hash>`.
- **Use a wider signal list than Archon's**, since the point is to catch the dialects Archon misses: `usage limit`, `session limit`, `credit balance`, `credit exhaustion`. A bare `codex_turn_failed` is *not* enough — unrelated failures carry it too.
- **Re-check status immediately before resuming** (`GET /runs/<id>` still `failed`), then increment attempts and never exceed `quotaMaxAttempts`/`quotaDeadlineMs` equivalents. That mirrors the built-in semantics and stops a persistently broken run from being resumed forever.
- **Treat resume acceptance as asynchronous dispatch, not proof of the resumed run.** `POST /api/workflows/runs/<id>/resume` can return success while the original row remains `failed` and a replacement run with a new ID starts moments later. After a successful response, poll the run list by exact issue target/conversation and verify the single new `running` row before doing anything else. Never launch a fresh run merely because the original row did not change immediately; that creates two concurrent worktrees for one issue.
- **Classify the actual blocker before spending a reset credit.** Read Codex `account/rateLimits/read`, the failed node's provider/error, and a paused run's `metadata.wait`. A run paused on CI attention or failed on Claude is not repaired by a Codex reset. Consume a full reset credit only when Codex ordinary usage is blocked and the run is genuinely waiting on that quota.
- **Remove obsolete non-terminal rows with the lifecycle action that matches their state.** `cancel` only stops a live `running` run; use `POST /api/workflows/runs/<id>/abandon` for a stale `paused` or resumable `failed` run. Otherwise an intake guard that treats paused runs as active can block every later issue even after the PR is already merged.
- **Talk to the API with `curl`, not `urllib`.** Cloudflare in front of this host answers **403** to the `Python-urllib/x.y` user-agent while serving curl normally, which looks exactly like an outage from inside a script.
- **Stay silent when idle.** With `no_agent`, empty stdout sends nothing; emit only on a resume, on parking a run, or on exhausting attempts. Set a `notified` flag per run so a blocked run is announced once, not every 15 minutes.

## DeepSeek and "OpenCode Go" in Archon

- **Archon has no DeepSeek provider.** The registered set is fixed: `claude`, `codex`, `opencode`, `pi`, `copilot`. Model refs are not free-form provider names.
- **OpenCode is the only door to third-party models.** Its universe is the models.dev catalogue resolved at runtime by the **embedded** server, so a ref like `deepseek/<model>` is possible in principle. There is no `OPENCODE_BIN_PATH`: `parseOpencodeRunConfig` rejects `baseUrl` outright ("external OpenCode runtimes are not supported").
- **It is currently down on this install**: `GET /api/providers/opencode/credentials` → **503 "Embedded OpenCode runtime unavailable"**, i.e. `acquireEmbeddedRuntime` throws even though `archon doctor --full` reports the SDK module resolves.
- **No keys reach the providers by env.** The Archon container's environment contains no `DEEPSEEK_API_KEY` / `OPENCODE_GO_API_KEY` / `ANTHROPIC_API_KEY`; Codex and Claude authenticate purely through the shared CLI homes (`CODEX_HOME`, `CLAUDE_BIN_PATH` → `/opt/ai-tools`). So adding a third party model needs (a) the embedded runtime fixed, (b) credentials injected into the container env through the TrueNAS app config (settings, survives updates), (c) an alias or tier mapped to `opencode`.

## What to recommend instead

Tier-splitting across **independent quotas** is the real failover available today, and it is settings-only: Codex (ChatGPT plan) and Claude (Anthropic subscription) exhaust separately, so placing the review/validate tail on Claude means a Codex exhaustion degrades rather than kills a run. Combine with the external watcher for the Codex half, and enable the native setting so the Claude half resumes by itself. Do not promise a per-node provider fallback chain — this engine does not have one.
