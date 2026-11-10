# Authentication runtime boundaries

Use this reference when an auth error appears during a mixed Hermes + Archon deployment.

## First classify the runtime

| Signal | Runtime to inspect |
|---|---|
| `@archon/server`, codebase clone, workflow node, Archon Web UI | Archon container |
| Named Hermes profile/bot, Telegram reply, `gateway.log`, `agent.log` | Hermes profile/gateway |

Never infer the runtime solely from generic text such as `Provider authentication failed`.

## Archon checks

1. Inspect Archon container logs and environment.
2. Separate GitHub clone auth from AI-provider auth.
3. GitHub clone `403` from `github.com` is remote token/repository authorization; dataset failures instead mention local permission, mkdir, or read-only filesystem.
4. Confirm Compose actually imports the Archon `.env` via `env_file:` and recreate the container after changes.
5. For shared `gh`, mount `ai-tools`, set `GH_CONFIG_DIR`, verify `gh auth status`, then test `git ls-remote` or a shallow clone with the same token.

## Hermes profile checks

1. Inspect `<profile>/logs/gateway.log`, `<profile>/logs/agent.log`, and `hermes --profile <name> auth list`.
2. A provider may appear logged in while its credential-pool entry is temporarily `exhausted`; inspect status rather than relying on the summary alone.
3. Prove a candidate credential in the source profile with `hermes --profile <source> chat -q 'Reply with exactly: ok'`.
4. Back up the target profile's `auth.json`, synchronize only the relevant provider credential, clear stale error/exhaustion state, and run the same target-profile smoke test.
5. Restart the target gateway only after the CLI smoke test succeeds. Under approval-gated supervision, do not bypass a blocked restart; ask the user to run `/restart` in that bot/profile.

## Communication rule

Keep Archon-container remediation and Hermes-profile remediation explicitly separated in the response. If the user corrects which product emitted the error, stop the current diagnosis, reclassify the runtime, and inspect the proper source before giving another fix.
