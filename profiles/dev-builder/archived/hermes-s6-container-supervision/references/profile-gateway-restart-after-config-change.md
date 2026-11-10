# Restarting a supervised profile gateway after config/auth changes

Use this when a Hermes profile gateway runs under s6 inside the container and you changed profile-level config such as:
- `model.provider`
- `model.default`
- auth credentials / OAuth state
- gateway-facing settings that are only read at process start

## Symptom pattern

- The profile gateway is still online on Telegram/Discord/etc.
- A direct profile-scoped test like `hermes --profile <name> chat -q ...` succeeds after the fix.
- But the live gateway is still using the old provider/model or still failing with the pre-fix auth error.
- Running `hermes gateway restart` from *inside that same gateway conversation* is blocked with a restart-loop guard.

## Reliable recovery sequence

1. **Fix the profile config/auth first.**
2. **Reproduce with the exact profile outside the gateway:**
   ```sh
   HOME=/opt/data /opt/hermes/.venv/bin/hermes --profile <name> chat -q 'Reply with exactly: ok' --quiet
   ```
3. **Restart the supervised gateway from outside the process:**
   - preferred in-container form:
     ```sh
     docker exec <c> /command/s6-svc -t /run/service/gateway-<name>
     ```
   - or signal the running PID and let `s6-supervise` respawn it:
     ```sh
     kill -TERM <gateway_pid>
     ```
4. **Verify revival:** inspect `<profile>/gateway_state.json` until:
   - `gateway_state` becomes `running`
   - the target platform state becomes `connected`
5. **Only then** test from Telegram/other gateway channel.

## Notes

- `kill -TERM` is safe here because the supervision parent revives the process automatically.
- A blocked `hermes gateway restart` from inside the gateway is not a dead end; it is a guardrail against self-restart loops.
- Ignore unrelated adapter noise unless it blocks the target platform. For example, a sidecar `api_server` port conflict may still leave Telegram fully healthy.
