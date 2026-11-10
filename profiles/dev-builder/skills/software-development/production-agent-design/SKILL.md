---
name: production-agent-design
description: "Use when designing durable workflow-first production agents."
---

# Production Agent Design

How to design a durable, workflow-first production agent (a watchdog/monitor/coordinator that observes systems, correlates signals, and proposes actions with human approval) so it stays cheap, provider-independent, and reusable across apps. This is the class-level design, not a specific build.

## Core working model

Two execution planes:

- **Deterministic/default-code nodes** — collect/normalize/dedupe data, compute fingerprints, apply severity/cost/approval rules, strip PII, execute side effects, verify outcomes. No tokens, and more reliable than letting an LLM drive the whole flow.
- **LLM nodes** — only: correlate evidence, write a root-cause hypothesis, pick affected code, draft an issue/PR. Keep the LLM out of the control flow.

Only reach for an LLM where judgment or natural language is actually required.

## Steps (order matters)

1. **Define the domain model first, independent of any framework**: a single normalized signal type (source, category, severity, confidence, evidence, fingerprint) plus a finding type (signals + impact + suspectedCause + recommendedAction + duplicate-check). Every provider/technology feeds the same model.
2. **Split a reusable core from per-app config.** A reusable agent (multiple apps, different stacks) must be: shared core (orchestration + normalization/correlation/dedupe/policy) + one config per app + one provider-adapter per technology. Do NOT copy-paste the agent per app.
3. **Separate capabilities from technologies.** Model capabilities as interfaces: `DatabaseMonitor`, `AuthMonitor`, `ErrorTracker`, `ProductAnalyticsMonitor`, synthetic-website, deployment. Adapters implement them (Firebase/Supabase for DB, Clerk/Firebase for auth, Sentry for errors, PostHog for analytics). The core asks "database health? auth health? product analytics?" — never "is this Firebase or Supabase?" Capabilities that are optional (e.g. product analytics = PostHog) must degrade gracefully and the report must state "not configured" explicitly. Never fabricate insight for a provider that isn't wired in.
   - Error tracking and product analytics are DIFFERENT capabilities. Sentry (errors/traces/perf) does not substitute for PostHog (funnels/behavior/rage clicks). Keep them separate; switching one stack does not remove the other.
4. **Design a single model port before writing any vendor code.**
   ```
   interface ModelRouter {
     classify(...); correlate(...); investigate(...); review(...);
   }
   // one class per provider, same contract
   ```
   Graph nodes call ONLY the router, never a provider SDK. Config picks the implementation per role (classifier/coder/reviewer). Swapping an LLM provider = changing one class + one config line.
5. **License-check the deployment product, not just the core library.** Run this check before committing to a run-time.
   - A MIT/OSS orchestration *library* is freely self-hostable in production.
   - The *convenience server* layered on top (schedules, auth, persistence out of the box) is frequently a separate, commercially licensed artifact.
   - Pick the OSS library and build the missing conveniences yourself (Fastify + PostgreSQL + `pg-boss` queue for schedules/retries in one place) to stay on the free layer. Tutorials and one-click deploys steer you to the licensed server — stay on the library in Node.
6. **Reuse paid subscriptions as model backends instead of buying new API keys**, on a trusted private runner only (never a public hosted runner, and no controlling third-party apps with the owner's login). Respect that a consumer subscription is not a general model API: adapters must go through the coding-agent CLI or Agent SDK, not a plain SDK chat client that expects a billing API key.
7. **Cap the spend explicitly.** Never auto-fail over to pay-as-you-go API credits. Cache per-fingerprint results, batch small signals, skip re-analysis when input unchanged, and park jobs when a subscription limit is hit.

## Pitfalls

- **The library is free; its server is not.** `@langchain/langgraph` (and `eve`, `@ai-sdk/workflow`) are MIT/open; but `langgraph-api` / the LangSmith "Agent Server" / "LangSmith Deployment" is Elastic License 2.0 and self-hosting it requires an Enterprise plan + license key. Build schedules/auth/persistence yourself to stay on the free core.
- **Provider independence lives at one seam.** Swapping the LLM provider costs one module IF every node calls a `ModelRouter`. If nodes call provider SDKs directly, a provider change touches every node. The real lock-in is the orchestrator (checkpointers, interrupts, graph structure) — keep `core` + provider adapters decoupled so an orchestrator migration reuses them instead of rewriting.
- **A consumer Claude/Codex subscription is not an API subscription.** `ChatAnthropic`/`ChatOpenAI` need separate billing API keys. To reuse Claude Pro / ChatGPT Plus as backends, call `claude -p` / the Agent SDK / the Codex SDK, authenticated with the existing subscription, on your own private runner.
- **Optional capabilities must not be silently ignored.** If product analytics isn't configured, the report says so and that analysis is skipped — a report that implies full coverage when a domain is unobserved is a false-confidence bug.
- **Do not let the LLM control side effects.** Only the deterministic layer executes writes; issue/PR creation and any production write require explicit human approval gate. Observe+analyze automatic, act approved.

## User preferences (de gebruiker)

- Direct, practical, action-oriented; MVP-first; Dutch.
- Reuse paid systems already subscribed, and keep the core independent of both provider and framework so a future change is a config/layer swap, not a rewrite.
- Reusable-core-plus-per-app-config beats copying the agent per app.

See `references/framework-and-provider-notes.md` for the framework comparison, licensing matrix, and concrete subscription/provider endpoints.
