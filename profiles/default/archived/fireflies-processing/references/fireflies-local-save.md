# Fireflies Local Save Workflow — Reference

**Source:** `webhook-subscriptions/references/fireflies-local-save.md`

This file is a pointer to the detailed workflow documentation in the webhook-subscriptions skill. For the complete current state, configuration, blockers, and directory structure, see:

> **`webhook-subscriptions/references/fireflies-local-save.md`**

## Key Points (Summary)

- **Target directories** (already exist):
  - `/opt/ai-context/ProductivityCenter/Meetings/` — `YYYY-MM-DD - Topic.md`
  - `/opt/ai-context/ProductivityCenter/decisions/log.md` — Append-only decisions log
  - `/opt/ai-context/ProductivityCenter/Projects/` — Action items routed by project

- **Current blockers** (as of 2026-06-11):
  1. Missing `FIREFLIES_API_KEY` in `/opt/data/.env`
  2. HMAC secret mismatch — Fireflies dashboard secret ≠ `[REDACTED]`
  3. Telegram token conflict — `gateway-health-coach` holds the bot connection
  4. Cron job `fireflies-webhook-handler` (ID: `1846d27d84d3`, `*/5 * * * *`) incorrectly polls for push-based webhooks

- **Webhook subscription** (active):
  - Route: `/webhooks/fireflies`
  - Secret: `[REDACTED]`
  - Events: `[]` (accepts all)
  - Skills: `[]` — **needs `fireflies-processing` attached**
  - Deliver: `telegram` to chat_id `EXAMPLE_CHAT_ID`

- **Real deliveries received** (both failed HMAC):
  - 2026-06-11 01:50:24 UTC
  - 2026-06-11 04:53:19 UTC

See the source file for complete GraphQL query, markdown format, decisions log format, and implementation options.