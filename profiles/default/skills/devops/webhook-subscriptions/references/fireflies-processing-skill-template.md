# Fireflies Transcript Processing Skill Template

**Purpose:** Reference implementation for a skill that processes Fireflies webhook payloads, fetches full transcripts via GraphQL API, and saves as structured markdown to the ProductivityCenter.

## Skill Requirements

A Fireflies processing skill should provide a function/tool that:
1. Accepts `meeting_id` from webhook payload
2. Calls Fireflies GraphQL API (requires `FIREFLIES_API_KEY` in environment)
3. Transforms response into markdown following the standard format
4. Writes meeting markdown to `/opt/ai-context/ProductivityCenter/Meetings/YYYY-MM-DD - Topic.md`
5. Extracts decisions → appends to `/opt/ai-context/ProductivityCenter/decisions/log.md`
6. Extracts action items → writes to relevant project folders under `/opt/ai-context/ProductivityCenter/Projects/`

## Prompt Template for Webhook Subscription

```bash
hermes webhook subscribe fireflies \
  --events "meeting.transcribed,meeting.summarized" \
  --prompt "Fireflies meeting event: {event}. Meeting ID: {meeting_id}. Timestamp: {timestamp}. Client Reference ID: {client_reference_id}. Use the fireflies-processing skill to fetch the full transcript from Fireflies API and save as markdown." \
  --skills "fireflies-processing" \
  --deliver telegram \
  --deliver-chat-id "EXAMPLE_CHAT_ID" \
  --secret "[REDACTED]"
```

## GraphQL Query Template

```graphql
query Transcript($transcriptId: String!) {
  transcript(id: $transcriptId) {
    id
    title
    date
    duration
    organizer_email
    participants
    sentiment
    summary {
      action_items
      overview
      bullet_gist
      shorthand_bullet
      short_summary
      topics_discussed
    }
    sentences {
      index
      speaker_name
      text
      start_time
      end_time
    }
  }
}
```

## Markdown Output Format (Target)

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

## Action Items Routing

Map action items to project folders based on keywords/context:
- `/opt/ai-context/ProductivityCenter/Projects/AI tools/`
- `/opt/ai-context/ProductivityCenter/Projects/club-app/`
- `/opt/ai-context/ProductivityCenter/Projects/hermes/`
- `/opt/ai-context/ProductivityCenter/Projects/openclaw/`

Each project folder can have an `action-items.md` file appended to.

## Implementation Notes

- **Agent-based approach (recommended):** Create a Hermes skill `fireflies-processing` with a tool/function `process_meeting(meeting_id: str)` that uses `terminal` to call curl + jq, then writes files.
- **Zero-LLM approach:** Write a standalone Python/Node script that the webhook handler calls directly (bypasses agent for save operation).
- **Hybrid:** Webhook subscription `deliver-only` to a script endpoint that does the fetch+save, then optionally triggers agent for summarization/analysis.

## Common Blockers

1. `FIREFLIES_API_KEY` not configured in any `.env` file → Add to `/opt/data/.env` and restart gateway
2. HMAC signature mismatch — Fireflies dashboard secret doesn't match Hermes subscription secret → Verify webhook URL path (`/webhooks/fireflies`) and secret in Fireflies dashboard
3. Telegram token conflict (multi-profile) — Only one gateway can hold the Telegram bot connection → Stop conflicting profile's gateway via s6: `s6-svc -d /run/s6/services/gateway-<profile>`
4. No `fireflies-processing` skill attached to subscription → Create the skill and update subscription with `--skills "fireflies-processing"`

## Testing

```bash
# Test webhook subscription with mock payload
hermes webhook test fireflies --payload '{"event":"meeting.summarized","meeting_id":"TEST_ID","timestamp":1710876789456,"client_reference_id":"test"}'

# Verify curl GraphQL call works
FIREFLIES_API_KEY=your_key curl -X POST https://api.fireflies.ai/graphql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $FIREFLIES_API_KEY" \
  -d '{"query": "...", "variables": {"transcriptId": "ASxwZxCstx"}}'
```

---

*This template is a reference for creating a `fireflies-processing` skill. Once created, attach it to the Fireflies webhook subscription via `hermes webhook subscribe fireflies --skills "fireflies-processing" ...`.*