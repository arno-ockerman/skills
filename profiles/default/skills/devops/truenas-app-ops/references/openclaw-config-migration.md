# OpenClaw config migration ("OpenClaw config is invalid")

## Symptom

Gateway crash-loops. Logs show:

```
OpenClaw config is invalid
- meta: Unrecognized key: "lastTouchedAt"
- agents.ownership: multi-agent rosters require agents.ownership="explicit" ...
- gateway.controlUi: Unrecognized key: "allowInsecureAuth"
- gateway.tailscale: Unrecognized key: "resetOnExit"
Legacy config keys detected: gateway.tailscale.resetOnExit, agents.defaults.models, ...
```

Root cause: the OpenClaw image was rebuilt to a newer version; the old
`openclaw.json` still has retired/renamed keys and lacks `agents.ownership`.
`openclaw doctor` still RUNS with invalid config (per the error text), so it can
fix this.

## Layout

- Host config: `/mnt/HomeNAS/appdata/openclaw/config/openclaw.json`, mounted into
  containers as `/home/node/.openclaw` (this mount IS the full state dir).
- Workspace: `/mnt/HomeNAS/appdata/openclaw/workspace` → `/home/node/.openclaw/workspace`.
- Containers (compose): `openclaw-cli` (interactive CLI), `openclaw-gateway`
  (binds 18789; also exposes 18790 control UI + 3333). Image `openclaw:local`,
  run as `node /app/dist/index.js`.
- Gateway crash-loops while config is invalid, so `docker exec` is unreliable.
  Run the CLI in a ONE-OFF container instead (below).

## Fix — `openclaw doctor --fix` (documented in OpenClaw docs)

`--non-interactive` still applies the `agents.ownership="explicit"` fix
(confirmed in OpenClaw's multi-agent docs).

```bash
sudo docker run --rm \
  -v /mnt/HomeNAS/appdata/openclaw/config:/home/node/.openclaw \
  -v /mnt/HomeNAS/appdata/openclaw/workspace:/home/node/.openclaw/workspace \
  -e HOME=/home/node -e OPENCLAW_STATE_DIR=/home/node/.openclaw \
  -e OPENCLAW_WORKSPACE_DIR=/home/node/.openclaw/workspace \
  --entrypoint node openclaw:local /app/dist/index.js doctor --fix --non-interactive
```

Validate with `... config validate` (same `docker run` shape, subcommand swapped).

## Manual fallback (if doctor leaves stale keys)

Edit `/mnt/HomeNAS/appdata/openclaw/config/openclaw.json` on the host (python3):

```python
c["meta"].pop("lastTouchedAt", None)
c["gateway"]["controlUi"].pop("allowInsecureAuth", None)
c["gateway"]["tailscale"].pop("resetOnExit", None)
c.setdefault("agents", {})["ownership"] = "explicit"
```

Leave `agents.defaults.models` alone — `doctor --fix` migrates it to
`agents.defaults.modelPolicy.allow`.

## Full idempotent script

Delivered at `/opt/data/scripts/fix-openclaw-config.sh` (= host path
`/mnt/HomeNAS/appdata/hermes/scripts/fix-openclaw-config.sh`). Order: backup →
doctor → validate → manual fallback → restart gateway. Reproduce it from the
steps above if the file is gone.
