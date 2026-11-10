---
name: expo-supabase-playwright-web-e2e
description: Expo web E2E stubs Supabase via Playwright (REST+realtime).
version: 1.0.0
author: Hermes
license: MIT
metadata:
  hermes:
    tags: [expo, playwright, supabase, e2e, testing]
    related_skills: [expo-saas-production-readiness]
---

# Expo + Supabase Playwright web E2E

Driving an Expo Router web export through Playwright while the app's Supabase backend is a stubbed fixture, so the same responsive/flow specs run locally and in CI.

## When to use
- A Playwright spec must exercise real query paths (`/rest/v1/rpc/<fn>`, tables) against a stub rather than mock-data fallbacks.
- The E2E harness builds the export itself (a `scripts/*-web-server.cjs` that runs `expo export`) and injects build-time env.
- You are expanding responsive/flow coverage or adding clean-console / layout assertions for Expo web.

## Core procedure
1. Read the E2E web-server script FIRST and find which env var it actually reads to bake Supabase into the export (commonly `E2E_SUPABASE_URL` / `E2E_SUPABASE_ANON_KEY`, not `EXPO_PUBLIC_SUPABASE_URL`). Set the var it reads, to the stub host.
2. Verify the SERVED bundle got the value (grep the served `entry-*.js` for the stub host) instead of trusting env propagation through Playwright's `webServer` child.
3. Free the E2E port before re-running so `reuseExistingServer` cannot serve a stale build baked with an earlier env.
4. Stub BOTH the REST path (`page.route`) AND the realtime WebSocket (`page.routeWebSocket`), or a clean-console assertion fails every test.
5. Keep the stub's intercepted host identical to the value baked into the build, or the routing never matches.
6. Prefer behavior/DOM assertions over source-string assertions for layout/responsive intent.

## Pitfalls
- Setting `EXPO_PUBLIC_SUPABASE_URL` when the harness reads `E2E_SUPABASE_URL`: the app boots "Supabase not configured", selectors silently find nothing, and the real cause is only a console warning. Read the server's env map before writing the spec.
- `page.route` does NOT cover the Supabase realtime socket (`wss://<host>/realtime/v1/websocket`); unimpeded it fails with `ERR_NAME_NOT_RESOLVED` and pollutes the console.
- A spec that asserts an EMPTY console collection (every `error`/`warning`/`pageerror`/`requestfailed`) makes one unhandled WebSocket join fail the whole file — complete the stubbing or scope the collection.
- Replacing a brittle source-count layout test with a browser spec must prove real DOM state (no horizontal overflow, single scroll owner) — not a different implementation-coupled check.
- Empty the port and kill lingering `e2e-web-server`/export processes before changing env and re-running; a reused stale server defeats every fix.

## Support files
- `references/supabase-stubbing-recipe.md` — full recipe: env-bake gotcha, served-bundle verification, REST + realtime WebSocket stubbing, clean-console bar, narrow-viewport layout assertions.
