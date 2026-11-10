# Home Assistant automation operations

Use this reference when creating, repairing, or verifying Home Assistant automations through the web frontend and its authenticated runtime.

## Preflight and authentication

1. Open the supplied Home Assistant URL and verify the expected login page.
2. Prefer a dedicated temporary administrator account; advise rotating/removing it afterward.
3. If login returns `User cannot authenticate remotely`, the temporary user has local-network-only login enabled. Ask the owner to disable that restriction for this user; do not weaken global network controls.
4. Use read-only discovery before editing anything.
5. Direct browser navigation may restart the auth flow unless session persistence is enabled. Prefer in-app navigation or enable “Keep me logged in” for the temporary session.

Never include credentials, access tokens, private hostnames, or exact home coordinates in skill notes or reports.

## Reliable entity and service discovery

The frontend exposes its authenticated runtime at:

```js
const hass = document.querySelector('home-assistant')?.hass;
```

Useful read-only sources:

```js
Object.values(hass.states)
hass.services.notify
hass.states['zone.home']
hass.states['alarm_control_panel.alarm']
```

Filter by entity domain and `attributes.device_class`, not only friendly-name text. For openings, inspect every `binary_sensor.*` whose device class is `door`, `window`, `opening`, or `garage_door`. Treat missing, `unknown`, and `unavailable` values as unsafe.

Prefer `person.*` entities over raw phone trackers when persons are correctly linked. Person states may be named zones, not only `home`/`not_home`; “away” should mean a state not in `['home', 'unknown', 'unavailable']`.

## Inspect before creating

Search `automation.*` entities by friendly name before creating a duplicate. If a similarly named automation exists, inspect and repair it when that best matches the requested behavior.

Read and write UI-managed automations through the authenticated frontend helper:

```js
const cfg = await hass.callApi(
  'GET',
  `config/automation/config/${automationId}`
);

await hass.callApi(
  'POST',
  `config/automation/config/${automationId}`,
  configObject
);
```

A successful write returns `{ result: 'ok' }`. Always read it back and confirm the loaded `automation.*` entity is `on`.

If the config endpoint rejects the entity suffix, resolve the automation's registry `unique_id` first and use that as `automationId`:

```js
const reg = await hass.callWS({
  type: 'config/entity_registry/get',
  entity_id: 'automation.example'
});
const cfg = await hass.callApi(
  'GET',
  `config/automation/config/${reg.unique_id}`
);
```

## Diagnose a missed presence trigger

Do not infer the cause from current states alone. Reconstruct the incident window through recorder history for:

- every relevant `person.*`;
- each person's active source from `person.attributes.source`;
- the corresponding `device_tracker.*` entities;
- the alarm panel and automation;
- every opening sensor used as a condition.

Use UTC timestamps in API calls and convert them to the home's timezone in the report:

```js
const history = await hass.callApi(
  'GET',
  `history/period/${startUtc}?filter_entity_id=${entityIds.join(',')}` +
    `&end_time=${encodeURIComponent(endUtc)}&minimal_response`
);
```

Interpretation sequence:

1. Find when each person changed from `home` to an away state.
2. Confirm the transition came from the expected source tracker.
3. Add the trigger's stabilization duration to determine when it should have fired.
4. Check all alarm/contact conditions at that exact time, not only at departure.
5. Inspect `last_triggered` and available traces. No trace plus a presence expression that never became true usually means the trigger never fired, rather than an action failure.
6. Compare location updates with other Companion App sensors. Fresh battery/activity data alongside stale GPS indicates that the app is connected but background location is not working.

For iOS, inspect `sensor.<device>_location_permission` when available. `Authorized when in use` is not sufficient for reliable background departure detection. Ask the owner to set Location to **Always**, enable **Precise Location**, **Background App Refresh**, and mobile data, then open the Companion App once and perform a real departure test.

Never treat an old `home` or stale tracker state as `not_home`: someone may still be inside. Keep alarm arming fail-closed. Improve reliability with corrected phone permissions, a trustworthy redundant presence source, and/or a separate stale-tracker warning.

## Monaco editor pitfall

Home Assistant's YAML editor is Monaco-based. Generic fill/clear browser actions can append instead of replace. For a full replacement:

1. Focus the editor.
2. Press `Ctrl+A` (`Cmd+A` on macOS).
3. Press Backspace/Delete.
4. Confirm the editor is empty.
5. Type the replacement and save.
6. Check for parse-error banners.

Prefer the authenticated automation config API for structured updates when available.

## Safe alarm auto-arming pattern

Use a stabilized template trigger and repeat the presence test as a condition to protect against races:

```yaml
triggers:
  - trigger: template
    value_template: >-
      {{ states('person.person_a') not in ['home', 'unknown', 'unavailable']
         and states('person.person_b') not in ['home', 'unknown', 'unavailable'] }}
    for:
      minutes: 5
conditions:
  - condition: template
    value_template: >-
      {{ states('person.person_a') not in ['home', 'unknown', 'unavailable']
         and states('person.person_b') not in ['home', 'unknown', 'unavailable'] }}
  - condition: state
    entity_id: alarm_control_panel.alarm
    state: disarmed
  # Add an exact state: 'off' condition for every discovered opening sensor.
actions:
  - action: alarm_control_panel.alarm_arm_away
    target:
      entity_id: alarm_control_panel.alarm
mode: single
```

Explicit `state: 'off'` contact checks fail closed for open, missing, unknown, and unavailable sensors.

Do not manually run this action while occupants are home. Verify configuration, template rendering, current states, and entity load instead.

## Almost-home alarm warning

Use a template trigger on distance to `zone.home`, with one trigger ID per person and a shared alarm condition:

```yaml
triggers:
  - trigger: template
    id: person_a_near_home
    value_template: >-
      {{ state_attr('person.person_a', 'latitude') is not none
         and distance('person.person_a', 'zone.home') <= 1.5 }}
conditions:
  - condition: template
    value_template: >-
      {{ states('alarm_control_panel.alarm') not in
         ['disarmed', 'unknown', 'unavailable'] }}
```

Do not require `not_home` in the distance trigger: a delayed GPS update may jump directly from outside the threshold to `home`, which would miss the warning. The distance template is true at home, false after travelling beyond the threshold, and true again once when returning inside it.

Start around 1–2 km when the user wants margin for iOS background-location delay. Explain that actual timing depends on phone updates. Route trigger IDs through `choose` to each person's own `notify.mobile_app_*` service.

Attention-grabbing iOS payload:

```yaml
data:
  title: "⚠️ Alarm staat nog aan"
  message: "Pas op: het alarm thuis staat nog aan. Schakel het uit vóór je binnenkomt."
  data:
    tag: alarm-bijna-thuis
    push:
      sound:
        name: default
        critical: 1
        volume: 1
      interruption-level: critical
```

Critical delivery still depends on Companion App and iOS permissions.

## Non-side-effecting verification

Render templates through Home Assistant itself:

```js
await hass.callApi('POST', 'template', { template: '{{ ... }}' });
```

Before completion, verify:

- config reads back exactly;
- automation entity exists and is `on`;
- referenced entities and notification services exist;
- templates render without errors;
- current results match live states;
- no alarm action or notification was manually triggered unless explicitly requested.
