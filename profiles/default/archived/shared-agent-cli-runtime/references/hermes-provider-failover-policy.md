# Hermes Provider Failover Policy

**A re-login fixes today; a failover chain fixes the next outage.** When a provider's
credential dies (see `oauth-credential-sharing-pitfalls.md`), the user-visible symptom is
a hard provider error — not a graceful downgrade. Hermes supports an automatic fallback
chain, but it must be configured in **two independent places**, and it is worth proving
that it fires rather than assuming it.

## The two places

`fallback_providers` (top level) applies to the **main chat model** only:

```yaml
fallback_providers:
  - provider: deepseek
    model: deepseek-v4-flash
```

`auxiliary.<task>.fallback_chain` is per auxiliary task (vision, compression,
title_generation, curator, review, mcp, skills_hub, triage_specifier, …):

```yaml
auxiliary:
  compression:
    provider: openai-codex        # explicitly pinned
    fallback_chain:
      - provider: deepseek
        model: deepseek-v4-flash
```

**Why both are needed.** For an aux task with provider `auto`, Hermes walks the main
`fallback_providers` chain. But for an aux task with an **explicitly pinned provider**, the
main chain is *not* consulted: the code path is
`_try_configured_fallback_chain(task, provider, reason)` →
`_try_main_agent_model_fallback()`. So a Codex-pinned aux task silently falls back to the
main agent model — not to the model the user asked for — unless the task carries its own
`fallback_chain`. On the main agent, an auth failure *does* activate `fallback_providers`
(`_try_activate_fallback`), which is why a single top-level chain is enough for the chat
model but not for the aux tasks.

## What actually triggers the aux ladder — auth is NOT enough

Declaring `auxiliary.<task>.fallback_chain` does **not** mean "anything that goes wrong on
this task falls through". The trigger is gated in `agent/auxiliary_client.py` (sync
`call_llm` ≈ line 10521, async ≈ line 11223):

```python
is_auto = resolved_provider in {"auto", "", None}
is_capacity_error = (
    _is_payment_error(first_err)        # 402
    or _is_connection_error(first_err)
    or _is_rate_limit_error(first_err)  # 429 after retries / daily quota
    or _is_model_incompatible_error(first_err)
    or _is_invalid_aux_response_error(first_err)
)
if should_fallback and (is_auto or is_capacity_error):
```

`_is_auth_error` is in `should_fallback` but deliberately **not** in `is_capacity_error`.
So for a task with an explicitly pinned provider:

| Failure on the pinned aux provider | Follows `fallback_chain`? |
|---|---|
| 401 / 403 auth failure | **No** — the aux task hard-fails, error card surfaces to the user |
| 402 payment / daily-quota 429 / connection failure / model-incompatible 400 | Yes |
| any failure class, when `provider: auto` | Yes |

There is **no config knob** to make auth failures fall back on a pinned aux provider. So
"add a `fallback_chain` everywhere" protects against rate limits and quota, not against a
dead credential. For the auth case, re-login the credential (see
`oauth-credential-sharing-pitfalls.md`); the chain is not insurance against it.

### Identifying an aux failure from the error card

The card names the model that failed. If that model appears under `auxiliary.*` and *not*
in `model.default`, the failure is an **auxiliary task** — and the top-level
`fallback_providers` chain was never consulted, which is exactly why the user saw a hard
error while believing a fallback was configured:

```yaml
model:     { default: z-ai/glm-5.2, provider: nous }   # fallback_providers applies here
auxiliary: { vision: { model: gpt-5.6-luna, provider: openai-codex }, ... }
# error card: layer=provider provider=openai-codex model=gpt-5.6-luna
#   → aux task; main fallback chain never runs; aux 401 does not fall back either
```

Grep the config for the failing model name before touching the fallback chain.

### `provider: auto` is not "try my pinned model, then fall back"

Switching a pinned aux task to `auto` does buy fallback-on-any-error, but it silently
changes *which model serves the task*: `_resolve_auto_route()` (≈ line 6218) returns the
**main provider + main model** at step 1 and ignores the task's `model:` field entirely. A
luna-pinned task on `provider: auto` starts running on the main chat model instead.

### When a user asks for "always fall back to X when Y fails"

Present the real options instead of implying the chain does it:

1. **Leave it** — rate-limit/quota/connection failures still degrade, and the auth failure
   is fixed at the source by the per-agent login. Correct answer when the credential is
   healthy; say so plainly.
2. **Pin the aux tasks to the fallback provider outright** (`provider: deepseek`) — a hard
   guarantee, but those tasks never use the primary model again (loses luna for
   vision/compression).
3. **`provider: auto`** — falls back on every error class, but the task moves onto the main
   chat model (previous section).

State the trade-off and let the user choose; do not silently re-pin their aux models.

## Roll it out per profile, not per machine

Hermes profiles are fully separate runtimes: each has its own `config.yaml`, `auth.json`,
`.env`, `state.db` and gateway. A policy applied to `/opt/data/config.yaml` does nothing
for `/opt/data/profiles/<name>/config.yaml`. Apply to every config, and inspect each
profile's credentials separately:

```bash
python3 -c "
import json
for p in ['/opt/data'] + [f'/opt/data/profiles/{n}' for n in ('dev-builder','health-coach')]:
    d = json.load(open(p + '/auth.json'))
    print(p, {k: [(e.get('label'), e.get('last_status')) for e in v] for k, v in d.get('credential_pool', {}).items()})"
```

Do **not** "fix" several profiles by copying one working credential into all of them —
they would share one single-use refresh chain again. Each profile needs its own login.

## Verification 1 — prove the chain fires (non-destructive)

Never test a failover by breaking a real credential (a refresh attempt may rotate the
token, or re-flag `relogin_required`). Instead point the *primary* at a throwaway provider
that cannot answer, using an alternate config file selected by `HERMES_CONFIG`:

```bash
D=/opt/data/cache/fb-test
cp /opt/data/config.yaml $D/config.yaml
cat >> $D/config.yaml <<'EOF'

custom_providers:
  - name: deadtest
    base_url: http://127.0.0.1:9/v1
    api_key: sk-dead
    models:
      - deadmodel
EOF
HOME=/opt/data HERMES_CONFIG=$D/config.yaml /opt/hermes/bin/hermes chat \
  -q "Reply with exactly: FALLBACK_LIVE_OK" -m deadmodel --provider deadtest
```

Expected console line — this is the proof the whole path works:

```
⚠️  Primary auth failed — switching to fallback: deepseek / deepseek-v4-flash
FALLBACK_LIVE_OK
```

Then delete the throwaway config dir. `HERMES_CONFIG` (also `HERMES_CONFIG_PATH`) only
redirects the config file; `auth.json` and `.env` stay those of the active HOME/profile,
which is exactly what makes this a safe probe.

## Verification 2 — which model actually answered

Do not trust the chat output alone: `-Q` (and quiet rendering generally) hides the
fallback banner. The authoritative record is `session_model_usage` in `state.db`:

```bash
python3 -c "
import sqlite3
c = sqlite3.connect('/opt/data/state.db'); cur = c.cursor()
cur.execute('select model, billing_provider, billing_base_url, task, cost_status from session_model_usage where session_id=?', ('<session_id>',))
[print(r) for r in cur.fetchall()]"
```

Columns that matter: `model`, `billing_provider`, `billing_base_url`, `task` (empty =
main turn, otherwise the aux task), `cost_status` (`included` = subscription-covered
Codex, `estimated` = metered API key). Example row proving a failover to DeepSeek:
`('deepseek-v4-flash', 'deepseek', 'https://api.deepseek.com/v1', '', 'estimated')`.
Note that profile runs land in the *profile's* `state.db`, not the default one.

## Verification 3 — resolve the chain without spending tokens

```bash
cd /opt/data && HOME=/opt/data PYTHONPATH=/opt/hermes /opt/hermes/.venv/bin/python -c "
from hermes_cli.config import load_config_readonly
from hermes_cli.fallback_config import get_fallback_chain
from agent.auxiliary_client import _try_configured_fallback_chain, _get_auxiliary_task_config
print('main chain:', get_fallback_chain(load_config_readonly()))
print('aux.vision:', _get_auxiliary_task_config('vision').get('fallback_chain'))
cl, m, lbl = _try_configured_fallback_chain('vision', 'openai-codex', reason='auth error')
print('resolved:', type(cl).__name__ if cl else None, m, lbl)"
```

Resolver output is the fastest way to catch a **dead chain entry**: an entry naming a
provider with no credential at all (e.g. `anthropic/claude-opus-4-6` with no Anthropic
credential in `auth.json`) resolves to nothing and is pure noise in the chain.

## Pitfalls

- **Chain changes need a new agent, not a restart of your patience.** The chain is read at
  agent init, so the session you are sitting in keeps the old chain. Tell the user to run
  `/new` (or restart the gateway) before expecting the new behaviour.
- **Falling back to the failing provider is a no-op.** A chain entry whose `provider`
  equals the one that just failed is skipped. Choose a genuinely different backend.
- **An API-key env override does not beat the stored credential.** Setting a junk
  `OPENROUTER_API_KEY=` for one command still billed through the real pooled key — the
  `auth.json` credential wins. Use the `custom_providers` dead-endpoint probe instead of
  trying to fake an auth failure this way.
- **`last_auth_error.relogin_required` does not mean the provider is unusable right now.**
  Profiles carrying a weeks-old `refresh_token_reused` flag still served live calls. Test
  with a real one-shot call before declaring a credential dead or forcing a re-login on the
  user.
- **Backups before config surgery.** Configs carry trailing documentation comments; a full
  YAML round-trip (load + dump) silently deletes them. Edit line-wise, keep a timestamped
  `.bak-*`, and re-parse the result with `yaml.safe_load` before declaring success —
  `scripts/apply_fallback_policy.py` does exactly this.

## Reporting shape

State the policy that is now in force, the file(s) it was written to, and the evidence:
the failover banner from the probe run plus the `session_model_usage` row. Close with what
is still on the user (device-code approvals) and the `/new` caveat.
