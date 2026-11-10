# Shared skills for the ai-tools CLIs, and Codex usage limits

Covers the shared `/opt/ai-tools` runtime (Claude Code, Codex, Herdr workbox, Archon) — where per-CLI skills live, how to install one for several CLIs at once, and how to read or reset Codex usage limits.

## Where each CLI reads skills

The wrappers override `HOME` before exec, so skills live in the **shared tool homes**, not in the caller's profile:

| CLI | Skill root | Verified by |
|---|---|---|
| Claude Code | `/opt/ai-tools/config/claude/home/.claude/skills/<name>/SKILL.md` | `claude -p "list your skills"` names them |
| Codex | `/opt/ai-tools/config/codex/home/.codex/skills/<name>/SKILL.md` | `codex debug prompt-input "x"` contains them |

Both wrappers (`/opt/ai-tools/bin/claude`, `/opt/ai-tools/bin/codex`) `source /opt/ai-tools/config/shared/env.sh` and then `export HOME="$CLAUDE_HOME_DIR"` / `"$CODEX_HOME_DIR"`. Anything that runs those wrappers — this Hermes profile, the Herdr workbox container (mounts `ai-tools` at the same `/opt/ai-tools`), Archon — sees the same skill set without extra mounts.

Codex's own preinstalled skills live in `skills/.system/`; leave them alone.

## Installing one skill for all CLIs

```bash
for root in /opt/ai-tools/config/claude/home/.claude/skills \
            /opt/ai-tools/config/codex/home/.codex/skills; do
  mkdir -p "$root/<name>" && cp /path/to/SKILL.md "$root/<name>/SKILL.md"
done
```

Claude Code also accepts `--plugin-dir` and a plugin marketplace, and Codex has a bundled `skill-installer` skill (`$CODEX_HOME/skills/.system/skill-installer`) that pulls from `openai/skills` or any GitHub repo path — both are alternatives to plain copying, and both make the set read-only/managed.

Description length costs differently per host, and the difference is large:

- **Hermes** truncates each description to 57 chars + `...` in its skills index, so a long description is free there.
- **Codex does not truncate.** Its `<skills_instructions>` block carries every skill's full description. Measured on a 12-skill install: the block was 4.615 chars ≈ 1.153 tokens, of which 2.025 chars were five local skills — `plan-architecture` alone 800 chars. Two of those five accounted for ~1.4 k chars purely through long descriptions.

So the same skill can cost nothing extra for Hermes and hundreds of tokens for Codex. When a description must be written for both, spend the detail where it earns its keep (the trigger phrase and the 'when to use' clause) and cut the rationale prose; the skill body is loaded only when the skill fires, so it can stay as long as it needs.

Do not shorten a description so far that the skill stops firing — the trigger words are the point. Verify the trade-off by re-running `codex debug prompt-input` and reading the measured block size.

## Verifying discovery without spending tokens

- **Codex, no model call:** `codex debug prompt-input "ping"` renders the exact prompt input list as JSON (5 items; item 0 holds `<skills_instructions>`). Grep it for the skill names. This is the cheapest possible proof and works while rate-limited.
- **Claude Code, live:** `claude -p "List the exact names of every skill available to you..."`. A bare print-mode run needs a trusted cwd and working auth; `--bare` skips hooks/LSP but still failed with "Not logged in" in this environment, so omit it.

## Codex usage limits and reset credits

There is **no `codex reset` subcommand**. The supported surface is the app-server JSON-RPC protocol (what the TUI's reset-credit menu calls):

- `account/rateLimits/read` — current windows, both `ordinaryUsageAllowed` and the reset-credit list
- `account/rateLimitResetCredit/consume` — params `{idempotencyKey: <uuid>, creditId?: string}`; omitting `creditId` redeems the next available credit
- `account/read`, `account/usage/read`, `account/workspaceMessages/read`

Protocol details and a working client: `tools/scripts/codex-ratelimit.py` in this profile (read-only by default; add `--consume` to redeem one credit). Regenerate the full protocol with `codex app-server generate-json-schema --out <dir>` when the CLI updates — method and param names drift between versions.

Handshake: send `initialize` with `{clientInfo: {name, title, version}}`, then the `initialized` notification, then the method calls; responses arrive as JSON lines on stdout.

The response shape that matters:

- `rateLimits.primary` = rolling 5-hour window, `secondary` = weekly window, each with `usedPercent` and `resetsAt` (unix seconds)
- `rateLimits.credits` is account balance (a different thing from reset credits)
- `rateLimitResetCredits` (top level) = `{availableCount, credits: [{id, resetType, status, grantedAt, expiresAt, title}]}` — the granted free resets
- `rateLimitsByLimitId.base_model_inference` (`limitName: gpt-reserve`) is the automatic fallback tier Codex uses once ordinary usage is blocked

Always read before consuming and report the trade-off to the user: a credit grants a **full reset (weekly + 5-hour window)**, so redeeming one to clear a small window that expires in hours also wipes accumulated weekly usage. Credits expire (roughly 30 days after grant), so an unused credit is not free forever — quote the exact expiry dates when asking. Consuming is irreversible: never do it on your own initiative, and never retry after an ambiguous failure.

A `429`/usage-limit error is a state, not a defect: check `ordinaryUsageAllowed` and `resetsAt` first, and tell the user when the block lifts naturally before offering the credit route.
