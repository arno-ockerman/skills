# Sentry error-noise filtering

Use when a production error tracker has a pile of unresolved issues: classify before fixing, and prefer filtering at the transport (`beforeSend`) over one-off code patches.

## Classify each issue before touching code

Pull the sanitized event and read `tags.environment`, `tags.release`, `contexts.browser.name`, and `exception.values[].stacktrace.frames` for each issue. Most events fall into three buckets:

1. **Development / test noise** — `environment=development` or a `/e2e` route (Playwright/localhost). Drop in `beforeSend` for development; keep staging verification opt-in and separately labelled.
2. **Third-party injected-browser noise** — errors the host browser/webview injects, not the app:
   - Facebook in-app browser: `Error invoking postMessage: Java object is gone` with frames under `iabjs://navigation_performance_logger_android`.
   - Chrome-on-iOS truncated script errors: `pa`, `La`, or `Maximum call stack size exceeded.` with no application-owned frame.
3. **Genuine app defects** — normalize (turn thrown PostgREST/plain objects into real `Error`s) and keep.

## The app-frame guard

Drop third-party noise ONLY when no exception in the event carries an application frame — `/src/` path, a hashed `app:///entry-<hash>.js` frame, or a deployed web bundle `/_expo/static/js/web/entry-<hash>.js` (Expo web serves the bundle there, so a real overflow with that frame must not be dropped as browser noise). If any sibling exception has an app frame, keep the whole event — filtering one exception must not discard a genuine stack overflow travelling alongside. Test the mixed-event case explicitly.

Filter on exact `exception.value`/`type` + `contexts.browser.name`, never loose substring matching.

## Dedup patterns that stop amplification

- Threshold reporter: latch, don't compare counts. `>=` emits once per request after the threshold; `count === threshold` still re-fires during a sustained outage because a rolling window that stays at the threshold keeps returning the same count while old failures expire and new ones arrive. Emit once when the window first reaches the threshold, stay latched until it falls back below, then re-arm for the next outage.
- Shared-failure dedup: WeakSet the error object so N concurrent callers of one rejected promise report once.
- Single-flight credential/token lookup: keep one in-flight promise, cleared only by the promise still current — a replaced adapter's stale promise must not clear a newer one.
- Recognize the error downstream of the transport, not just at the throw site: supabase-js wraps a thrown custom-fetch error into a plain `{ error: { message: '<ErrorName>: <message>', code: '' } }` — the custom `code` is dropped and the message is prefixed with the error name. Match the `isXxxError` guard on the distinctive message substring, and any layer that collapses errors to a fallback string must preserve that wrapped message instead of substituting a generic one.

## Sanitization safety

Cycle/depth-bound the event sanitizer before transport (a `WeakSet` for seen objects plus a max depth); circular event data otherwise recurses into a stack overflow inside the reporting path.

## Read scope

A source-map-upload token returns 403 on the issues/events endpoint. Reading them needs `event:read` — request it explicitly and store it where the job runs, never in the repo.
