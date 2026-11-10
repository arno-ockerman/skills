# Cutting token/quota spend on an Archon ship run

Use when a run burns the provider limit too fast and the question is which knob actually reduces it. Measure before recommending — the intuitive lever (reasoning effort) is one of the weakest here.

## Measure first

Run-level totals come from `GET /api/workflows/runs?limit=N` → `metadata`: `total_tokens_in`, `total_tokens_out`, `total_cache_read_tokens`, `total_cache_write_tokens`, `total_cost_usd`. Turns per node are NOT in the API — count `tool_called` events by `step_name` (from `GET /api/workflows/runs/<id>`, or SQLite read-only if the event type looks filtered).

Worked example — one `archon-ship` run of ~80 min:

```text
31.9M input tokens | 151k output | 271x more input than output
97% cache read      | 270 turns x ~118k context per turn
83 turns on codex/sol  (implement 62, corrections-fix 21)
187 turns on claude    (triage 45, the 6-node review fan-out 127)
~$5.20 estimated
```

The 271x ratio is the finding that redirects the whole analysis: **output (where reasoning tokens live) is ~0.5% of the total.** So reasoning effort is a minor lever, and "the model thinks too hard" is the wrong diagnosis.

## The actual cost structure

Cost ≈ context-per-turn × turns, not output. Two consequences:

- **Turn count is the multiplier.** 270 turns means 270 full contexts. Reducing turns beats every per-token optimisation.
- **Cache is already doing its job** at 97%; there is no cache win left to claim.

## Why one provider dies and the other does not

A run can be 69% Claude turns and still exhaust only Codex: the two quotas are independent and sized differently (a ChatGPT **Plus** Codex allowance is far smaller than a Claude subscription). Diagnose by quota *bucket*, not by turn count — check `planType` alongside the windows in the rate-limit read.

## The levers, ranked by what they actually change

**1. Which provider owns `large` — the only lever that removes the burn.** The tier indirection is all-or-nothing: every workflow declaring `model: large` moves together. In this pack that is `implement`, `plan`, `stabilize` (and `corrections.fix__implement` through the include), so redefining `large` is a single settings change that relocates the entire implementation load. This is the answer to "use less Codex": stop using Codex for it.

**2. Model within the same provider.** The `priority` field in the model catalogue tracks capability/premium standing (frontier model 1 → balanced 7 → fast-and-affordable 8 → older 12). A cheaper sibling in the same bucket stretches the budget without moving buckets. Confirm the target model actually runs before promising it.

**3. Effort — real but small.** Verified `effortControl: true` for codex (#2556), with precedence `nodeConfig.effort` > `assistants.<provider>.modelReasoningEffort`; ladder is `minimal, low, medium, high, xhigh, max, ultra, persistent`. Worth setting anyway when it restores the model's own default (a model with `default_reasoning_level: "low"` pushed to `medium` is being over-driven), but size the expectation from the output share above.

**4. Fewer turns — behavioural, and the biggest real win.** Tighter issue scope, less exploratory thrashing. Not a config change.

**5. A lighter workflow for small work.** The delivery tail's review fan-out is 6 nodes / ~127 turns; `archon-implement` + `archon-pr` skips it. Choose a different workflow rather than editing the bundled one.

## The repository's own agent instructions are a budget lever

`AGENTS.md`/`CLAUDE.md` are re-read and obeyed every turn, so a mandate in them is a per-turn cost multiplier — and often the single biggest lever available, larger than any model or effort setting.

Measured case: `AGENTS.md` said *"Before declaring a task complete, run `npm run verify`"*, and that script is `verify:test && verify:build && verify:e2e` — the full Playwright suite against Firebase emulators. The implement node ran **`npm run verify` five times** (plus `verify:e2e` and `firebase emulators:export`), 38 of the run's 78 minutes, each run injecting tens of thousands of tokens that were then re-sent on every subsequent turn. Meanwhile CI already ran the full `verify` as a required check on every push — the local runs verified nothing CI was not about to verify anyway.

Diagnose it by extracting the tool calls and reading the actual commands:

```python
# tool_called events carry the command in data.tool_name for codex bash nodes
[ (e['created_at'], e['data']['tool_name']) for e in events
  if e['event_type'] == 'tool_called' and e['step_name'] == 'deliver__impl__implement' ]
```

Classify them into READ / WRITE / CHECK / git buckets. A healthy split is mostly reads and edits with a couple of checks; **16 of 62 turns being check runs, five of them the full suite, is the signature of a mandate that is duplicating CI.**

Before proposing the change, confirm the redundancy: read `.github/workflows/*.yml` and check whether the same command is a required check. Removing a local duplicate of a CI job does not reduce verification coverage. The fix belongs in the repo's instruction file (a small PR), not in the workflow YAML — and it is the user's file, so propose the exact wording rather than editing silently.

## Put the runtimes the tail needs on PATH once

The delivery tail needs runtimes the upstream image does not ship (see `node-and-python-runtimes-in-ai-tools.md`). Anything missing gets downloaded into `/tmp` by the agent, mid-run, at the cost of turns and context — and the leftovers persist (255 MB of JDK/JRE tarballs and extracts were found from a single failed run). Java is needed for the Firebase emulator suite; install a wrapper in `/opt/ai-tools/bin` alongside `node`/`npm`/`uv` so a run never has to fetch it.

## Two things that are NOT levers

- **`fallbackModel`** — capability-gated to claude only (`fallbackModel: false` for codex, opencode, pi, copilot). Cannot move a Codex-exhausted node off Codex.
- **Per-node model overrides via settings** — the run-metadata `overrides` field carries only `tiers` and `aliases`; workflow YAML declares `model:` per node and aliases are rejected inside bundled workflows as non-portable. A node cannot be re-pointed by configuration alone.

## Traps

- **Never enable the Fast/priority service tier.** It is 1.5-2x lower latency for **increased usage** — the wrong direction when the goal is to spend less.
- **Check for a high `multi_agent_reasoning_effort` on the chosen model.** A frontier model can spawn subagents at a higher effort than the node's own (`xhigh` while the node runs `medium`). Inspect `task_activity` events for subagent turns to see whether it is actually firing.
- **Repository instruction files are re-sent every turn.** Both `AGENTS.md` and `CLAUDE.md` existing is correct (each provider reads its own) — but if they duplicate each other, ~10 KB each is ~2% of a 118k context, compounding over hundreds of turns. Small, free, and easy to over-claim: measure the file size before presenting it as a saving.

## Reporting honestly

Distinguish the lever that changes the bucket (structural, large) from the ones that shave percentages (effort, instruction files). Presenting all of them as equal "options" hides the one that matters. Where a lever's effect is small, say the number rather than implying it is the fix.
