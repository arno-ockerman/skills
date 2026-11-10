# s6-Supervised Multi-Profile Gateway Reference

**Session context:** Cron job checking Fireflies webhook deliveries (2026-06-11)

## Environment Discovery

This Hermes deployment runs **multiple gateway instances under s6 supervision**, each tied to a profile:

| Gateway Process | Profile | Active Platforms |
|----------------|---------|------------------|
| `hermes -p dev-builder gateway run` (PID 3531) | dev-builder | (check profile config) |
| `hermes -p health-coach gateway run` (PID 3529) | health-coach | (check profile config) |
| `hermes gateway run` (no -p, PID 3533) | default | `telegram` ✅, `webhook` ✅ (port 8644) |

**Key files:**
- Main config: `/opt/data/config.yaml` (has `platforms.webhook.enabled: true`, port 8644, secret)
- Profile configs: `/opt/data/profiles/<name>/config.yaml` (may differ)
- Gateway state: `/opt/data/data/gateway_state.json` (shows active platforms per profile)
- s6 service dir: `/run/s6/services/gateway-<profile>/`
- Webhook subscriptions: `/opt/data/webhook_subscriptions.json`

## Webhook Status (Verified 2026-06-11)

- **Port 8644 IS bound and responding** — `curl http://localhost:8644/webhooks/fireflies` returns 405 (Method Not Allowed for GET), test POST returns 202 Accepted
- **Fireflies subscription exists** in `/opt/data/webhook_subscriptions.json`
- **Route:** `fireflies` → delivers to Telegram (chat_id: EXAMPLE_CHAT_ID)
- **Events:** All (accepts `meeting.transcribed` and `meeting.summarized` V2 events)
- **Gateway logs:** `/opt/data/logs/gateways/default/current` (s6-log format)

## Real Webhook Deliveries (2026-06-11)

| Time (UTC) | Event | Result | Notes |
|------------|-------|--------|-------|
| 01:39:08 | Test: `meeting.transcribed` (meeting_id: `ASxwZxCstx`) | ✅ 202 Accepted | Agent ran, tried to fetch transcript (no API key) |
| 01:47:40 | Test: template payload | ✅ 202 Accepted | Agent ran with unrendered template |
| **01:50:24** | **Real Fireflies delivery** | ❌ **401 Invalid signature** | Likely real webhook — HMAC validation failed |

**Key finding:** The 01:50:24 delivery with "Invalid signature" is likely a **real Fireflies webhook** that failed HMAC validation — possibly because the Fireflies dashboard webhook URL points to a different endpoint or the secret there doesn't match the subscription secret (`[REDACTED]`).

## Missing Configuration (Blocking Transcript Fetch)

| Missing | Impact |
|---------|--------|
| `FIREFLIES_API_KEY` in `/opt/data/.env` | Without it, agent cannot call Fireflies GraphQL API to fetch full transcripts/summaries |

## Checking Which Gateway Has Webhook Enabled

```bash
# List all s6-supervised gateway processes
ps aux | grep "hermes.*gateway run" | grep -v grep

# Check gateway state file (shows active platforms per profile)
cat /opt/data/data/gateway_state.json

# Check per-profile config
cat /opt/data/config.yaml | grep -A 10 "platforms:"
cat /opt/data/profiles/default/config.yaml   # if exists
cat /opt/data/profiles/dev-builder/config.yaml
cat /opt/data/profiles/health-coach/config.yaml
```

## Static vs Dynamic Webhook Routes

- **Static routes** — defined in `config.yaml` under `platforms.webhook.extra.routes`. Require gateway restart to add/change.
- **Dynamic routes** — created via `hermes webhook subscribe`, stored in `~/.hermes/webhook_subscriptions.json`, hot-reloaded on each request.
- Static routes take precedence over dynamic ones with the same name.

## Fireflies Webhook Payload Formats

See `references/fireflies-webhook.md` for full V1/V2 payload formats and GraphQL API query.

## Cron Job Context

- Job: `fireflies-webhook-handler` (runs every 5 minutes via `*/5 * * * *`)
- Prompt: Process new Fireflies deliveries, save to `/opt/ai-context/ProductivityCenter/Meetings/YYYY-MM-DD - Topic.md`
- Decisions → `/opt/ai-context/ProductivityCenter/decisions/log.md`
- Action items → relevant project folders

**DEFINITIVE FINDING (2026-06-11):** This cron job is **fundamentally misguided and should be removed.** Webhooks are push-based — the webhook adapter already receives events in real-time. The cron job found no new processable deliveries (only a failed HMAC delivery at 01:50:24). Repurpose it ONLY to query Fireflies API directly for recent transcripts if a webhook was missed during gateway downtime.

## Common Pitfalls

❌ **Cron job polling for webhook deliveries** — Webhooks are **push-based**. Fireflies POSTs to your endpoint when events occur. Do NOT create a cron job to "check for new deliveries." The webhook adapter receives events in real-time.

✅ **Let the webhook adapter handle delivery** — The Hermes gateway webhook platform:
1. Receives POST at `/webhooks/fireflies`
2. Validates HMAC signature
3. Rate-limits per route
4. Deduplicates via idempotency keys
5. Renders prompt template with payload fields
6. Triggers agent run with typed prompt
7. Delivers response to configured target (Telegram, etc.)

⚠️ **Event filtering** — The `--events` filter matches against payload `event` field for Fireflies V2. Use `--events "meeting.transcribed,meeting.summarized"` or omit to accept all.

⚠️ **Local testing** — For local development, use a tunnel (ngrok, cloudflared) so Fireflies can reach your webhook URL:
```bash
ngrok http 8644
# Use https://xxx.ngrok-free.app/webhooks/fireflies as the webhook URL in Fireflies dashboard
```

⚠️ **Telegram token conflict (multi-profile) — RESOLUTION (2026-06-11):**
Only ONE gateway can hold the Telegram bot connection. The `gateway-health-coach` instance was holding it, causing all webhook responses from `gateway-default` to fail delivery with "Telegram bot token already in use" error.
**Fix:** Stop the conflicting instance via `s6-svc -d /run/s6/services/gateway-health-coach`, then restart the webhook profile via `s6-svc -r /run/s6/services/gateway-default`. Verify with `ps aux | grep "hermes.*gateway run" | grep -v grep` that only the intended gateway is running.