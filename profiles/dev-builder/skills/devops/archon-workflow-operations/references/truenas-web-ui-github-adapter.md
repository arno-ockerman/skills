# TrueNAS Archon Web UI + GitHub adapter notes

Use this when de gebruiker wants Archon's dashboard/Web UI reachable from the browser and/or wants GitHub issues/PRs to trigger Archon workflows.

## Current shape to prefer

- CLI workflows are the MVP and do not require the server.
- Web UI/GitHub webhooks require a persistent Archon server.
- For de gebruiker, expose the Web UI behind Cloudflare Zero Trust, e.g. `https://example.com`, rather than publicly exposing the raw Archon port.
- Keep Archon bound to loopback or protected by a reverse proxy; if GitHub App mode is enabled, ensure `/internal/*` is blocked by the proxy.

## Server/Web UI startup pattern

From source install:

```bash
cd /opt/ai-tools/src/Archon
export PATH=/opt/ai-tools/bun/bin:/opt/ai-tools/bin:$PATH
export ARCHON_HOME=/opt/ai-tools/config/archon
export HOME=/opt/ai-tools/config/codex/home
export CODEX_BIN_PATH=/opt/ai-tools/bin/codex
export DEFAULT_AI_ASSISTANT=codex
export PORT=3090
export HOST=127.0.0.1

# Web UI must be built before production start can serve `/`.
/opt/ai-tools/bun/bin/bun --filter @archon/web build
NODE_ENV=production /opt/ai-tools/bun/bin/bun run start
```

If starting via `bun run dev:server`, make sure `PATH` includes `/opt/ai-tools/bun/bin`; otherwise package scripts may fail with `bun: command not found` even when `/opt/ai-tools/bun/bin/bun` exists.

## Codex env for server

The CLI wrapper can use shared Codex home directly, but the server boot currently checks `CODEX_ID_TOKEN` and `CODEX_ACCESS_TOKEN` env vars. In de gebruiker's shared Codex install these are available inside:

```text
/opt/ai-tools/config/codex/home/.codex/auth.json
```

Extract keys from `tokens.id_token`, `tokens.access_token`, `tokens.refresh_token`, and `tokens.account_id` into env before server start. Do not print token values in logs or chat.

## Verification

```bash
curl -fsS http://127.0.0.1:3090/api/health
curl -s -o /tmp/archon-root.html -w '%{http_code}\n' http://127.0.0.1:3090/
```

Expected after web build + production start:

- `/api/health` returns `status: ok` with `activePlatforms` including `Web`.
- `/` returns the Web UI HTML, not 404.

## GitHub projects/workflows

Important server/CLI difference:

- CLI reads `.archon/commands` and `.archon/workflows` from the current working directory, including uncommitted local changes.
- Server/GitHub adapter reads from Archon's workspace clone, which syncs from remote GitHub. Project workflows must be committed and pushed before the Web UI/server sees them.

### Prefer a dedicated GitHub App for Archon

Use a GitHub App when Archon must not inherit Hermes' personal GitHub identity. Give the App only the repository permissions and repository installations Archon needs. Configure the Archon container with:

```env
GITHUB_APP_ID=<numeric app id>
GITHUB_APP_PRIVATE_KEY_PATH=/opt/ai-tools/config/archon/github-app.pem
GITHUB_APP_SLUG=<app slug>
WEBHOOK_SECRET=<same secret configured on the App>
ARCHON_ALLOW_INTERNAL_ON_PUBLIC_BIND=1
```

Remove `GITHUB_TOKEN` and `GH_TOKEN`; Archon refuses mixed PAT/App mode. Do not point `GH_CONFIG_DIR` or `GITHUB_CONFIG_DIR` at Hermes' config. A shared `gh` wrapper may source a global env file and overwrite Compose values, so put an Archon-specific wrapper first on `PATH`; it must set both variables to an empty Archon-owned directory and exec the real `gh` binary. App mode injects short-lived `GH_TOKEN` values for workflow calls, while the empty config prevents fallback to a personal token.

Store the PEM as a file, not inline. When the dataset is app-owned and the SSH admin cannot write it directly:

1. Upload to the admin home with `scp ... admin@host:~/github-app.pem`.
2. Use temporary passworded sudo, not root SSH or permanent dataset write access.
3. Install atomically with the container UID/GID and mode `0600`, e.g. `sudo install -o <uid> -g <gid> -m 600 ~/github-app.pem <dataset>/config/archon/github-app.pem`.
4. Delete the home copy and remove the temporary sudo grant.
5. Verify only owner/mode and PEM boundary markers; never print the key body.

Before enabling `ARCHON_ALLOW_INTERNAL_ON_PUBLIC_BIND=1`, block `/internal/*` at the reverse proxy or Cloudflare edge. Test the endpoint's actual method, not only GET:

```bash
curl -i -X POST https://archon.example.com/internal/git-credential \
  -H 'Content-Type: application/json' \
  -d '{"host":"github.com","path":"owner/repo"}'
```

The external result must be 403 or 404. After redeploy, verify `/api/health` includes `GitHub (App)`, register a private repository, and read the codebase back. A healthy clone has a real default branch; a row with `default_branch: null` is a failed registration even when the row exists. Delete an incomplete row and re-register after fixing auth.

### PAT mode only for intentionally shared solo installs

PAT mode uses `GITHUB_TOKEN`/`GH_TOKEN` directly for private clones. A `gh` CLI login in `hosts.yml` does not prove the clone path uses that credential. Keep PAT mode only when the operator deliberately accepts that shared identity and blast radius; never use Hermes' credential as Archon's convenience fallback.

Webhook URL:

```text
https://archon.example.com/webhooks/github
```

Use the same `WEBHOOK_SECRET` and subscribe only to the events the installed workflows require.
