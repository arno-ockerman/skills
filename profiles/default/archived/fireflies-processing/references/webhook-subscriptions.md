# Webhook Subscriptions — Reference

**Source:** `devops/webhook-subscriptions/SKILL.md`

For webhook platform setup, subscription management, troubleshooting, and multi-profile gateway issues, see the main webhook-subscriptions skill:

> **`devops/webhook-subscriptions`**

## Key Fireflies-Specific Points

- **Webhook endpoint**: `/webhooks/fireflies` on port 8644 (default profile gateway)
- **HMAC secret**: `[REDACTED]` (must match Fireflies dashboard exactly)
- **Fireflies events**: `meeting.transcribed`, `meeting.summarized` (V2 format)
- **Required env var**: `FIREFLIES_API_KEY` in `/opt/data/.env`
- **Multi-profile gotcha**: Only one gateway can hold Telegram bot token. Stop conflicting profile: `s6-svc -d /run/s6/services/gateway-health-coach`
- **Anti-pattern**: Do NOT create cron jobs to "check for webhook deliveries" — webhooks are push-based

## Related References in webhook-subscriptions

- `references/fireflies-webhook.md` — Payload formats, API integration
- `references/fireflies-local-save.md` — Complete workflow & current state
- `references/fireflies-processing-skill-template.md` — This skill's template origin
- `references/s6-multi-profile-gateway.md` — Multi-profile troubleshooting