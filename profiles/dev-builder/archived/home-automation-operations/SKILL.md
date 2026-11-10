---
name: home-automation-operations
description: Safely discover, create, repair, and verify smart-home automations, especially Home Assistant presence, alarm, opening-sensor, zone, and mobile-notification workflows.
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [home-assistant, smart-home, automation, alarm, presence, notifications]
    category: productivity
---

# Home Automation Operations

Use this class-level skill when the user asks to inspect, create, repair, test, or verify smart-home automations. It is especially applicable to Home Assistant workflows involving presence, Alarmo/alarm panels, door/window contacts, zones, phone trackers, or Companion App notifications.

## Operating discipline

1. Establish the exact desired trigger, conditions, actions, recipients, and safety behavior.
2. Authenticate with a dedicated temporary account where possible; advise credential rotation/removal afterward.
3. Perform read-only discovery before writes: existing automations, entity IDs, device classes, current states, services, zones, and notification targets.
4. Inspect for an existing automation before creating another; repair it when that best matches the user's intent.
5. For presence failures, reconstruct the incident timeline from recorder history for the `person.*` entities, their active `device_tracker.*` sources, the alarm, automation, and opening sensors. Compare `last_changed` and `last_updated`; a connected phone can still have stale GPS while battery sensors continue updating.
6. Check each mobile device's location-permission sensor when available. On iOS, `Authorized when in use` is insufficient for reliable background presence; require `Authorized Always`, Precise Location, Background App Refresh, and mobile-data access.
7. Treat security automations as fail-closed: missing, stale, `unknown`, or `unavailable` presence/contact/alarm data must not be interpreted as away/closed. Never “fix” stale presence by assuming away; add a stale-tracker warning or a trustworthy redundant tracker instead.
8. Make the smallest targeted change, then read the persisted configuration back.
9. Verify templates and entity load without causing dangerous or noisy side effects. Do not arm an occupied home or send live alerts merely to prove configuration unless the user explicitly requests that test.
10. Report the actual automation name/entity, conditions, recipients, incident timeline, root cause, and verification results.

## Home Assistant branch

For browser-based Home Assistant operation, use the frontend's authenticated `hass` runtime for precise discovery and structured config reads/writes when available. Prefer entity domains and `device_class` over fuzzy friendly-name matching.

For established implementation patterns, API examples, Monaco-editor pitfalls, safe alarm arming, distance-based arrival warnings, critical iOS notifications, and non-side-effecting verification, read:

- `references/home-assistant-automation.md`

## Security and privacy

- Never preserve passwords, tokens, private hostnames, or exact home coordinates in skill files.
- Avoid exposing secrets in screenshots, console output, or final reports.
- Use exact explicit entity lists for security-critical openings rather than broad assumptions.
- `unknown` and `unavailable` are not equivalent to away, closed, or disarmed.
- A successful config save is insufficient: read back the config and confirm the runtime automation entity is loaded and enabled.

## Verification checklist

- [ ] Existing automation checked before creating a duplicate.
- [ ] Person/device-tracker mapping confirmed.
- [ ] Incident-window history checked for each person, source tracker, alarm, automation, and opening condition.
- [ ] Tracker freshness and mobile location permissions confirmed; stale `home` was not interpreted as away.
- [ ] Every relevant opening sensor discovered by domain/device class.
- [ ] Alarm entity and valid states confirmed.
- [ ] Notification services mapped to the correct devices.
- [ ] Persisted automation config read back.
- [ ] Templates rendered by Home Assistant without errors.
- [ ] Runtime automation entity exists and is `on`.
- [ ] No unsafe action or unwanted notification fired during verification.
