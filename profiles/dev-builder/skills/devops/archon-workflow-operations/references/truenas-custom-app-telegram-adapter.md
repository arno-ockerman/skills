# Archon Telegram adapter on a TrueNAS Custom App

Use this when an existing Archon container is managed as a TrueNAS Custom App and Telegram must be enabled without hand-editing generated Compose files.

## Security and configuration

Required Archon environment variables:

```ini
TELEGRAM_BOT_TOKEN=<BotFather token>
TELEGRAM_ALLOWED_USER_IDS=<comma-separated numeric Telegram user IDs>
TELEGRAM_STREAMING_MODE=stream
```

Always set `TELEGRAM_ALLOWED_USER_IDS` for a private Archon instance. Without it, anyone who finds the bot can message it. Never print the token, dump the full container environment, or commit it to Git.

Validate a newly supplied token against Telegram `getMe`, but print only safe bot metadata such as ID, username, and display name.

## TrueNAS Custom App update pattern

1. Inspect the live deployment first. Confirm the container image, Compose project labels, mounts, runtime UID/GID, and `/api/health` response. A repository overlay or old Compose file on disk may not be the deployment TrueNAS is actually running.
2. Detect a TrueNAS Custom App through container labels and `midclt call app.get_instance <app>`. For a custom app, `midclt call app.config <app>` returns the active structured Compose configuration.
3. Treat `/mnt/.ix-apps/.../templates/rendered/docker-compose.yaml` as generated state. Do not edit it directly.
4. Parse the complete `app.config` object, mutate only `services.<service>.environment`, and submit the complete preserved object through `app.update` as `custom_compose_config`.
5. Use the TrueNAS job form `midclt call -j app.update <app> -` and pass the update JSON on stdin. The trailing `-` keeps secrets out of shell history and process arguments. Do not log the payload.
6. Wait for the update job to finish; it recreates the app container with the new environment.

Minimal mutation logic:

```python
compose = json.loads(run(["midclt", "call", "app.config", app]))
env = compose["services"][service].setdefault("environment", {})
env["TELEGRAM_BOT_TOKEN"] = token
env["TELEGRAM_ALLOWED_USER_IDS"] = allowed_user_ids
env["TELEGRAM_STREAMING_MODE"] = "stream"
update = {"custom_compose_config": compose}
# Serialize `update` and feed it on stdin to:
# midclt call -j app.update <app> -
```

Use a temporary script that reads the BotFather token from stdin, and remove the script afterward. Preserve every unrelated Compose key and environment variable.

## Verification ladder

1. `app.get_instance` reports `RUNNING`.
2. `docker ps` reports the Archon container as healthy after recreation.
3. Inspect only environment variable names and confirm the three `TELEGRAM_*` keys exist; never print values.
4. `/api/health` returns `status: ok` and `activePlatforms` contains both `Web` and `Telegram`.
5. Telegram `getWebhookInfo` should have no webhook URL when Archon uses Bot API polling and should report no polling error.
6. Ask the user to open the bot and press **Start** or send `/start`, then send a normal Archon request. Telegram bots cannot initiate a private chat before the user starts them, so a proactive `sendMessage` returning HTTP 400 is not proof that the adapter failed.

The final end-to-end acceptance check is an inbound user message handled by Archon and a bot response—not merely a successful direct Telegram API call.