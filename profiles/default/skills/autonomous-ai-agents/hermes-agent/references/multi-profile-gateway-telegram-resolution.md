# Multi-Profile Hermes Gateway — Telegram Token Conflict Resolution

**Session:** 2026-06-15  
**Problem:** Two Hermes gateways (default + dev-builder) running with the same `TELEGRAM_BOT_TOKEN` caused fatal error: `Telegram bot token already in use. Stop the other gateway first.`

## Root Cause

The default profile's gateway was started via s6 supervision with a token intended for the Hermes agent. The `dev-builder` profile was also configured with the same token. The `health-coach` profile had its own unique token.

Telegram allows only **one active long-polling connection per bot token**. Running multiple gateways with the same token causes immediate conflict.

## Resolution Steps

### 1. Identify Conflicting Gateways

```bash
# Check gateway state
cat /opt/data/gateway_state.json
cat /opt/data/profiles/dev-builder/gateway_state.json
cat /opt/data/profiles/health-coach/gateway_state.json

# Check running processes
ps aux | grep -E "hermes.*gateway" | grep -v grep
```

### 2. Set Unique Tokens Per Profile

```bash
# Hermes agent token → dev-builder profile
/opt/hermes/.venv/bin/hermes config set TELEGRAM_BOT_TOKEN "EXAMPLE_BOT_ID:***" --profile dev-builder

# Health coach token → health-coach profile  
/opt/hermes/.venv/bin/hermes config set TELEGRAM_BOT_TOKEN "EXAMPLE_BOT_ID:***" --profile health-coach

# Clear token from default profile (not used for bot personas)
/opt/hermes/.venv/bin/hermes config set TELEGRAM_BOT_TOKEN ""  # default profile
```

### 3. Stop Conflicting Gateway (Default Profile)

```bash
# Via s6 control file (no s6-svc binary needed)
echo d > /run/service/gateway-default/supervise/control

# Or kill the process directly
kill <PID_OF_DEFAULT_GATEWAY>
```

### 4. Start Profile Gateways Under s6 Supervision

```bash
# Start dev-builder gateway
echo u > /run/service/gateway-dev-builder/supervise/control

# Start health-coach gateway
echo u > /run/service/gateway-health-coach/supervise/control

# Verify
sleep 3
cat /opt/data/profiles/dev-builder/gateway_state.json
cat /opt/data/profiles/health-coach/gateway_state.json
```

### 5. Verify Telegram Connectivity

Both gateways should show:
```json
{
  "platforms": {
    "telegram": {"state": "connected", "error_code": null, "error_message": null},
    "api_server": {"state": "connected", "error_code": null, "error_message": null}
  }
}
```

## Key Lessons

1. **Never share `TELEGRAM_BOT_TOKEN` across profiles** — Each Telegram bot = one token = one gateway process.

2. **Default profile token should be cleared** when using profile-specific gateways with dedicated bots.

3. **s6 control files** (`/run/service/<service>/supervise/control`) work when `s6-svc` binary is unavailable:
   - `echo d` = down (stop)
   - `echo u` = up (start)
   - `echo t` = terminate (restart)

4. **Gateway state files** at `/opt/data/profiles/<profile>/gateway_state.json` are the source of truth for platform connection status.

5. **Profile `.env` files** at `/opt/data/profiles/<profile>/.env` hold the per-profile `TELEGRAM_BOT_TOKEN`.

## Prevention Checklist

- [ ] Each profile has unique `TELEGRAM_BOT_TOKEN` in its `.env`
- [ ] Default profile has `TELEGRAM_BOT_TOKEN=""` (empty)
- [ ] No gateway runs outside s6 supervision without explicit token assignment
- [ ] Telemetry: monitor `gateway_state.json` for `state: fatal` with `telegram-bot-token_lock` error

## Related Files

- `/opt/data/profiles/dev-builder/.env` — Dev builder bot token
- `/opt/data/profiles/health-coach/.env` — Health coach bot token
- `/opt/data/.env` — Default profile (token cleared)
- `/run/service/gateway-*/supervise/control` — s6 control files
- `hermes config set TELEGRAM_BOT_TOKEN <value> --profile <name>` — CLI for token management