# Client integration patterns

## Hermes

Use a custom provider with a protected environment reference:

```yaml
model:
  default: "coding-primary"
  provider: "custom"
  base_url: "http://router.internal:20128/v1"
  api_key: ${INFERENCE_GATEWAY_KEY}

delegation:
  model: "coding-worker"
  provider: "custom"
  base_url: "http://router.internal:20128/v1"
  api_key: ${INFERENCE_GATEWAY_KEY}
```

Put `INFERENCE_GATEWAY_KEY` in that profile's protected `.env`. Assign auxiliary roles by capability instead of sending every task to the expensive main route. Test the main model, delegation, one auxiliary task, a real messaging turn, and one scheduled run before migrating another profile.

A gateway changes only configured inference calls. Hermes tools, MCP, browser, shell, messaging, and scheduler control remain Hermes responsibilities.

## OpenClaw

Back up the active config derived from live mounts. Add a custom provider with:

- gateway `/v1` base URL;
- a client-specific API key;
- the API mode required by the installed OpenClaw version;
- explicit model allowlists;
- one non-critical agent pointed at `gateway/<route>` first.

Run the native config validator, restart the gateway process, verify HTTP/RPC health, and perform a real channel request. A successful JSON write does not prove the active mounted config changed.

## Claude-compatible CLI

Prefer a dedicated config home or wrapper that sets the gateway base URL and auth token. Keep a direct wrapper beside it:

```text
claude-direct
claude-gateway
```

Run a streaming tool-use task through both before changing the default command.

## Codex/OpenAI-compatible CLI

Use a named custom provider with:

- `/v1` base URL;
- the wire API expected by the client (`responses` or chat completions);
- a static Authorization header or supported API-key setting;
- explicit main and subagent models.

Do not assume an environment variable overrides an active provider in a persisted TOML/JSON config; inspect the effective provider after applying changes.

## Herdr-like terminal orchestrators

The terminal orchestrator itself normally makes no model call. Configure each launched agent:

- Claude/Codex through shared wrappers and dedicated config homes;
- Hermes through its own profile;
- other agents through their native custom-provider config.

When the workbox mounts a shared tools root, add parallel gateway wrappers there first. Do not force all agents onto one shared HOME.

## Deployment security defaults

- Persistent database on a snapshotted dataset.
- Gateway API-key requirement enabled.
- One key per client/profile.
- Full request/response logs disabled.
- Dashboard behind HTTPS and identity-aware access.
- Inference endpoint limited to LAN/VPN unless the client supports proxy service-token headers.
- Cloud synchronization disabled until its trust and data-handling model has been reviewed.
- Tested container image pinned by digest after the pilot.

## Verification ladder

1. Health endpoint.
2. Authenticated model list.
3. Minimal non-streaming completion.
4. Streaming completion.
5. Tool/function-call round trip.
6. Long-context coding request.
7. Forced upstream unavailability proving fallback.
8. Client-native validation and real end-to-end request.
9. Gateway outage proving direct rollback.
10. Database snapshot/restore verification.

Do not migrate every client after only steps 1–3. Translation failures commonly appear only in streaming, tools, thinking blocks, media, or client-specific wire formats.
