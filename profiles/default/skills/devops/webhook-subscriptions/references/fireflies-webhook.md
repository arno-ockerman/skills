# Fireflies.ai Webhook Integration Reference

## Overview
Fireflies.ai provides meeting transcription and summarization with webhook notifications. Two webhook versions exist:

- **V1 (Legacy)** — Single event: `Transcription completed`
- **V2 (Current)** — Granular events: `meeting.transcribed`, `meeting.summarized`

Configure at: https://app.fireflies.ai/integrations/api/webhook (V2) or Settings → Developer (V1)

## Webhook V2 Payload Format

### meeting.transcribed
```json
{
  "event": "meeting.transcribed",
  "timestamp": 1710876543210,
  "meeting_id": "ASxwZxCstx",
  "client_reference_id": "be582c46-4ac9-4565-9ba6-6ab4264496a8"
}
```

### meeting.summarized
```json
{
  "event": "meeting.summarized",
  "timestamp": 1710876789456,
  "meeting_id": "ASxwZxCstx"
}
```

## Webhook V1 Payload Format (Legacy)
```json
{
  "meetingId": "ASxwZxCstx",
  "eventType": "Transcription completed",
  "clientReferenceId": "be582c46-4ac9-4565-9ba6-6ab4264496a8"
}
```

## Signature Verification
- Header: `X-Hub-Signature` (both V1 and V2)
- Format: `sha256=<hex-encoded-hmac-sha256-digest>`
- Algorithm: HMAC-SHA256 with shared secret
- Secret configured in Fireflies dashboard (16-32 chars, or auto-generated)
- **Current subscription secret:** `[REDACTED]` (from `/opt/data/webhook_subscriptions.json`)

## Hermes Subscription Setup

```bash
# Subscribe to all Fireflies events (V2 format)
hermes webhook subscribe fireflies \
  --events "" \
  --prompt "Fireflies meeting event: {event}. Meeting ID: {meeting_id}. Timestamp: {timestamp}. Client Reference ID: {client_reference_id}. Fetch transcript from Fireflies API." \
  --deliver telegram \
  --deliver-chat-id "EXAMPLE_CHAT_ID" \
  --secret "your-fireflies-secret"
```

**Note:** Omitting `--events` or using `--events "meeting.transcribed,meeting.summarized"` accepts all V2 events. The `event` field is in the payload body (not a header).

## Fetching Full Transcript/Post-Webhook

The webhook only delivers a notification. To get the full transcript/summary, call Fireflies GraphQL API:

```bash
# Query transcript details
curl -X POST https://api.fireflies.ai/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{"query": "query Transcript($transcriptId: String!) { transcript(id: $transcriptId) { id title date duration summary { action_items outline overview bullet_gist shorthand_bullet short_summary topics_discussed } sentences { index speaker_name text start_time end_time } } }", "variables": { "transcriptId": "ASxwZxCstx" }}'
```

**Requires `FIREFLIES_API_KEY`** in `~/.hermes/.env` or profile `.env`.

## Common Pitfalls

### ❌ Cron job polling for webhook deliveries
Webhooks are **push-based** — Fireflies POSTs to your endpoint when events occur. Do NOT create a cron job to "check for new deliveries." The webhook adapter receives events in real-time.

**Definitive finding (2026-06-11 cron run):** The `fireflies-webhook-handler` cron job (runs `*/5 * * * *`) executed and found **no new processable deliveries** — the only real Fireflies delivery (01:50:24 UTC) failed HMAC validation. The cron job is unnecessary and should be **removed or repurposed** to only query Fireflies API directly for recent transcripts if a webhook was missed during gateway downtime.

### ✅ Let the webhook adapter handle delivery
The Hermes gateway webhook platform:
1. Receives POST at `/webhooks/fireflies`
2. Validates HMAC signature
3. Rate-limits per route
4. Deduplicates via idempotency keys (X-GitHub-Delivery, svix-id, etc.)
5. Renders prompt template with payload fields
6. Triggers agent run with typed prompt
7. Delivers response to configured target (Telegram, etc.)

### ⚠️ Event filtering
The `--events` filter matches against:
- `X-GitHub-Event` header
- `X-GitLab-Event` header
- `payload.event_type` or `payload.type`

For Fireflies V2, the event is in the payload body as `event` field. Use `--events "meeting.transcribed,meeting.summarized"` or omit `--events` to accept all.

### ⚠️ Local testing
For local development, use a tunnel (ngrok, cloudflared) so Fireflies can reach your webhook URL:
### ⚠️ HMAC signature mismatch (401 Invalid signature)
**Observed 2026-06-11 01:50:24 UTC and 04:53:19 UTC** — Two real Fireflies deliveries returned "Invalid signature" in gateway logs.
- **Cause:** Fireflies dashboard webhook URL may point to a different path, or the secret configured in Fireflies doesn't match the Hermes subscription secret (`[REDACTED]`).
- **Fix:** Verify in Fireflies dashboard (https://app.fireflies.ai/integrations/api/webhook) that:
  - Webhook URL is exactly `https://your-domain/webhooks/fireflies`
  - Secret matches `[REDACTED]`
- **Confirmation:** The second failure at 04:53:19 proves this is a persistent configuration mismatch, not a transient error.

### ❌ Cron job polling for webhook deliveries
Webhooks are **push-based** — Fireflies POSTs to your endpoint when events occur. Do NOT create a cron job to "check for new deliveries." The webhook adapter receives events in real-time.

**Definitive finding (2026-06-11 cron runs):** The `fireflies-webhook-handler` cron job (ID: `1846d27d84d3`, runs `*/5 * * * *`) executed 30+ times between 03:41–05:18 UTC and found **zero new processable deliveries** — the two real Fireflies deliveries (01:50:24, 04:53:19) both failed HMAC validation. The cron job is unnecessary and should be **removed or repurposed** to only query Fireflies API directly for recent transcripts if a webhook was missed during gateway downtime.

### ⚠️ Profile-aware gateway mismatch (multi-profile setups)
**Observed 2026-06-11** — The webhook subscription existed in the default profile (`/opt/data/webhook_subscriptions.json`), and the default profile's gateway was running and receiving webhooks on port 8644. However, the Telegram delivery platform failed because the Telegram bot token was already in use by another gateway instance.

**Observed 2026-06-11 (cron job run)** — A scheduled cron job executed to "check for new Fireflies webhook deliveries" but found none (last real delivery was the failed HMAC one at 01:50:24). **This cron job is unnecessary** — webhooks are push-based. The webhook adapter already receives events in real-time. Remove or repurpose this cron job to only query Fireflies API directly for transcripts if a webhook was missed (e.g., during gateway downtime).

**Gateway state at time of investigation:**
- Three gateway processes running: `gateway-default` (PID 3533), `gateway-dev-builder` (PID 3531), `gateway-health-coach` (PID 3529)
- `gateway_state.json` only showed state for one (stopped) instance — s6 supervision state not fully reflected
- **Telegram token conflict:** Only ONE gateway can hold the Telegram bot connection. The `gateway-default` instance had webhook active but Telegram showed "disconnected" with "Telegram bot token already in use" error.

- In multi-profile/s6 setups, **each profile runs its own gateway** with its own platform connections.
- The webhook subscription must be created in the **profile whose gateway is actually running and reachable** at the public webhook URL.
- Check `gateway_state.json` to see which platforms are active per gateway instance.
- If Telegram (or other delivery) fails with "token already in use", another gateway instance is holding the connection — stop it via `s6-svc -d /run/s6/services/gateway-<other-profile>` before starting the correct one.
- **Fireflies webhook secret must match** the configured subscription secret (`[REDACTED]`) in Fireflies dashboard at https://app.fireflies.ai/integrations/api/webhook.

## API Key
Get your Fireflies API key at: https://app.fireflies.ai/settings → Developer Settings → API Key