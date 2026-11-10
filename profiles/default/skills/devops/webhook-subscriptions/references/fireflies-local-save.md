# Fireflies Webhook → Local Markdown Save Workflow

**Session context:** Cron job for processing Fireflies webhook deliveries and saving as markdown (2026-06-11)

## Current Architecture (As-Is) — Verified 2026-06-11

```
Fireflies V2 webhook (meeting.transcribed / meeting.summarized)
         │
         ▼
Hermes Gateway (port 8644) /webhooks/fireflies  [DEFAULT PROFILE]
         │  • Validates HMAC signature (sha256=...)
         │  • Hot-reloads /opt/data/webhook_subscriptions.json
         │  • Renders prompt template with payload fields
         ▼
Agent run (prompt includes meeting_id, event, timestamp)
         │
         ├──► If FIREFLIES_API_KEY set: calls GraphQL API → delivers summary to Telegram
         └──► If FIREFLIES_API_KEY missing: agent fails → error to Telegram
         │
         ▼ (MISSING: Local file save handler)
```

**Gateway Status (2026-06-11):**
- Three gateway instances running under s6: `gateway-default` (PID 3533), `gateway-dev-builder` (PID 3531), `gateway-health-coach` (PID 3529)
- Default profile gateway receiving webhooks on port 8644
- Telegram delivery failing: "Telegram bot token already in use" — another gateway holds the connection
- `gateway_state.json` only reflects one stopped instance (s6 state not fully synced)

## Actual Webhook Subscription (from `/opt/data/webhook_subscriptions.json`)

```json
{
  "fireflies": {
    "description": "Agent-created subscription: fireflies",
    "events": [],                    // accepts all events
    "secret": "[REDACTED]",
    "prompt": "Fireflies meeting event: {event}. Meeting ID: {meeting_id}. Timestamp: {timestamp}. Client Reference ID: {client_reference_id}. Please fetch the full transcript and summary from Fireflies API and save as markdown.",
    "skills": [],
    "deliver": "telegram",
    "deliver_extra": { "chat_id": "EXAMPLE_CHAT_ID" }
  }
}
```

## Real-World Delivery Log (2026-06-11)

| Time (UTC) | Event | Result |
|------------|-------|--------|
| 01:39:08 | Test: `meeting.transcribed` (meeting_id: `ASxwZxCstx`) | ✅ 202 Accepted, agent triggered |
| 01:47:40 | Test: template payload | ✅ 202 Accepted, agent triggered |
| **01:50:24** | **Real Fireflies delivery** | ❌ **401 Invalid signature** |
| 04:08:12 | Test: template payload | ✅ 202 Accepted, agent triggered |
| **04:53:19** | **Real Fireflies delivery** | ❌ **401 Invalid signature** |
| **06:28:49** | Test: manual test via CLI | ✅ 202 Accepted, agent triggered |

**Key finding:** Two real Fireflies deliveries (01:50:24 and 04:53:19) failed HMAC validation — the Fireflies dashboard webhook secret does not match the subscription secret (`[REDACTED]`). The 04:53:19 failure confirms this is a persistent configuration mismatch, not a one-off.

**Cron job runs (2026-06-11 03:41–06:30 UTC):** 41 executions every 5 minutes (ID: `1846d27d84d3`, schedule `*/5 * * * *`). All runs after 01:50:24 returned no new processable deliveries (the 04:53:19 delivery also failed HMAC). The cron job is fundamentally misaligned with push-based webhooks and should be removed/repurposed.

## Blocker: Missing `FIREFLIES_API_KEY`

**No Fireflies API key is configured** in any `.env` file:
- `/opt/data/.env` ❌
- `/opt/data/data/.env` ❌
- `/opt/data/profiles/dev-builder/.env` ❌
- `/opt/data/profiles/health-coach/.env` ❌

Without this, the agent **cannot fetch transcripts/summaries** from the Fireflies GraphQL API when webhooks arrive.

## Directory Structure Ready ✅

```\n/opt/ai-context/ProductivityCenter/\n├── Meetings/          # Empty — YYYY-MM-DD - Topic.md files go here\n├── decisions/log.md   # Header template exists\n└── Projects/          # AI tools/, club-app/, hermes/, openclaw/ — action items go here\n```

## Cron Job Output Directory (Observed 2026-06-11)

The `fireflies-webhook-handler` cron job (ID: `1846d27d84d3`, schedule `*/5 * * * *`) writes run outputs to:

```
/opt/data/cron/output/1846d27d84d3/
```

Each run produces a markdown file: `YYYY-MM-DD_HH-MM-SS.md` containing the prompt, agent response, and analysis.

**Sample output (2026-06-11_03-13-18.md):** Detailed investigation of webhook endpoint status, HMAC failure, missing API key, and multi-profile gateway conflicts.

**Note:** All runs after the failed HMAC delivery at 01:50:24 returned `[SILENT]` because no new processable webhook deliveries occurred. Webhooks are push-based — this cron job is unnecessary and should be removed or repurposed to query Fireflies API directly only if a webhook was missed during gateway downtime.

## Required Action

Add your Fireflies API key to `/opt/data/.env`:
```bash
echo "FIREFLIES_API_KEY=your_key_here" >> /opt/data/.env
```
Then restart the gateway to pick up the new env var:
```bash
s6-svc -r /run/s6/services/gateway-default
```

## Fireflies GraphQL API Query (Working Template)

```bash
curl -X POST https://api.fireflies.ai/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{
    "query": "query Transcript($transcriptId: String!) { transcript(id: $transcriptId) { id title date duration organizer_email participants sentiment summary { action_items overview bullet_gist shorthand_bullet short_summary topics_discussed } sentences { index speaker_name text start_time end_time } } }",
    "variables": { "transcriptId": "MEETING_ID_FROM_WEBHOOK" }
  }'
```

## Markdown Output Format

```markdown
# YYYY-MM-DD - Topic (from meeting.title)

**Meeting ID:** ASxwZxCstx
**Date:** 2026-06-11
**Duration:** 45 min
**Organizer:** user@example.com
**Participants:** ["user1@example.com", "user2@example.com"]
**Fireflies URL:** https://app.fireflies.ai/view/ASxwZxCstx

## Summary

### Overview
{summary.overview}

### Action Items
- [ ] {action_item_1} (assignee: ...)
- [ ] {action_item_2} (assignee: ...)

### Key Points
- {bullet_gist_1}
- {bullet_gist_2}

### Topics Discussed
- {topic_1}
- {topic_2}

## Full Transcript

| Time | Speaker | Text |
|------|---------|------|
| 00:00 | John | Hello everyone... |
| 00:15 | Jane | Hi John...
```

## Decisions Log Format (append to decisions/log.md)

```markdown
## YYYY-MM-DD — Short title (from meeting topic or key decision)

**Decision:** what was decided.

**Why:** the reasoning, constraints, and what would change your mind.

**Alternatives considered:** what else was on the table.

**Owner:** who's accountable.
```

## Implementation Options

### Option 1: Modify webhook subscription prompt + add skill
- Update fireflies subscription prompt to include extraction instructions
- Add a skill that knows how to write to the specific markdown paths
- Agent runs, fetches transcript, writes files via terminal tool

### Option 2: Custom webhook handler (server-side)
- Write a small Python/Node service that receives webhook, fetches transcript, writes files
- Bypasses LLM entirely for the save operation
- More reliable, zero LLM cost

### Option 3: Hermes skill with terminal access (RECOMMENDED)
- Add a skill that provides `fireflies_save_transcript(meeting_id)` function
- Webhook subscription calls this skill
- Skill handles GraphQL call + file writes

## Next Steps

1. **Remove or repurpose the cron job** — The `fireflies-webhook-handler` cron (ID: `1846d27d84d3`, `*/5 * * * *`) is **fundamentally misguided**. Webhooks are push-based; the webhook adapter already receives events in real-time. Delete this cron job or repurpose it to only query Fireflies API directly for recent transcripts if a webhook was missed during gateway downtime.

2. Add `FIREFLIES_API_KEY` to `/opt/data/.env`

3. Fix HMAC mismatch in Fireflies dashboard — Verify webhook URL is exactly `https://your-domain/webhooks/fireflies` and secret matches `[REDACTED]`

4. Resolve Telegram token conflict — Only ONE gateway can hold the Telegram bot connection. Stop the conflicting instance (`gateway-health-coach` holds it per 2026-06-11 investigation) via `s6-svc -d /run/s6/services/gateway-health-coach`

5. Choose implementation option (Option 3 recommended — cleanest within Hermes)

6. Create/update fireflies skill with `save_transcript` function

7. Update webhook subscription to use the skill (`--skills "fireflies"`)

8. Test with `hermes webhook test fireflies --payload '{"event":"meeting.summarized","meeting_id":"TEST"}'`

## Verification Script

A verification script is available at `devops/fireflies-processing/scripts/verify-fireflies-setup.sh` — checks all prerequisites: API key, webhook subscription config, gateway processes, Telegram conflicts, webhook endpoint health, cron job status, directory structure.