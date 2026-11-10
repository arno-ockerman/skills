# Fireflies Webhook Fixes — Session 2026-06-11

## Complete Fix Commands (Run in Order)

```bash
# 1. Add Fireflies API Key
echo "FIREFLIES_API_KEY=your_api_key_here" >> /opt/data/.env
s6-svc -r /run/s6/services/gateway-default

# 2. Fix Fireflies Dashboard Webhook Secret
# Go to: https://app.fireflies.ai/integrations/api/webhook
# Set Webhook URL to: https://your-domain/webhooks/fireflies
# Set Secret to: [REDACTED]

# 3. Attach Processing Skill to Webhook Subscription
# Note: This REPLACES the existing subscription to add skill + events filter
hermes webhook subscribe fireflies \
  --events "meeting.transcribed,meeting.summarized" \
  --prompt "Fireflies meeting event: {event}. Meeting ID: {meeting_id}. Timestamp: {timestamp}. Client Reference ID: {client_reference_id}. Use the fireflies-processing skill to fetch the full transcript and save as markdown." \
  --skills "fireflies-processing" \
  --deliver telegram \
  --deliver-chat-id "EXAMPLE_CHAT_ID" \
  --secret "[REDACTED]"

# 4. Stop Conflicting Gateway (Free Telegram Token)
s6-svc -d /run/s6/services/gateway-health-coach

# 5. Disable Anti-pattern Cron Job
hermes cron pause 1846d27d84d3
```

## What Was Actually Fixed (2026-06-11 ~07:44 UTC)

```bash
# 3. Recreated webhook subscription with correct configuration
hermes webhook remove fireflies
hermes webhook subscribe fireflies \
  --events "meeting.transcribed,meeting.summarized" \
  --prompt "Fireflies meeting event: {event}. Meeting ID: {meeting_id}. Use the fireflies-processing skill to fetch the full transcript and save as markdown." \
  --skills "fireflies-processing" \
  --deliver telegram \
  --deliver-chat-id "EXAMPLE_CHAT_ID" \
  --secret "[REDACTED]"
# Result: Subscription now has skills=["fireflies-processing"], events=["meeting.transcribed","meeting.summarized"], secret=[REDACTED]

# 5. Paused cron job (note: used 'pause' not 'edit --enabled false')
hermes cron pause 1846d27d84d3
# Result: Job ID 1846d27d84d3 now has enabled=false, state=paused
```

## Still Pending (Require Manual Action)

| Step | Action | Why |
|------|--------|-----|
| 1 | Add `FIREFLIES_API_KEY` to `/opt/data/.env` and restart gateway | GraphQL fetch will fail without it |
| 2 | Update Fireflies dashboard webhook secret to `[REDACTED]` | 2 real deliveries already failed HMAC |
| 4 | Stop `gateway-health-coach` via `s6-svc -d` | Releases Telegram token for default gateway |

## Verification After Fixes

```bash
# Run verification script
/opt/data/skills/devops/fireflies-processing/scripts/verify-fireflies-setup.sh
# Expected: skill attached ✓, events filter ✓, cron paused ✓

# Test webhook end-to-end
hermes webhook test fireflies --payload '{"event":"meeting.summarized","meeting_id":"TEST_ID","timestamp":1710876789456,"client_reference_id":"test"}'
# Expected: HTTP 202 accepted, agent runs with fireflies-processing skill
```

## Recover Missed Meetings

The 2 real meetings that failed HMAC (2026-06-11 01:50:24 & 04:53:19 UTC) can be recovered once API key is set:

```bash
# Get meeting IDs from Fireflies dashboard, then:
hermes skill fireflies-processing process_meeting --meeting_id "ASxwZxCstx"
# Repeat for second meeting ID
```

## Evidence from This Session

- **Webhook endpoint healthy**: `curl http://localhost:8644/health` → `{"status":"ok","platform":"webhook"}`
- **2 real deliveries failed HMAC**: Gateway logs show "Invalid signature for route fireflies" at 01:50:24 and 04:53:19 UTC
- **Test webhooks work**: Multiple test deliveries processed successfully (01:39:08, 01:47:40, 04:08:12, 06:28:49, 07:42:13 UTC)
- **Cron job status**: ID `1846d27d84d3`, `*/5 * * * *`, 52 runs completed, **paused after run #52**
- **Three gateways running**: default (PID 3533), dev-builder (PID 3531), health-coach (PID 3529)
- **Telegram conflict**: health-coach gateway holds bot token; default gateway shows "disconnected"
- **Missing FIREFLIES_API_KEY**: Not in `/opt/data/.env`
- **Skill not attached (FIXED)**: Subscription now has `skills: ["fireflies-processing"]`
- **Events filter missing (FIXED)**: Subscription now has `events: ["meeting.transcribed","meeting.summarized"]`

## ProductivityCenter Structure (Confirmed Existing)

```
/opt/ai-context/ProductivityCenter/
├── Meetings/          # YYYY-MM-DD - Topic.md
├── decisions/
│   └── log.md         # Append-only decisions log
└── Projects/
    ├── AI tools/
    ├── club-app/
    ├── hermes/
    └── openclaw/      # Action items routed here
```