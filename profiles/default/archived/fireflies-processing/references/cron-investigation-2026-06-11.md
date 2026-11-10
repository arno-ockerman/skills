# Cron Job Investigation — Fireflies Webhook Handler (2026-06-11)

## Executive Summary
The cron job `fireflies-webhook-handler` (ID: `1846d27d84d3`, schedule: `*/5 * * * *`) was created to "check for new Fireflies webhook deliveries" but **webhooks are push-based, not pull-based**. The webhook adapter receives events in real-time via HTTP POST. No polling is needed.

## Current State

### Webhook Endpoint
- Route: `/webhooks/fireflies`
- Secret: `[REDACTED]`
- Subscription file: `/opt/data/webhook_subscriptions.json`
- Events accepted: `[]` (all events)
- Skills attached: `[]` — **missing `fireflies-processing`**
- Delivery: Telegram to chat_id `EXAMPLE_CHAT_ID`

### Gateway Configuration
- Default gateway PID 3533: running, but **webhook platform not showing as active** in gateway_state.json
- Health-coach gateway (PID 3529): holds Telegram bot token connection
- Dev-builder gateway (PID 3531): also running
- **Multi-profile conflict**: Only one gateway can hold the Telegram connection

### Real Deliveries Received (Both Failed)
| Timestamp (UTC) | Event | Result |
|-----------------|-------|--------|
| 2026-06-11 01:50:24 | meeting.transcribed/summarized | HMAC Invalid signature |
| 2026-06-11 04:53:19 | meeting.transcribed/summarized | HMAC Invalid signature |

### Gateway Logs Evidence
```
2026-06-11 01:35:26,817 INFO Reloaded 1 dynamic route(s): fireflies
2026-06-11 01:50:24,160 WARNING Invalid signature for route fireflies
2026-06-11 04:53:19,317 WARNING Invalid signature for route fireflies
```

## Root Cause Analysis

### 1. HMAC Signature Mismatch
**Cause**: Fireflies dashboard webhook secret ≠ `[REDACTED]`
**Fix**: Update Fireflies dashboard → Settings → Webhooks → set secret to `[REDACTED]`

### 2. Missing FIREFLIES_API_KEY
**Cause**: Not in `/opt/data/.env`
**Effect**: Even if webhook validated, GraphQL transcript fetch would fail
**Fix**: Add `FIREFLIES_API_KEY=***` to `/opt/data/.env`, restart gateway

### 3. No Processing Skill Attached
**Cause**: Subscription `skills: []`
**Effect**: Agent runs but has no guidance to save transcript/extract decisions
**Fix**: Update subscription with `--skills "fireflies-processing"`

### 4. Telegram Token Conflict
**Cause**: health-coach gateway holds bot token; default gateway cannot deliver
**Evidence**: `Platform telegram not connected — trying plain-text fallback`
**Fix**: Stop conflicting gateway: `s6-svc -d /run/s6/services/gateway-health-coach`

### 5. Cron Job Anti-Pattern
**Problem**: Cron polls `/webhooks/fireflies` expecting to "find deliveries"
**Reality**: Webhook adapter receives POST in real-time; cron cannot "check" it
**Correct Use**: Only query Fireflies GraphQL API directly for catch-up after gateway downtime
**Action**: Disable/delete this cron job once webhook flow works

## Files Examined
- `/opt/data/webhook_subscriptions.json` — subscription config
- `/opt/data/logs/gateway.log` — delivery evidence
- `/opt/data/cron/jobs.json` — cron job definition
- `/opt/data/.env` — missing FIREFLIES_API_KEY
- `/opt/data/data/gateway_state.json` — shows webhook not active
- `ps aux | grep gateway` — three gateways running, health-coach owns Telegram

## Latest Cron Run (2026-06-11 ~06:49 UTC)
- Cron job ID: `1846d27d84d3` completed **45 runs** (every 5 minutes since 2026-06-10 20:02)
- **Zero new processable deliveries** found this run
- Two real Fireflies deliveries total (01:50:24, 04:53:19), both failed HMAC
- Test webhook at 06:28:49 succeeded (202 response)
- Output saved to `/opt/data/cron/output/1846d27d84d3/2026-06-11_06-49-07.md`

## Session Notes (2026-06-11 06:49 cron run)
See `references/cron-run-2026-06-11-session.md` for detailed session state, missed meeting IDs, and recovery steps.

## Recommended Next Steps
1. Add FIREFLIES_API_KEY to `/opt/data/.env` and restart default gateway
2. Update Fireflies dashboard webhook secret to match `[REDACTED]`
3. Update subscription: attach `fireflies-processing` skill
4. Stop health-coach gateway to free Telegram token
5. **Disable cron job `fireflies-webhook-handler`** (anti-pattern — webhooks are push-based)
   ```bash
   /opt/hermes/bin/hermes cron edit 1846d27d84d3 --enabled false
   # Or remove entirely once webhook flow verified working
   ```

## Verification Script
Added `scripts/verify-fireflies-setup.sh` — run to check all prerequisites:
```bash
/opt/data/skills/devops/fireflies-processing/scripts/verify-fireflies-setup.sh
```