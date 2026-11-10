# Health-coach recovery reference

## Problem shape
A Hermes Telegram bot reported provider auth failure. After provider recovery, the profile still showed repeated API server reconnect failures with:

- `Port 30432 already in use`
- `api_server failed to connect`

## What mattered
The profile `config.yaml` already had a non-conflicting API server port, but the live gateway process still inherited:

- `API_SERVER_ENABLED=true`
- `API_SERVER_HOST=0.0.0.0`
- `API_SERVER_PORT=30432`

This meant the supervised runtime environment overrode the YAML config.

## Durable lesson
When a Hermes profile in an s6/with-contenv container keeps binding the wrong API server port after YAML edits:

1. Inspect `gateway_state.json` and the newest `gateway.log` lines.
2. Inspect the live gateway process environment.
3. If `API_SERVER_*` vars are present there, fix the profile `.env` (or the relevant supervisor env source), not only `config.yaml`.
4. Restart under supervision and verify both platform states and the final `API server listening on http://...` log line.

## Recovery pattern that worked
- Restore or validate the provider with a real `hermes --profile ... chat` smoke test.
- If needed, use a known-good fallback provider/model to get the bot usable again first.
- For the port conflict, set profile-local API server env vars so the supervised gateway starts with the intended port.
- Restart the gateway and confirm:
  - `telegram: connected`
  - `api_server: connected`
  - `gateway_state: running`

## Why this is worth remembering
This is not a generic 'change the port in config.yaml' issue. The key diagnostic move was proving that runtime env injection beat the profile YAML, which changes the fix path completely.
