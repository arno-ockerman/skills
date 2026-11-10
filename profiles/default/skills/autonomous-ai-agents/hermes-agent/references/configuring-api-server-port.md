# Configuring the Hermes API Server Port

## Overview
The API server port is configured at `platforms.api_server.extra.port` in `config.yaml`. This port is used by the Hermes gateway's built-in API server (for Open WebUI, custom clients, etc.).

## Config Location
| Profile | Config Path |
|---------|-------------|
| Default (main) | `~/.hermes/config.yaml` |
| Named profile | `~/.hermes/profiles/<name>/config.yaml` |

## Changing the Port
Use the CLI (direct file edit is blocked for security):

```bash
# Main profile
hermes config set platforms.api_server.extra.port 30434

# Named profile
hermes config set platforms.api_server.extra.port 30434 --profile dev-builder
hermes config set platforms.api_server.extra.port 30434 --profile health-coach
```

## Port Conflicts
**Common error:** `[Api_Server] Port 30432 already in use. Set a different port in config.yaml: platforms.api_server.port`

**Causes:**
1. Another Hermes instance/gateway running on the same port
2. Stale process holding the port (especially under s6 supervision)
3. Dashboard and API server configured to same port

**Resolution:**
- Pick a free port (e.g. 30434, 30435)
- Update ALL profiles that run gateways
- Restart affected gateways

## Restarting After Config Change

### Gateway Processes (User-level, can kill)
```bash
# Find gateway PIDs
ps aux | grep 'hermes.*gateway run' | grep -v grep

# Kill them — s6 will respawn with new config
kill <PID1> <PID2> ...
```

### Main s6 Service (Root-level, needs root)
The main Hermes wrapper (`main-hermes`) runs under s6 as **root**. User cannot kill/restart it directly.

```bash
# This FAILS without root:
s6-svc -t /run/s6-rc:.../servicedirs/main-hermes

# Options:
# 1. Container/host restart (full reset)
# 2. Ask admin with root to run s6-svc
# 3. Wait for watchdog/auto-recovery
```

### Dashboard (Separate Process)
```bash
# Dashboard runs on its own port (default 30433)
ps aux | grep 'hermes dashboard'
kill <dashboard_pid>  # Restarts via s6
```

## Multi-Profile Considerations
Each profile with `gateway run` starts its own API server on the configured port. If multiple profiles run simultaneously, **each needs a unique port** or they'll conflict.

```yaml
# profile A config.yaml
platforms:
  api_server:
    extra:
      port: 30434

# profile B config.yaml  
platforms:
  api_server:
    extra:
      port: 30435
```

## Verification
```bash
# Check config took effect
hermes config show | grep -A 5 'api_server'

# Check port is listening (after gateway restart)
lsof -i :30434
# or
ss -tlnp | grep 30434
```

## Related Settings
| Setting | Path | Purpose |
|---------|------|---------|
| API server host | `platforms.api_server.extra.host` | Bind address (default `0.0.0.0`) |
| API server enabled | `platforms.api_server.enabled` | Toggle on/off |
| Webhook port | `platforms.webhook.extra.port` | Separate webhook receiver port |
| Dashboard port | CLI flag `--port` or dashboard wrapper | Web UI port (separate from API) |