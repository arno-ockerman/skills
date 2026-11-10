---
name: production-observability-agents
description: "Use when designing production-monitoring agents."
---

# Production Observability Agents

Design reusable agents that inspect a production application, its repository, delivery pipeline, runtime, data layer, authentication, error tracking, and product analytics. Treat the system as a deterministic monitoring workflow with bounded LLM analysis, not as an open-ended chatbot.

## Procedure

### 1. Define the operational loop before choosing a framework

Write the loop as explicit stages:

```text
collect → normalize → correlate → deduplicate → prioritize → report → approve → act → verify
```

List which stages are deterministic and where an LLM adds value. Use code for collection, schemas, thresholds, fingerprints, policy gates, and verification. Use the LLM for cross-source explanation, root-cause hypotheses, and concise recommendations.

Do not choose a framework from its chat or agent demo. Score it against this loop: schedules/webhooks, durable retries, persisted state, human approval, idempotency, TypeScript support, self-hosting, observability, evals, and provider portability.

### 2. Inventory capabilities, not vendor names

Describe each app through optional capabilities:

- repository and CI
- deployment runtime
- synthetic journeys
- database health
- authentication health
- error/performance tracking
- product analytics
- cost and quota monitoring

Map technologies to these capabilities only in app configuration. Report unconfigured capabilities explicitly; never imply coverage that does not exist.

Keep error tracking and product analytics separate. Sentry-style tooling can explain exceptions, traces, and latency, but does not replace funnels, feature usage, session behavior, or conversion analytics.

### 3. Establish one normalized signal contract

Every provider must return the same small `Signal` shape: source, category, fingerprint, evidence, observed time, environment, severity, confidence, affected version/users, links, and optional code hints.

Correlate signals into a `Finding` containing:

- evidence and source links
- impact
- suspected cause, clearly labeled as a hypothesis
- recommended next action
- severity and confidence
- duplicate issue, when found
- lifecycle status

Never emit an actionable finding without evidence, impact, a next action, duplicate detection, and confidence. This prevents the watchdog from becoming an alert-noise generator.

### 4. Put portability at real seams

Keep provider implementations outside the core. Introduce an adapter seam only when behavior genuinely varies; two implementations make the seam real. Typical interfaces are `DatabaseMonitor`, `AuthMonitor`, `ErrorTracker`, `ProductAnalyticsMonitor`, `DeploymentMonitor`, and `RepositoryMonitor`.

The shared core owns correlation, deduplication, severity, reporting, approvals, and finding lifecycle. Each app owns provider selection, thresholds, critical journeys, architecture notes, and policies.

Use one monorepo with independently deployable app agents rather than copying a full agent directory per product. Package shared behavior as framework-native extensions or ordinary TypeScript packages, depending on the chosen runtime.

See `references/provider-capabilities.md` for capability boundaries and adapter guidance; `references/sentry-noise-filtering.md` for classifying and filtering error-tracker noise (test/dev, third-party injected-browser, and genuine app defects) plus dedup patterns that stop event amplification.

### 5. Separate shared and app-specific behavior

Share:

- provider adapters
- signal and finding schemas
- correlation and fingerprinting
- policy enforcement
- report rendering
- core evals

Keep app-local:

- critical user journeys
- known query allowlists
- data-quality invariants
- severity overrides
- architecture knowledge
- domain-specific evals

Do not bury provider behavior in prompt instructions. Put it in typed code so it is testable and portable.

### 6. Start read-only and narrow

Build one vertical slice first:

1. one app
2. repository/CI signals
3. error tracker
4. one database-health provider
5. one read-only production smoke journey
6. one daily evidence-based report

Delay automatic issue creation, code edits, database repairs, index changes, deployment, and messaging until the signal quality is proven. Require approval for every external write. Keep production database writes disabled by policy, not merely by prompt.

Use least-privilege, app-specific credentials. Prefer aggregate metrics and technical identifiers; exclude personal data from reports by default.

Provision one credential per role and probe it against the exact endpoint the job will call before enabling the job. A build-artifact upload token is not a read token: it authenticates to the project endpoint (HTTP 200) yet returns 403 on the issues endpoint, because listing issues requires a read scope (for Sentry, `event:read`) that source-map upload does not need. Request the read scope explicitly, gate job enablement on a live successful probe, and store the value where the job runs — never in the product repository.

### 7. Make schedules replay-safe

Use different cadences for urgent health checks, hourly infrastructure checks, daily analysis, and weekly trends. Fingerprint every signal and finding. Store observation windows and action IDs so retries, replay, or overlapping schedules cannot create duplicate issues or repeat side effects.

Treat collection as retryable and action as idempotent. Persist approval state and verify every approved external change by reading the target back.

### 8. Test behavior, not only code

Core evals must cover duplicate suppression, confidence thresholds, missing-provider reporting, PII exclusion, approval enforcement, resolved-finding behavior, and unsupported causal claims.

App evals must cover domain-specific invariants and realistic cross-source incidents. Test adapters with fixtures through their shared interface; test the core with provider fakes rather than live services.

### 9. Prove portability with a second stack

Do not declare the architecture reusable after one integration. Add a second app with a materially different database and auth provider without copying the core. If core changes are required for vendor-specific concepts, move those concepts back behind the provider seam.

See `references/framework-selection.md` for a repeatable framework decision process.

## Output style

When proposing this architecture, present:

1. the operational loop
2. shared core versus app-specific configuration
3. capability coverage per app
4. provider seams
5. safety and approval policy
6. MVP vertical slice
7. explicit framework trade-offs

Prefer concrete TypeScript interfaces, folder structures, and staged scope over generic architecture prose.
