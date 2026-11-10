# Provider capabilities and seams

Use this reference when different production apps have different infrastructure stacks.

## Capability map

| Capability | Typical providers | What it can establish |
|---|---|---|
| Repository/CI | GitHub, GitLab | failed checks, stale PRs, issue state, changed code |
| Deployment | Vercel, Cloud Run, Firebase Hosting | releases, runtime failures, deployment correlation |
| Synthetic monitoring | Browser runner, Playwright | availability and reproducible user-flow failures |
| Database health | Firestore, Postgres/Supabase | latency, operations, quotas, connections, query health |
| Authentication health | Firebase Auth, Clerk | sign-in failures, session/token health, identity consistency |
| Error tracking | Sentry | exceptions, regressions, traces, affected users, latency |
| Product analytics | PostHog or equivalent | funnels, feature usage, behavior anomalies, conversion |
| Cost/quota | Cloud provider billing/metrics | anomalous usage, quota pressure, cost trends |

## Required distinctions

- Do not model error tracking as product analytics. Technical failures and user behavior answer different questions.
- Do not model a database provider as generic SQL when one implementation is document-oriented. Keep shared output generic while provider-specific query analysis remains inside the adapter.
- Do not let auth adapters expose personal data by default. Return aggregate health signals and opaque identifiers unless an approved investigation requires more.
- Do not execute arbitrary production queries. Maintain app-local allowlists of known health and query-plan checks.

## Suggested interfaces

```ts
interface SignalCollector {
  collect(context: WatchContext): Promise<Signal[]>;
}

interface DatabaseMonitor extends SignalCollector {
  inspectKnownQueries?(context: WatchContext): Promise<Signal[]>;
  inspectDataQuality?(context: WatchContext): Promise<Signal[]>;
}

interface AuthMonitor extends SignalCollector {
  inspectConsistency?(context: WatchContext): Promise<Signal[]>;
}

interface ErrorTracker extends SignalCollector {
  collectRegressions(context: WatchContext): Promise<Signal[]>;
}

interface ProductAnalyticsMonitor extends SignalCollector {
  inspectCriticalFunnels?(context: WatchContext): Promise<Signal[]>;
}
```

Keep interfaces small. Optional methods represent genuinely optional capabilities; provider absence must appear as a coverage gap rather than an empty successful result.

## Example cross-stack configuration

```ts
const apps = {
  appA: {
    database: { type: "firebase" },
    auth: { type: "firebase-auth" },
    errorTracking: { type: "sentry" },
    productAnalytics: { type: "posthog" },
  },
  appB: {
    database: { type: "supabase" },
    auth: { type: "clerk" },
    errorTracking: { type: "sentry" },
    productAnalytics: undefined,
  },
};
```

Validate configuration at startup. A missing optional provider disables and reports that capability; an incomplete configured provider fails fast.
