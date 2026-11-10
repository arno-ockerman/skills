# Supabase stubbing recipe (Expo web export + Playwright)

## Only the REST stub is not enough
`page.route` covers REST only. Supabase's client always opens `wss://<host>/realtime/v1/websocket`; left alone it fails `ERR_NAME_NOT_RESOLVED` and spews console errors. When the spec asserts a clean console, that single failure sinks every test in the file. Stub it with `page.routeWebSocket` too.

## Find the env var the build-harness actually reads
A self-contained E2E server builds the export itself (`scripts/*-web-server.cjs` running `expo export --platform web`). Read the server before touching the spec — it often maps build env itself, e.g. bakes `EXPO_PUBLIC_SUPABASE_URL`/`EXPO_PUBLIC_SUPABASE_ANON_KEY` from `E2E_SUPABASE_URL`/`E2E_SUPABASE_ANON_KEY`, and forces `EXPO_PUBLIC_E2E_MODE=true`, `EXPO_PUBLIC_ENABLE_WEB_AUTH=false`.

Set the var it READS (the `E2E_*` name) to the stub host. Setting the wrong name makes `isSupabaseConfigured` false ("Supabase not configured" warning in console), the REST stubs never match a live host, and every selector silently finds nothing while the only clue is a console warning.

## Verify the served bundle, not the env
Env propagation into a Playwright `webServer` child is easy to get wrong. Read the artifact:
```
b=$(curl -fsS http://127.0.0.1:$PORT/ | grep -o 'entry-[a-f0-9]*\.js' | head -1)
curl -fsS http://127.0.0.1:$PORT/_expo/static/js/web/$b | grep -c '<stub-host>'
```
A 0 count means the served bundle was built without the stub; rebuild rather than reason about env inheritance.

## Kill stale servers before re-running
`reuseExistingServer` happily serves a STALE export built with an earlier env. Free the port (kill lingering `e2e-web-server`/`expo export` processes) before changing env so the fresh build is what actually serves.

## REST stub
```
await page.route(`${supabaseUrl}/**`, async (route) => {
  const req = route.request();
  if (req.method() === 'OPTIONS') return route.fulfill({status:204, headers: CORS});
  const table = new URL(req.url()).pathname.replace('/rest/v1/','');
  if (!table.startsWith('rpc/')) return route.fulfill({status:200, json: fixtureRowsFor(table)});
  switch (table.slice('rpc/'.length)) { /* get_staff_sessions, check_in_member, ... */ default: [] }
});
```

## Realtime WebSocket stub
`page.routeWebSocket` is a Playwright PAGE method (>=1.46), not a top-level module export:
```
await page.routeWebSocket(`${wssUrl}/realtime/v1/websocket*`, (ws) => {
  ws.onMessage((message) => {
    const m = JSON.parse(message.toString());
    if (m.event === 'phx_join') ws.send(JSON.stringify({topic:m.topic, event:'phx_reply', ref:m.ref, payload:{status:'ok'}}));
    // heartbeat/leave likewise; a valid phx_reply keeps the client silent and the console clean
  });
});
```
Accepting the socket + replying to `phx_join` stops client errors; the channel may stay unconsumed but the console stays clean, which is what the assertion needs.

## Clean-console assertion bar
A spec that collects every `console.error`/`console.warning`/`pageerror`/`requestfailed` and asserts the list is empty in `afterEach` fails the whole file on ANY unhandled warning/error, not just the one you are testing. Complete stubbing must cover every surface the routes load, or scope the collection to the errors the test cares about.

## Narrow-viewport layout assertions (replace source-string checks)
Never assert layout via `fs.readFileSync` source + counting `<ScrollView>`/`<FlatList>` literals — it is brittle and proves nothing rendered. In the browser on a narrow viewport assert real DOM:
- no document-level horizontal overflow: `document.documentElement.scrollWidth <= window.innerWidth && document.body.scrollWidth <= window.innerWidth`
- no more than one active vertical scroll owner: elements with `overflow-y:auto|scroll` AND `scrollHeight > clientHeight`
- the last/target control is reachable (visible, not clipped)

At the component seam, assert behavior (e.g. showing walk-in search hides the roster so only one list can scroll) rather than markup counts.
