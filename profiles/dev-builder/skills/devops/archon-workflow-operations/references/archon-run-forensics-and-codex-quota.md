# Archon run forensics and the shared Codex quota

Use when an Archon workflow fails, costs more than expected, or the user asks "which model ran which task" / "why did it hit a usage limit".

## Reading a run

**List runs and their totals:**

```bash
curl -s 'https://example.com/api/workflows/runs?limit=25'
```

Each run carries `metadata.total_tokens_in`, `total_tokens_out`, `total_cache_read_tokens`, `metadata.error`, `metadata.model_bindings.effective` (the aliases actually resolved for that run), `started_at`/`completed_at`, and `working_path`.

**One run with its event stream:**

```bash
curl -s 'https://example.com/api/workflows/runs/<runId>'
```

472 events for a single `archon-ship` run. What matters:

- `workflow_started.data` → the resolved default provider/model and isolation mode
- `node_started.data` → `{provider, model, tier, effort}` **per node** — this is the per-task model answer
- `node_completed.data` → `duration_ms`, `structured_output`, and `tokens: {input, output, cacheRead, cacheWrite}` per node
- `node_skipped.data` → `{reason, expr}` (the `when_condition` that skipped it)
- `loop_iteration_started/completed/failed` → loop node iterations and their per-iteration duration
- `node_failed` / `workflow_failed` → the terminal error, naming the exact failing node

Build the per-node table from `node_started` (model) joined to `node_completed` (duration + tokens); the sum of per-node `tokens.input` equals `metadata.total_tokens_in`, which is a useful consistency check.

**Route pitfalls:** `GET /api/workflows/runs` is the JSON list; `/api/runs`, `/api/runs/{id}`, `/api/projects`, `/api/workflow-runs` all return the SPA HTML fallback. `GET /api/config` gives `assistant`, `assistants`, and the three `tiers` with their provider/model. Route definitions live in `packages/server/src/routes/api.ts` of an Archon checkout. `POST /api/workflows/runs/{runId}/resume` resumes a failed run.

## Reality of an archon-ship run on makeithappen

Measured 2026-09-17, issue #185, run `27e37dc5`: 60 minutes, **20.7 M input tokens** (1.26 M non-cached, 19.4 M cache reads), 105 k output, 13 AI nodes + 13 script nodes, 194 tool calls.

| phase | input tokens | share | duration | model (tier) |
|---|---|---|---|---|
| triage | 359 k | 1.7% | 133 s | gpt-5.6-terra (medium) |
| plan | 1.36 M | 6.6% | 559 s | gpt-5.6-sol (large) |
| implement | **14.35 M** | **69.3%** | 1778 s | gpt-5.6-sol (large) |
| PR | 444 k | 2.1% | 113 s | gpt-5.6-terra (medium) |
| classify | 109 k | 0.5% | 19 s | gpt-5.6-terra |
| 6 review lenses (parallel) | 3.41 M | 16.5% | 725 s | gpt-5.6-terra (medium) |
| review synthesize | 672 k | 3.2% | 252 s | gpt-5.6-terra (medium) |
| corrections loop | — | — | — | gpt-5.6-sol (large) — **failed on the usage limit** |

The corrections loop is the node that breaks a good run: it sits *after* everything above, so a nearly-full window kills the run at the last gate even though implementation and PR succeeded. Earlier large runs on the same install: 24.8 M and 21.5 M (completed, barely), 16.6 M (failed). Treat ~20 M input tokens as the working size of one full ship run.

## Why a "just reset" Codex limit is already gone

Codex's 5-hour window starts at the **first request after the previous window expired** — so the reset the user sees and the start of the expensive run are usually the same moment. Verify with arithmetic rather than assuming a bug:

```
window_start = rateLimits.primary.resetsAt - windowDurationMins*60
# compare with run started_at
```

On 2026-09-17 the window reset was 00:04:17 UTC, so the window opened at 19:04:17 — and the run started at 19:04:18, one second later. The run then consumed 100% of it in 50 minutes. Nothing was left for the corrections loop or for Hermes.

**One quota, several consumers.** The Archon container sets `CODEX_HOME=/opt/ai-tools/config/codex/home/.codex` from the shared `ai-tools` mount (`docker inspect archon` shows `/mnt/HomeNAS/appdata/ai-tools -> /opt/ai-tools`), the same `auth.json` the Codex wrapper uses for Hermes and the Herdr workbox. A single ChatGPT account therefore backs Archon workflows, every Hermes profile, and interactive CLI work. Do not run Hermes/Codex work while an Archon run is in flight.

Model-tier choice does not create headroom: `tiers.small` (gpt-5.6-luna) also fails once the account's ordinary usage is blocked. The `base_model_inference` / `gpt-reserve` bucket that reports 0% used is **not** reachable through the plain provider — tested, it returns the same usage-limit error. Do not offer it as a workaround without testing it.

## Diagnosing without burning quota

- `docker logs archon --tail 60` over SSH already contains `provider.codex` → `stream_error` / `turn_failed` with the verbatim usage-limit text; read it before running anything.
- `codex debug prompt-input "ping"` renders the prompt input without a model call — the way to prove config/skill state while rate-limited.
- Read limits with `account/rateLimits/read` (see `coding-agent-clis` → `references/shared-skills-and-codex-limits.md`); never spend a reset credit to "check".
- SSH access: `ssh -F /opt/data/profiles/dev-builder/ssh/config truenas-archon`, then `sudo -n /usr/bin/docker ...` (a NOPASSWD rule exists for `/usr/bin/docker`). The plain docker socket is denied to the account; use sudo.

## Recommendations that follow from the numbers

1. **Repair, don't re-run.** After a failed corrections loop the implementation and PR already exist (PR #224 was open, draft, MERGEABLE, with `Fast gate`, `Vercel` and `verify` all green). Finishing the review findings on that PR costs a fraction of a fresh 20 M-token ship run — resume/adopt the failed run instead.
2. **Split the pipeline.** `archon-plan` alone was 2.3 M on this install; ship-as-one-run is ~20 M. Separate triage+plan, implement+PR, and review+correct runs to shrink the blast radius of a mid-run limit.
3. **Take the review tail off Codex.** The six review lenses plus synthesize are 20% of the tokens; running them (and the corrections loop) on the subscription-backed Claude provider also means a Codex exhaustion can no longer fail the whole run.
4. **Attack the implement node.** 69% of the run sits in one node with a 5-iteration loop and a fresh context per iteration. Cap `max_iterations`, or point it at the medium tier, before adding budget elsewhere.
5. **Serialise the account.** One Codex consumer at a time, across Archon, Hermes profiles, and Herdr.
