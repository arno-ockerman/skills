# Profile gateway provider-auth recovery

Use this when a profile gateway replies with:

```text
⚠️ Provider authentication failed. Check the configured credentials; raw provider details are in the gateway logs.
```

## Signal

A direct CLI smoke test for the same profile can reveal the real provider error, e.g. OpenAI Codex returning:

```text
Error code: 401 ... token_expired
```

The gateway message is intentionally generic; the provider-specific detail lives in profile logs or in a CLI smoke test.

## Recovery pattern

1. Identify the affected profile and check its live config/status:
   ```sh
   HOME=/opt/data hermes --profile <profile> status --all
   ```
2. Run a direct provider smoke test outside the gateway:
   ```sh
   HOME=/opt/data hermes --profile <profile> chat -q 'Reply with exactly: ok' --quiet
   ```
3. If the smoke test fails with expired OAuth credentials, prefer re-authentication:
   ```sh
   HOME=/opt/data hermes --profile <profile> auth add openai-codex
   ```
   If a sibling profile already has known-good credentials and the user accepts credential sharing, copy only the relevant `credential_pool.<provider>` entry, preserve a backup, and remove stale legacy provider entries that may take precedence.
4. Re-run the direct smoke test before touching the gateway. Continue only when it returns the expected model response.
5. Restart the supervised gateway from outside that gateway process so it loads the updated auth file:
   ```sh
   /command/s6-svc -t /run/service/gateway-<profile>
   # If -t does not restart because of the current supervision state, signal the tracked PID and let s6 revive it:
   kill -TERM <gateway_pid>
   ```
6. Verify the new PID and platform reconnect in `gateway.log`:
   ```sh
   HOME=/opt/data hermes --profile <profile> gateway status
   ```

## Pitfalls

- `hermes gateway restart` may refuse when invoked from inside the gateway process to prevent restart loops. Use an external shell or the s6 service controls instead.
- In this container, s6 binaries may not be on PATH for arbitrary terminal sessions. Use absolute paths such as `/command/s6-svstat` and `/command/s6-svc`.
- Do not treat missing unrelated provider keys as the cause. If the profile provider is `OpenAI Codex`, `OpenAI` API key or Nous Portal login can be absent without blocking the configured model.
- Avoid persisting “tool/provider is broken” as a lesson. The durable lesson is the CLI smoke-test → auth repair → gateway restart verification loop.
