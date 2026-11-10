# Making a new provider model selectable in Archon

Use when a provider ships a model Archon does not know about (e.g. a new Codex flagship) and it must be usable without editing bundled code.

## Step 1 — does the provider actually serve it?

The model list Archon's web UI shows is **not authority**. `packages/web/src/experiments/console/lib/model-options.ts` says so outright: the curated lists are "CONVENIENCE suggestions, not authority — the SDKs ship models faster than Archon can enumerate them, so every consumer keeps a free-text escape and nothing client-side blocks an unlisted model string." So an absent dropdown entry means nothing; test the model instead.

For Codex the model catalog lives in the CLI's cache, not in Archon:

```bash
python3 -c "import json;d=json.load(open('/opt/ai-tools/config/codex/home/.codex/models_cache.json'));[print(m.get('slug'), '|', m.get('visibility'), '|', m.get('display_name')) for m in d['models']]"
```

Check `fetched_at` before trusting it — a stale cache can list models the server no longer serves, or miss new ones. Then run the model for real; a catalog entry is not an entitlement:

```bash
/opt/ai-tools/bin/codex exec --skip-git-repo-check --sandbox read-only -m <slug> "Reply with exactly: OK"
```

Repeat it **inside the app container**, not only in your own shell — the container is the environment the engine spawns, and it has its own `CODEX_HOME`, PATH and mounts:

```bash
sudo -n /usr/bin/docker exec -w /tmp archon /opt/ai-tools/bin/codex exec --skip-git-repo-check --sandbox read-only -m <slug> "Reply with exactly: OK"
```

Archon passes a Codex model string straight through (`model: model ?? config.model` to the SDK) and has no allowlist — the only model-name logic is `CODEX_MODEL_FALLBACKS`, a map of *retired* slugs to current ones.

## Step 2 — add an alias

The body must be wrapped in `aliases`; a bare `{"@name": {...}}` is rejected with `aliases: Invalid input: expected record, received undefined`:

```bash
curl -s -X PATCH https://<host>/api/config/aliases \
  -H 'Content-Type: application/json' \
  -d '{"aliases":{"@<name>":{"provider":"codex","model":"<slug>"}}}'
```

It is a **per-key merge** — existing aliases and tiers are untouched. Verify by reading back `GET /api/config` (note `/api/config/tiers` and `/api/config/aliases` are PATCH-only; a GET on them falls through to the SPA and returns HTML, which looks like a broken route).

Prefer the API or `archon ai alias set` / `archon ai tier set` over hand-editing `/.archon/config.yaml`. The CLI equivalent is:

```bash
archon ai alias set @<name> codex <slug> [--effort <e>] [--scope user|install]
archon ai tier set <small|medium|large> codex <slug> [--effort <e>]
```

## Step 3 — prove the alias resolves, without burning a run

`archon validate workflows` checks model refs but runs no AI node, so a validation-only workflow costs nothing. Put one in a throwaway git repo (the CLI refuses to run outside a git repository) with a bash-only node and the alias at workflow level:

```yaml
name: alias-check
description: validation only
model: "@<name>"
nodes:
  - id: noop
    bash: |
      echo "validation-only workload"
```

```bash
sudo -n /usr/bin/docker exec -e ARCHON_HOME=/.archon -w <dir> archon sh -c 'cd <dir> && /opt/ai-tools/bin/archon validate workflows'
```

**Always pair it with a control.** An `ok` on its own proves nothing — a workflow with `model: "@nonexistent"` must fail. The failure message is the evidence, because it enumerates every registered alias:

```
ERROR [model] Unknown alias '@nonexistent'. Defined aliases: small, medium, large, @opencode, @luna, @astra
```

If the real alias is absent from that list, the patch did not land; if it is present and the workflow validates `ok`, resolution works.

Create the alias first, then the control workflow **after** the real one exists, so the control's alias list proves registration.

## Scope: aliases vs tiers

Aliases (`@name`) are for project workflows, the console and chat. They are deliberately **not portable for bundled workflows** — the validator rejects `model: @alias` there with "not portable", so a bundled workflow (including anything in the sdlc pack) cannot select an alias and needs a literal provider model string or a tier.

To move a bundled workflow onto a new model, change the relevant tier (`small`/`medium`/`large`) instead. Treat that as a production change: tiers drive every workflow node, so confirm before repointing one.

## Cleanup

Delete the throwaway validation repo when finished, and confirm `/.archon/config.yaml` carries the alias (that file survives redeploys, whereas a container-local edit does not).

```bash
sudo -n /usr/bin/docker exec archon rm -rf <dir>
```
