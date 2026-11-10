# Browser E2E robustness recipes

Distilled copy-paste patterns for Playwright specs that are deterministic and honest. Generic — the Supabase-specific REST/realtime stub lives in `expo-supabase-playwright-web-e2e`.

## Relative-to-now fixtures
When a screen filters by the wall clock ("now"/"upcoming"/"live"), the stubbed record's window must contain the test's runtime:
```ts
const pad2 = (n: number) => String(n).padStart(2, '0');
const timeOf = (d: Date) => `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}`;
const start = new Date(Date.now() - 30 * 60_000);
const end = new Date(Date.now() + 60 * 60_000);
const record = { session_date: new Date().toISOString().slice(0, 10),
                 start_time: timeOf(start), end_time: timeOf(end), /* ... */ };
```
Assert on the field the UI renders (a card's class/group name), which may differ from the stubbed feature title.

## strict-mode-safe text selectors
`getByText` matches substrings. When a trigger button's label is a prefix/substring of the modal title it opens ("Show check-in QR" vs "Check-in QR"), both resolve and Playwright throws a strict-mode violation:
```ts
await expect(page.getByText('Check-in QR', { exact: true })).toBeVisible(); // title, not the button
```
Or take `.first()` when order is deterministic. Keep substring matching only when it is genuinely unambiguous.

## Keep clean-console assertions green
If you collect console `error`/`warning`, `pageerror`, and `requestfailed` and assert the list is empty, stub every passive request so it never aborts:
```ts
// Browsers request /favicon* on nearly every page and abort it when unhandled.
await page.route('**/favicon*', (r) => r.fulfill({ status: 204 }));
// Any socket the app opens (realtime, events) must be accepted/replied to, or it fails and pollutes.
await page.routeWebSocket('wss://**', (ws) => { /* accept + answer joins, or scope the collection */ });
```
Where truly-zero is impossible, scope the collection to the errors the test cares about instead of asserting none.

## Gates -> assert the shell, unit-test the body
A surface gated by a default-off feature flag or a signed-in-user (auth) gate renders empty when the harness can't satisfy it (e.g. auth is a passthrough with no user). Don't fabricate a session:
```ts
await expect(page.getByText('<header>').first()).toBeVisible();
await expectNarrowLayout(page); // shell reachable, no overflow
// gated content left to the hook's unit suite
```

## Verify the served bundle, not your env
Read the artifact to confirm a baked value reached the build:
```bash
b=$(curl -fsS http://127.0.0.1:$PORT/ | grep -o 'entry-[a-f0-9]*\.js' | head -1)
curl -fsS http://127.0.0.1:$PORT/_expo/static/js/web/$b | grep -c '<sentinel>'
```
A 0 count means the served build lacks the expected dependency — rebuild rather than reason about env inheritance. Free the port / kill stale servers before changing build env so `reuseExistingServer` can't serve an old export.

## test-results hygiene
Playwright writes tracked `test-results/` artifacts. Restore before committing so CI artifacts never appear in the diff:
```bash
git restore -- test-results
```
