# Framework & provider notes

Topical depth for choosing an orchestrator and wiring LLM providers for a durable workflow-first production agent.

## Framework comparison (workflow-first watchdog use case)

| Framework | Strong point | Weak point | Fit |
|---|---|---|---|
| **LangGraph.js** (library) | Explicit stateful graphs, durable checkpoints, `interrupt()` human-in-the-loop, mix deterministic + LLM nodes | More boilerplate than Eve; schedules/auth not built-in (build yourself) | **Best balance** for a reusable production workflow |
| **Eve** | Fast filesystem-first agent dev; built-in schedules, approvals, channels, subagents, evals; good Vercel/Next fit | Younger/preview; agent-loop-centric rather than explicit domain workflow | Excellent prototype / fast demo |
| **Mastra** | Modern TS: agents, typed workflows, Studio, evals, suspend/resume | Durable runner less proven than Temporal/Eve | Good if you want Studio + evals bundled |
| **Temporal + Vercel AI SDK** | Strongest durability: retries, timers, schedules, approvals via signals, audit history; official `@temporalio/ai-sdk` wraps model calls as Activities | Operationally heavy (server/workers/determinism); evals/agent tracing added separately | Best enterprise backbone later |

Recommendation: **LangGraph.js library** for V1. **Temporal + AI SDK** is the future migration path if it becomes business-critical — keep `core` + provider adapters decoupled so the migration reuses them.

## Licensing — the trap

| Component | License | Free in production? |
|---|---|---|
| `@langchain/langgraph` (orchestration) | **MIT** | ✅ Self-host, unlimited |
| `eve`, `@ai-sdk/workflow` | MIT/open | ✅ |
| Vercel AI SDK | MIT/Apache | ✅ |
| PostgreSQL + `pg-boss`, Playwright, Fastify, Zod, Vitest | open-source | ✅ self-host |
| `langgraph-api` / LangSmith "Agent Server" / "LangSmith Deployment" | **Elastic 2.0** | ❌ self-host requires Enterprise plan + license key |
| LangSmith observability | Free tier ~5k traces/mo; Plus $39/seat/mo | ⚠️ small free tier only |

Rule: take the MIT library, build schedules/auth/persistence yourself (Fastify + PostgreSQL + `pg-boss` on one host) and stay on the free layer. Do not adopt the convenience Agent Server — one-click deploys steer you to it.

## Reusing de gebruiker's existing subscriptions as model backends

Environment: Claude Code and Codex CLI live under `/opt/ai-tools/bin` and are already logged into their subscriptions under `/opt/data`. On the TrueNAS/AI-tools stack.

| Subscription | Backend adapter | Placement |
|---|---|---|
| **OpenCode Go** ($10/mo) | HTTP endpoints via `@ai-sdk/openai` / `@ai-sdk/openai-compatible` / `@ai-sdk/anthropic` + a Go API key | **Primary/routine** LLM: classify, correlate, summarize reports, draft issue concepts |
| **ChatGPT Plus** | `@openai/codex-sdk` (or `codex exec`), authenticated to ChatGPT, `auth.json` on private runner | Code/CI investigation, root-cause on the repo, later patch prep in a worktree |
| **Claude Pro** | `claude -p --output-format json` or the Claude Agent SDK | Critical/second review, security review, PR/patch review |
| Anthropic/OpenAI **API keys** | Standard `ChatAnthropic`/`ChatOpenAI` | NOT in V1 (billed separately) |

### OpenCode Go endpoints (official)

Base: `https://opencode.ai/zen/go/`.

| Model family | Endpoint | AI SDK package |
|---|---|---|
| grok-4.6, gpt-5.6-luna | `/v1/responses` | `@ai-sdk/openai` |
| glm-5.x, kimi, longcat, deepseek-v4, mimo, hy | `/v1/chat/completions` | `@ai-sdk/openai-compatible` |
| minimax, qwen3.x, union-alpha | `/v1/messages` | `@ai-sdk/anthropic` |

Full model list: `GET /v1/models`. Use `opencode-go/<model-id>` in OpenCode config. Send a stable `x-opencode-session` header + real client user-agent (Go monitors for coding-agent traffic).

### Codex SDK

```ts
import { Codex } from "@openai/codex-sdk";
const codex = new Codex();
const thread = codex.startThread({ workingDirectory, sandboxMode });
const result = await thread.run(prompt);
```

ChatGPT-managed auth on a trusted private runner: seed `~/.codex/auth.json` once, let Codex refresh it in-place, write it back between runs. Treat it like a password. API keys remain the official recommendation for generic automation; the auth-file route is for trusted private runners only. Never in Git/images/logs, no public runner.

### Claude Pro

Claude Pro covers Claude Code; `claude -p` / Agent SDK usage draws from plan limits (interactive TUI is a separate shared limit). It is NOT a general Anthropic API bundle — `ChatAnthropic` needs a separate billing key, so go through `claude` CLI or Agent SDK with subscription auth. Own private runner, own login, and never expose the login to control third-party apps.

## V1 self-host stack (all free/open)

```text
TrueNAS (Docker Compose/App)
├── watchdog-api      Fastify + Cloudflare Zero Trust (e.g. watchdog.<host>)
├── watchdog-worker   LangGraph runs + provider collectors
├── watchdog-scheduler pg-boss jobs → queue (no self-execution)
├── PostgreSQL        LangGraph checkpoints + domain state + pg-boss
└── Playwright/Chromium browser checks
```

Provider adapters: GitHub, Sentry, PostHog, Firebase, Supabase, Clerk, Vercel, browser. Each returns the same normalized signal model.
