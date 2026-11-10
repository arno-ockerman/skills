# OAuth Credential Sharing Across Agents

**Rule: centralize the binary and the cache, not the OAuth session.**

## Why this bites

Some agent CLIs (Codex CLI, Claude Code, and anything built on a ChatGPT/Anthropic
subscription login) authenticate with a short-lived `access_token` plus a **single-use
`refresh_token`**. The moment one client exchanges the refresh token for a new access
token, the old refresh token is *consumed* — any other client still holding it gets a
`401` on its next call.

If two agents share one tool HOME (`CODEX_HOME_DIR`, `CLAUDE_HOME_DIR`, …) they share
that token chain and race each other. The symptom looks like a credential bug; it is a
*sharing* bug.

## Symptom

Hermes surfaces it as a provider-layer error:

```
layer: provider
code: unknown
provider: openai-codex
model: gpt-5.6-luna
error: HTTP 401: Could not parse your authentication token. Please try signing in again.
```

and the credential itself carries an "auth failed" marker:

```
$ hermes auth list openai-codex
openai-codex (1 credentials):
  #1  dashboard device_code oauth   ... auth failed unauthorized_unknown (401) (re-auth may be required)
```

## Diagnosis (Hermes)

`hermes auth status <provider>` reports the *stored shape*, not validity — it can print
`logged in` for a credential that is dead. Read the recorded failure instead:

```bash
python3 - <<'EOF'
import json, os
d = json.load(open(os.path.expanduser("/opt/data/auth.json")))   # Hermes HOME/auth.json
for p, st in d.get("providers", {}).items():
    err = st.get("last_auth_error")
    if err:
        print(p, err.get("code"), "|", err.get("reason"), "|", "relogin_required=", err.get("relogin_required"), "|", err.get("at"))
EOF
```

Codes seen so far:

| code | reason | meaning |
|------|--------|---------|
| `refresh_token_reused` | `credential_pool_refresh_failure` | another client already consumed the refresh token — the shared-HOME case |
| `invalid_grant` | `managed_access_token_refresh_failure` | same class of failure for the Nous portal provider |
| `unauthorized_unknown` (401) | — | what the pool entry reports once the chain is dead |

Because Codex is often wired as the `auxiliary.*` model too (vision, compression, title
generation), a dead Codex credential breaks far more than the main chat model.

## Fix — one login per agent, not a shared file

Codex supports a **device-code login**: no browser on the host, no port forwarding, no
SSH tunnel. The CLI prints a URL and a `user_code` for the human to approve elsewhere.

```bash
HOME=/opt/data /opt/hermes/bin/hermes auth add openai-codex --type oauth --no-browser
```

- URL: `https://auth.openai.com/codex/device`
- The command polls for up to ~15 minutes and stores tokens on approval
- Exit code 429 with `codex_rate_limited` means OpenAI is throttling login attempts from
  that IP/account — wait a minute, do not retry in a loop

Run it as a **background PTY process** so you can read the code out and hand it to the
user instead of blocking your turn:

```
terminal(background=True, pty=True,
         command="HOME=/opt/data /opt/hermes/bin/hermes auth add openai-codex --type oauth --no-browser")
process(action="poll", session_id=...)   # → "Open this URL ... Enter this code: XXXX-XXXXX"
```

Tell the user the URL and code, then poll again once they confirm. `hermes auth list
openai-codex` should then show the new entry as the active one (`←`), e.g.
`#1  openai-codex-oauth-2  oauth  device_code ←`.

### Verify with a real call, not with the status output

`hermes auth list` / `hermes auth status` describe the *stored shape*; a live one-shot call
is what proves the credential works end to end:

```bash
cd /opt/data && HOME=/opt/data /opt/hermes/bin/hermes chat -q "Reply with exactly: CODEX_OK" \
  -m gpt-5.6-luna --provider openai-codex -Q
```

Exact-echo prompts make the result trivially checkable, and `-Q` keeps the output clean
(add `-Q` only after you no longer need the failover banner — it hides it).

### Remove the dead pool entry

A re-login adds a **second** credential; the broken one stays in the pool, is still
eligible once its exhaustion window expires, and keeps producing 401s before the client
rotates to the healthy entry. Delete it by entry id (the hex id from `--json`/`auth list`,
not the display index):

```bash
HOME=/opt/data /opt/hermes/bin/hermes auth remove openai-codex 062d11
# → Removed openai-codex credential #1 (dashboard device_code)
```

Grab the id first — the positional forms (`#1`) and 1-based indexing are easy to get wrong
and this deletes state. Provider-UI logins created from the desktop app are labelled
`dashboard device_code`; they are ordinary pool entries and safe to remove once dead.

### Then make the failure survivable

A corrected credential still leaves the next outage as a hard error. Wire the failover
chain too — `references/hermes-provider-failover-policy.md` (main chain **and**
`auxiliary.<task>.fallback_chain`, since aux tasks with a pinned provider ignore the main
chain).

### Fallback that must be watched

On refresh failure Hermes tries to recover by importing `$CODEX_HOME/auth.json`
(`_import_codex_cli_tokens()` in `hermes_cli/auth.py`). That *works* when the shared file
still holds a live token, but it deliberately re-creates the shared chain — so the 401
comes back as soon as the other client refreshes. Use it only to get unstuck, never as
the steady state; the durable fix is the separate device-code login.

## Nous Portal (`nous`) re-login

The Nous portal provider is a managed OAuth session, not an API key, and it takes the same
class of terminal `invalid_grant` (`managed_access_token_refresh_failure`). Hermes then
clears the token material and stamps `providers.nous.last_auth_error.relogin_required`.

Detect it — note that `auth status` **requires** the provider argument:

```bash
HOME=/opt/data /opt/hermes/bin/hermes auth status nous
# → nous: logged out (No access token found for Nous Portal login.)
```

A fully logged-out provider has **no row at all** in `hermes auth list` (only providers
holding pooled credentials appear), so a missing `nous` row is the symptom, not a display
bug.

Fix — same background-process shape as Codex, different approval site:

```bash
HOME=/opt/data /opt/hermes/bin/hermes auth add nous --type oauth --no-browser
```

```
Starting Hermes login via Nous Portal...
Portal: https://portal.nousresearch.com
  1. Open: https://portal.nousresearch.com/manage-subscription?user_code=XXXX-XXXX
  2. If prompted, enter code: XXXX-XXXX
Waiting for approval (polling every 1s)...
```

Run it as a background process, hand the URL + code to the user, poll once they confirm
(`Added nous OAuth credential …` on success). Approval happens on the portal, not on
`auth.openai.com`.

**Why this one is high priority:** when `model.provider: nous`, this credential *is* the
main chat model. A logged-out `nous` therefore breaks the whole agent, yet the error card
may name an aux model instead — check both `auth status nous` and the `auxiliary.*`
providers before concluding which layer broke.

**A container restart does not fix it.** A blank volume seeds `auth.json` from
`HERMES_AUTH_JSON_BOOTSTRAP` (create-only, guarded by `[ ! -f auth.json ]`). On an existing
volume the orchestrator must supply `HERMES_AUTH_JSON_REBOOTSTRAP`
(`scripts/docker_rebootstrap_nous_session.py` re-seeds only a provably terminal
`providers.nous` entry — `relogin_required` with tokens already cleared — and refuses when
live tokens are present, so it can never roll auth backward). Absent that env var, the
interactive login above is the fix.

## Prevention checklist

- Do not copy `~/.codex/auth.json` (or `CLAUDE_HOME_DIR` equivalents) between agents
- Do not point a second agent's `CODEX_HOME` at another agent's home
- Share `/opt/ai-tools/bin/<tool>` and the cache — keep `auth.json` per agent
- If one human account must serve several agents, give each agent its own login;
  device-code flows do not invalidate the others

## Operating note

When a user reports a provider auth error, the deliverable is the re-login they can do in
two minutes. Lead with the diagnosis in one or two lines plus the URL and code — do not
spelunk the Hermes source tree while the fix is already known. Check `hermes auth list
<provider>` and `last_auth_error` first, act, then investigate deeper only if it fails.

Also check the *other* profiles before declaring the incident closed: profiles are separate
runtimes with their own `auth.json`, so the same `refresh_token_reused` / `invalid_grant`
usually sits in every one of them. Report that, and arrange one device-code approval per
profile (they cannot share a chain). Do not force a re-login on a profile whose credential
still serves live calls just because an old `relogin_required` flag is present — test first.
