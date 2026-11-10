# Telegram Bot Token Conflict — Reproduction & Resolution

## Error Message
```
[Telegram] Telegram bot token already in use. Stop the other gateway first.
```

## Root Cause
Multiple profile gateways (`default`, `dev-builder`, `health-coach`) supervised by s6 all run simultaneously and connect to Telegram using the **same bot token** from the main `config.yaml`. Telegram allows only one WebSocket connection per bot token.

## Session Transcript (2026-06-12)

**Initial state** — 3 gateways running:
```
PID 194  → gateway-default      (default profile)
PID 851  → gateway-dev-builder  (-p dev-builder)
PID 849  → gateway-health-coach (-p health-coach)
```

**What didn't work**: `kill -9 <PID>` — s6-supervise immediately respawned them.

**What worked**:
```sh
# First: signal "want down" (graceful)
/command/s6-svc -d /run/service/gateway-dev-builder /run/service/gateway-health-coach

# Then: force-kill if still up (sends SIGKILL)
/command/s6-svc -k /run/service/gateway-dev-builder /run/service/gateway-health-coach
```

**Verification**:
```sh
/command/s6-svstat /run/service/gateway-dev-builder
# → "down (signal SIGKILL) 13 seconds, normally up, ready 13 seconds"
```

## Key Learning
- **Don't** kill gateway processes directly with `kill` — s6 restarts them
- **Do** use `/command/s6-svc -d` (want down) then `/command/s6-svc -k` (force kill) on the **s6 service directory** under `/run/service/gateway-<name>/`
- The `/command/` prefix is required — s6 binaries are not on PATH for `docker exec`

## Prevention
1. Only run one gateway at a time per Telegram bot token
2. For parallel profiles: create separate Telegram bots (@BotFather), configure per-profile tokens
3. Use `hermes gateway stop` to persist "stopped" state so boot reconciler doesn't auto-start