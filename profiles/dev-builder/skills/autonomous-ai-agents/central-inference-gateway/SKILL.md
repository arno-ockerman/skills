---
name: central-inference-gateway
description: "Use when several AI runtimes share one inference gateway."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [inference-gateway, llm-router, hermes, openclaw, herdr, multi-agent, security]
---

# Central Inference Gateway

## When to Use

Use this skill when Hermes, OpenClaw, coding CLIs, terminal-managed agents, or other runtimes should share provider credentials, model selection, quota handling, usage accounting, or fallback through one OpenAI/Anthropic-compatible endpoint.

## Boundary first

Keep these responsibilities separate:

- **Agent/orchestrator:** tools, permissions, memory, cron, subagents, workflows, and messaging.
- **Inference gateway:** model/media requests, protocol translation, provider credentials, account/model fallback, and usage tracking.
- **Terminal orchestrator:** starts agents in panes or remote machines; it normally emits no model traffic itself.

Never claim that routing the LLM endpoint also routes browser, shell, GitHub, Home Assistant, MCP, Telegram, or cron traffic. Configure each inference-producing client explicitly.

## Procedure

1. **Inventory clients and trust boundaries**
   - List every runtime that makes model calls and every terminal orchestrator that merely launches one.
   - Derive active config paths from live mounts/processes; stale Compose notes are not proof.
   - Record current direct provider paths as rollback targets.

2. **Deploy the gateway as a separate service**
   - Give it persistent state, a stable internal address, a healthcheck, and snapshots.
   - Inject dashboard/session, API-key-signing, and machine-identity secrets through the service manager or a mode-600 env file; never commit them.
   - Require API keys. Keep full request/response logging off by default because prompts and tool output can contain secrets.
   - Treat the database as a credential vault when it stores provider keys or OAuth refresh tokens.

3. **Separate dashboard and inference access**
   - Put the dashboard behind HTTPS and identity-aware access.
   - Keep inference on LAN/VPN when clients cannot attach reverse-proxy service-token headers.
   - Inside containers, never use `localhost` for a gateway in another container; use a shared-network service name or stable host address.

4. **Create keys and routes**
   - Create one API key per client/profile/workbox for attribution and isolated revocation.
   - Query the live model catalog before writing model IDs; provider catalogs and entitlements change.
   - Build capability routes rather than one universal route: strong coding, cheaper worker/review, fast utility, and modality-specific routes.
   - Restrict fallback to quota, rate-limit, or upstream availability failures. Do not mask authentication, malformed-request, code, or tool errors by switching providers.

5. **Integrate without cross-mounting homes**
   - Configure Hermes/OpenClaw/CLI files manually when they run in separate containers or use nonstandard profile roots.
   - Do not mount agent profile homes into the gateway merely so its dashboard can edit them; this broadens secret exposure and couples unrelated lifecycles.
   - For terminal orchestrators, configure the agents they launch through dedicated wrappers or config homes; the terminal orchestrator itself usually needs no provider config.

6. **Roll out one client at a time**
   - Gateway health and authenticated model list.
   - Minimal non-streaming and streaming requests.
   - Temporary agent/profile with tool calls and representative long context.
   - One non-critical OpenClaw agent.
   - Production Hermes profiles.
   - Terminal-launched agents.

7. **Preserve break glass**
   - Add gateway variants such as `claude-gateway` and `codex-gateway` before replacing direct wrappers.
   - Back up each native config before editing.
   - Keep direct wrappers/config backups usable and document the rollback command.

8. **Verify per client**
   - Run the client's native config validator, restart its supervised process, and perform a real end-to-end request.
   - Verify streaming, tool/function calls, long context, and forced fallback; a healthy gateway plus one `curl` completion is insufficient.
   - Verify an outage rollback and a database snapshot/restore path before declaring the migration complete.

## Client-specific depth

Read `references/client-integration-patterns.md` for configuration shapes, wrapper patterns, and the verification ladder for Hermes, OpenClaw, Claude/Codex CLIs, and Herdr-like terminal orchestrators.
