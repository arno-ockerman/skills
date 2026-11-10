---
name: browser-e2e-spec-authoring
description: Use when authoring browser (Playwright) E2E specs.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [playwright, e2e, testing, web]
    related_skills: [expo-supabase-playwright-web-e2e]
---

# Browser E2E spec authoring

Writing Playwright specs against a built web app so they pass reliably in CI and locally, with assertions that mean what they say. The Supabase-specific REST + realtime stubbing recipe for Expo web lives in `expo-supabase-playwright-web-e2e`; this skill is the generic authoring layer beneath it.

## When to use
- Writing or expanding a browser spec for responsive / layout / flow / clean-console coverage.
- A review finding must become a stable browser regression test.
- A selectors- or timing-related Playwright failure needs a durable fix.

## Core procedure
1. Make fixtures time-deterministic. If any screen filters by the wall clock (a "now"/"upcoming"/"live" list, a today view), compute the record's window from `Date.now()` at spec load — a fixed clock time makes the spec time-of-day dependent (green at 09:00, red at 21:00).
2. Assert on what is actually rendered. A card may show the class/group name, not the feature title you stubbed; assert on the rendered value.
3. Use `{ exact: true }` on `getByText` whenever the element's text is a substring or prefix of another reachable label (a trigger button that shares text with the modal it opens) or Playwright resolves both and throws a strict-mode violation.
4. If you assert a clean console (empty collected error/warning/pageerror/failed-request list), stub every surface the routes touch: `/favicon*` (browsers abort it on every page) and any WebSocket the app opens. Scope the collection to the errors you care about rather than asserting truly-zero when that is impossible.
5. Respect gates. A surface behind a default-off feature flag or a signed-in-user (auth) gate renders an empty shell when the harness cannot satisfy it. Assert the reachable shell (header renders, no overflow) and cover the gated behavior in the hook's unit suite — do not fabricate an auth session or click through screens the harness cannot get past.
6. Verify the served artifact, not your env. Grep the served bundle for a sentinel you baked in, rather than trusting env propagation to a `webServer` child. Free the port / kill stale servers before changing build env so an old export is not reused.
7. Hygiene: Playwright writes tracked `test-results/` artifacts; `git restore -- test-results` before committing so CI artifacts never dirty the PR diff.
8. When a review finding drives a fix, write the browser test first (red), then the minimal source change (green): that proves the test would have caught the bug it now guards.

## Pitfalls
- Fixed-clock fixture + a "live now" filter: the spec silently flips with the time of day. Compute relative to `now`.
- `getByText('<title>')` when an earlier button already contains that text as a substring: strict-mode violation, not a missing element. Use `{ exact: true }` or `.first()`.
- A single unsusbtubbed favicon or WebSocket aborts and sinks a whole clean-console file. Stub assets and sockets; scope the collection.
- Asserting a gated/authed surface's content the harness can't produce makes the test permanently red. Assert the shell; unit-test the gate.
- Committing Playwright's `test-results` churn hides real changes. Always `git restore -- test-results`.

## Support files
- `references/robustness-recipes.md` — copy-paste patterns: relative-now fixtures, exact-text selectors, asset/websocket stubs, and the served-bundle probe.
