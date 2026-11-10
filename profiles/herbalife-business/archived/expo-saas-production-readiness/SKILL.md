---
name: expo-saas-production-readiness
description: Harden an Expo/React Native SaaS app for production across web and mobile with env-driven config, CI gates, and CLI workflows for Vercel, Supabase, Clerk, and EAS.
---

# Expo SaaS Production Readiness

## When to use
Use this when a project is an Expo / Expo Router app that needs to move from "works locally" to a repeatable production workflow across web and mobile, especially when the stack includes:

- Expo / Expo Router
- Vercel for web hosting
- Supabase for database/functions/migrations
- Clerk for auth
- EAS for mobile builds/submission

This skill is for deployment hardening, not for feature work.

## Outcome
By the end, the repo should have:

1. A buildable, testable baseline.
2. Env-driven Expo config for production-only values.
3. CLI entrypoints for web deploys, Supabase migrations/functions, and EAS builds.
4. A CI gate that blocks on the real shipping path.
5. Clear fail-fast behavior when credentials are missing.
6. Documentation that matches the actual implementation instead of stale placeholder instructions.

## Steps

### 1) Stabilize the repo before touching deployment
Run the real quality path first. Fix hard blockers before adding infra scripts.

Minimum verification set:

- Lint (or a consciously scoped lint pass if legacy debt exists)
- Typecheck
- Tests
- Production web export/build
- Release-critical E2E smoke on the actual browser/runtime path

For Expo web, treat `expo export --platform web` as the concrete shipping check when the app deploys a static web output.

Do **not** start by wiring deploy automation around a repo that currently fails to build.

### 1b) Use an explicit verify-fix-verify loop
For production-readiness sessions, do not stop after a single green command. Iterate in this order:

1. run the broadest relevant quality gate (`lint`, `typecheck`, test suite, export/build)
2. fix the highest-risk blocker first (runtime logic, hook order, payment/booking/auth flows)
3. rerun the exact failed gate
4. rerun the full shipping path
5. finish with an independent diff-focused review when config rules or hook behavior changed

This catches the common failure mode where a lint/config cleanup silently introduces a runtime regression.

### 2) Move Expo production values into `app.config.ts`
Prefer dynamic Expo config over static placeholder-driven `app.json` when production identifiers are environment-dependent.

Use `app.config.ts` to:

- read `EXPO_PROJECT_ID`
- set `updates.url` only when the project ID exists
- inject `extra.eas.projectId`
- fail fast in production mode if a required identifier is missing

Pattern:

- `APP_ENV=production` + missing `EXPO_PROJECT_ID` => stop early
- non-production => allow local/dev defaults

This avoids stale "replace placeholder in app.json" workflows.

### 3) Add an env validation script that reads env files too
Create a small script that validates grouped env requirements for targets like:

- `web`
- `supabase`
- `eas`
- `submit`
- `vercel`

Important pitfall: do not only inspect `process.env`.
Also load known env files such as:

- `.env`
- `.env.local`
- `.env.production`
- `.env.production.local`

Otherwise the checker will falsely fail even though Expo/Vite/Next-style tooling would load those values during builds.

The validator should print:

- each required key with pass/fail status
- a concise missing-vars summary
- non-zero exit when required keys are missing

### 4) Wrap external CLIs in repo-local scripts
Create deterministic repo scripts for each external platform instead of expecting future agents to hand-type commands.

Recommended wrappers:

- `scripts/vercel-deploy.mjs`
- `scripts/supabase-deploy.mjs`
- `scripts/eas-build.mjs`

These wrappers should:

- validate required credentials up front
- print the underlying command they are about to run
- exit non-zero on failure
- support preview vs production mode explicitly

#### Vercel wrapper pitfall
Fail fast before calling `vercel pull/build/deploy` if neither of these exists:

- `VERCEL_TOKEN`
- a local Vercel auth file from `vercel login`

That produces a clearer message than letting the CLI drop into credential errors later.

#### Supabase wrapper pitfall
For migration / function deployment flows, validate the exact required remote credentials first, e.g. access token, project ref, DB password. Make dry-run entrypoints available for CI verification.

### 5) Build the CI gate around the real deployment path
Prefer a practical gate over an aspirational one.

For this class of app, the blocking path should usually be:

1. install dependencies
2. typecheck
3. run tests
4. run production web export/build
5. validate env for production deploy jobs
6. run dry-run migration checks where possible

### 6) Do not let unrelated legacy lint debt block production hardening
If lint is noisy because of pre-existing debt outside the deployment path, do not blindly keep it in the blocking deploy gate.

Instead:

- keep lint available as a separate command
- document why it is not currently blocking
- make typecheck/tests/export the shipping gate

This is acceptable when the goal is MVP production readiness and lint debt is not the immediate release risk.

Do **not** hide real type or build failures behind this rule.

### 7) Update stale docs immediately
After switching to dynamic config or env-driven workflows, patch old docs that still say things like:

- "replace placeholder in app.json"
- "update eas.json placeholders"

Replace them with the new source of truth:

- env var names
- CI secret names
- actual script entrypoints

If docs are not updated in the same session, the repo remains operationally inconsistent.

## Public web pages and marketing surfaces

This umbrella also covers the public-web-page layer inside an Expo Router app. Public vanity routes, campaign pages, and lightweight marketing landers are not a separate class from production readiness here — they are part of the same shipping surface.

Use this subsection when the job is to turn existing app data into a stable public web page such as `/[slug]`, `/club/[slug]`, or another shareable route.

### Default pattern

1. Reuse an existing internal/public data flow instead of inventing a second backend path.
2. Move public URL creation into helper modules so share links, canonical URLs, and settings screens all use one source of truth.
3. Keep web-only components isolated behind `.web.tsx` wrappers or equivalent platform guards.
4. Build the page in layers: hero, trust/value block, offers, freshness/upcoming content, location/directions.
5. Add helper tests for path formatting, absolute URLs, map links, and SEO fallback text.
6. Verify with the real shipping path: typecheck, tests, and web export/build.

### Recommended file shape

- route entrypoint such as `app/[slug].tsx`
- public link helper like `src/features/.../publicLinks.ts`
- web-safe location/embed components split by platform when needed
- focused helper tests under the project's test tree

### Key pitfalls

- do not hardcode public URLs in multiple places
- do not mix web-only embed code directly into shared native components
- do not call the route done until the web export/build succeeds
- do not overscope v1 when a strong landing page can be assembled from existing app metadata

## Verification checklist
A good finish looks like this:

- `npm run lint` passes, or lint debt is explicitly scoped to known legacy files instead of being ignored repo-wide
- `npm run typecheck` passes
- tests pass
- production web export/build passes
- release-critical E2E smoke passes on a real browser install
- env validator succeeds or clearly reports missing keys
- Expo config resolves correctly with and without production project ID
- wrapper scripts fail fast with actionable messages when credentials are absent
- CI config points at the same commands you verified locally
- generated artifacts like `coverage/` are treated as repo hygiene, not mistaken for shipping blockers

## Pitfalls

- Adding deploy automation before the app builds.
- Leaving Expo project/update identifiers as manual placeholders in static config.
- Writing env checkers that ignore `.env.production`.
- Treating lint debt as a release blocker when the real shipping path is already type-safe and build-safe.
- Solving noisy lint by disabling rules repo-wide instead of scoping debt to legacy files or fixing the underlying runtime issue.
- Updating code paths but leaving operational docs on the old workflow.
- Treating generated `coverage/` output as product code during readiness review; clean or ignore it separately from shipping risk.
- Forgetting to run a second review pass after hook-order or lint-config changes.

## Support files
- `references/club-app-production-hardening.md` — concrete examples from real Expo + Vercel + Supabase + Clerk hardening passes, including verification-loop and Playwright/browser-path notes.
