---
name: home-assistant-ops
description: Use when operating or debugging de gebruiker's Home Assistant.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [home-assistant, alarmo, zwave, automation, presence, truenas]
    related_skills: [truenas-app-ops, hermes-s6-container-supervision]
---

# Home Assistant ops (de gebruiker)

Home Assistant runs as a TrueNAS community app (container `ix-home-assistant-home-assistant-1`) exposed at `https://example.com/` (Cloudflare published route). Use the Cloudflare URL as the established API route. For local-connectivity diagnostics, discover the actual published port rather than assuming port 8123; direct TLS on `192.0.2.10:30103` has been reached successfully. Re-test reachability before drawing conclusions.

## When to Use

Load this skill when inspecting or changing anything in de gebruiker's Home Assistant from Hermes — alarm/automation debugging (Alarmo, Z-Wave sensors), presence-tracking questions, or reading why an automation did or didn't fire.

## Credentials

`HASS_URL` and `HASS_TOKEN` (Long-Lived Access Token) live in `/opt/data/profiles/dev-builder/.env`. Load into shell variables WITHOUT echoing the token:

```bash
HASS_URL=$(grep -E '^HASS_URL=' /opt/data/profiles/dev-builder/.env | cut -d= -f2- | sed 's#/*$##')
HASS_TOKEN=$(grep -E '^HASS_TOKEN=' /opt/data/profiles/dev-builder/.env | cut -d= -f2-)
AUTH="Authorization: Bearer $HASS_TOKEN"
```

Never print `HASS_TOKEN`. The Hermes `homeassistant-platform` plugin (tools `ha_get_state`, `ha_list_entities`, `ha_call_service`) needs the same token but is only loaded in the dev-builder profile — from the default profile, drive HA with curl.

## REST endpoints

All with `-H "$AUTH"`:

- `GET /api/states` — every entity + state (filter/print client-side).
- `GET /api/states/<entity_id>` — one entity's full state + attributes.
- `GET /api/history/period/<iso>?end_time=<iso>&filter_entity_id=a,b` — state-change timeline.
- `GET /api/logbook/<iso>?end_time=<iso>&entity=<id>&entity=<id2>` — event log; `context.user_id` set = manual action, empty = automation/system.
- `GET /api/config` — version, `time_zone`, `country`.
- `GET /api/error_log` — recent warnings/errors (to confirm a trigger is/isn't erroring).
- `GET/POST /api/config/automation/config/<id>` — read/update one automation's full config. `<id>` is the numeric `id` field (e.g. `1781301881728`), NOT the entity_id (that returns 404). POST body = full config; returns `{"result":"ok"}`.

## Diagnosing iPhone connectivity incidents

- de gebruiker confirmed the iPhone Companion app URL is `https://example.com`, including during the reported home-Wi-Fi incident. A separate internal URL/SSID configuration has not been verified. Do not assume the app uses HA's server-side `internal_url` setting.
- Check historical HA and cloudflared logs at the reported times; current HTTP 200 or a location update does not prove the frontend worked earlier.
- Docker `--timestamps` prefixes are UTC while HA's inner log timestamps use Europe/Brussels. Convert before correlating incidents.
- Preserve de gebruiker's preferred architecture: the iPhone Companion app, Cloudflare for external access, and a separate direct internal URL selected on home Wi-Fi. Inspect the app's internal/external URL and SSID settings before recommending a replacement service or VPN; the app supports both URLs for one server.
- Diagnose TLS trust and hostname matching separately. The local endpoint has served a Cloudflare Origin CA certificate: changing from an IP address to a matching hostname alone does not make that certificate trusted by the iPhone. Never disable certificate validation as the permanent remedy. Follow `references/local-https-connectivity.md` for the tested inspection method and acceptance gates.
- Confirm router model and local DNS capabilities before proposing split DNS; an ISP name or managed PoE switch does not establish those capabilities. A Cloudflare dashboard login is not an already-configured DNS automation credential; arrange any narrowly scoped DNS token through secure local/browser input, never chat.
- Keep the existing external route working throughout migration, and obtain separate approval before a Home Assistant restart or security action. Do not report a local HTTPS fix complete until trust validation and actual iPhone Wi-Fi/4G switching have been tested.
- Cloudflared QUIC failures to numeric edge IPs plus simultaneous DNS timeouts suggest broader network trouble, not a proven DNS-only root cause. Avoid changing DNS or tunnel protocol before isolating the cause.
- A read-only SSH identity may be available through `/opt/data/profiles/dev-builder/ssh/config`, alias `truenas-archon`; verify access and approval rather than assuming host access is unavailable. Never inspect or print secret environment/config values during diagnostics.

## Debugging "the automation didn't fire"

1. Read the automation entity and check `last_triggered`, but do not treat an old value as proof of a dead trigger: condition failures can also leave it unchanged. Establish whether the configured trigger actually occurred using history and inspect traces when available. For presence, verify each person AND its source device tracker; stale `home` is not proof of occupancy. Inspect `sensor.<phone>_location_permission`: `Authorized when in use` is a reported iOS permission incompatible with reliable background location tracking; have the owner confirm current settings and choose Always + Precise Location if they consent. Never bypass a stale occupant by arming based on the other person alone.
2. Pull the relevant entity history (`/api/history/period`) to confirm the trigger inputs actually moved (e.g. both `person.*` went `not_home`, `zone.home` went to `0`).
3. Pull a focused logbook with `entity=` filters to see who/what acted and when (manual vs automation).
4. Read the automation's actual trigger/condition/action via websocket (see references).

## Pitfalls

- **Strip the trailing slash** from `HASS_URL` before appending `/api/` — the .env value ends in `/`, so `"$HASS_URL/api/"` becomes `//api/` and returns 404.
- **`/api/trace/automation.X` returns 404 when there are no recent traces.** That 404 is itself the diagnostic (the automation has not run recently; traces cover only the last ~5 runs) — it is not an endpoint error.
- **Websocket command is `automation/config` with `entity_id`, not `config/automation/config`.** The latter is "Unknown command"; the former without `entity_id` raises KeyError (surfaces as "Unknown error").
- **Template triggers with a `for:` clause can silently stop firing.** When an "arm when everyone leaves" style automation dies, check `last_triggered` before blaming sensors or the alarm integration. Prefer a `state` trigger on `zone.home → "0"` (with `for:`) over a template trigger, and keep the "don't arm if a person is `unknown`/`unavailable`" safety as a template CONDITION — conditions still evaluate on a state trigger.
- **`automation.trigger` service skips conditions by default (`skip_condition: true`).** Never call it to "test" an arming/security automation — it runs the action directly and will arm/trigger the alarm. If you must exercise it, pass `skip_condition: false` and be ready to disarm.
- **Disarm a triggered Alarmo alarm with `alarmo.disarm` (Alarmo's own service), not `alarm_control_panel.alarm_disarm`.** The standard service requires the alarm code and fails silently; `alarmo.disarm` with only `entity_id` disarms without a code.
- **Cloudflare blocks Python urllib/requests (HTTP 403 code 1010, user-agent based).** Drive HA with `curl`, not Python's urllib/requests.
- **`binary_sensor.*_siren_active` sensors go stale and stick `on`.** After an alarm sounds, the Z-Wave siren's active-status sensors often stay `on` until the next poll — don't use them to judge whether the siren is currently sounding. Read `alarm_control_panel.alarmo` instead (`triggered` = sounding; `disarmed` = silent).

## References

- `references/local-https-connectivity.md` — direct-origin TLS inspection, Origin CA versus client trust, and internal/external Companion access verification.
- `references/websocket-automation-config.md` — read an automation's config (REST by numeric id, or websocket) and update it via REST POST.
