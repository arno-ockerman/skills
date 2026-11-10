---
name: truenas-app-ops
description: Fix or update TrueNAS self-hosted apps from Hermes.
---

# TrueNAS app ops

de gebruiker hosts most of his stack as TrueNAS SCALE custom apps (docker compose) on
`192.0.2.10` (pool `HomeNAS`). This skill is how you diagnose and fix them
from inside the Hermes container — because you **cannot reach them directly**.

## Access model (verified)

- The Hermes container has **no docker socket** and **no SSH private key**.
- TrueNAS host SSH: `admin@192.0.2.10`, private key lives on de gebruiker's Windows
  machine (`C:\Users\SNK206\.ssh\truenas_private_key_rsa.txt`). From Windows:
  `ssh -i "C:\Users\SNK206\.ssh\truenas_private_key_rsa.txt" admin@192.0.2.10`
- A fix you produce must be **run by de gebruiker over SSH** — you cannot exec into the
  app containers yourself. Never claim you "fixed" a TrueNAS app; you deliver a
  script + the SSH command, and de gebruiker runs it. Say this plainly and early.
- Host app data lives under `/mnt/HomeNAS/appdata/<app>/`. Only three datasets
  are mounted into Hermes: `ai-context` → `/opt/ai-context`,
  `ai-tools` → `/opt/ai-tools`, `hermes` → `/opt/data`.

## Where the setup docs live

Per-app notes (`Setup.md`, `Update-instructions.md`, `TODO.md`) live in the
git-synced context repo:

    /opt/ai-context/ProductivityCenter/Projects/truenas/<app>/

Read them FIRST — they hold container names, volume mappings, ports, and update
procedures. `Projects/truenas/Truenas Scale Machine.md` has the SSH command.

## Standard fix workflow

1. Diagnose from the logs de gebruiker pastes (or reads off the TrueNAS UI).
2. Read `Projects/truenas/<app>/Setup.md` for the container/volume layout.
3. Distinguish the Hermes container's internal s6 services from the parent TrueNAS app: internal service controls can restart child processes, but they cannot restart/reconcile the TrueNAS container itself. If boot-time reconciliation or container-level supervision is the blocker, stop after diagnosis and provide the TrueNAS app/container restart command instead of claiming completion.
4. Write a self-contained, idempotent fix script to `/opt/data/scripts/`.
   Because `/opt/data` = `HomeNAS/appdata/hermes`, the file is immediately
   visible on the host at `/mnt/HomeNAS/appdata/hermes/scripts/<name>` — no scp.
4. Hand de gebruiker: the SSH command + `bash /mnt/HomeNAS/appdata/hermes/scripts/<name>`.
5. Script order: backup (`.bak-<timestamp>`) → fix → validate → restart.
   Discover container names dynamically —
   `sudo docker ps -a --format '{{.Names}}' | grep -i <app>` — because names vary
   between `ix-<app>-...` and the compose `container_name`. `sudo` is required.
6. When a container crash-loops (invalid config), `docker exec` is unreliable;

## Hermes gateway topology check

When troubleshooting Telegram delivery for Hermes hosted as a TrueNAS app, inspect `/command/s6-svstat /run/service/gateway-*`, the gateway logs under `/opt/data/logs/gateways/`, and the profile `.env` files without printing tokens. Current Hermes uses one host gateway that multiplexes named profiles; do not run one long-lived gateway per Telegram bot unless the installed version explicitly supports that topology. A `down` marker on named-profile services can be intentional. If `hermes gateway migrate --multiplex --dry-run` reports an s6-supervised-container blocker, the validated remedy is a full TrueNAS app/container restart so boot reconciliation can converge the services; do not treat removing `down` files as the final fix.

7. When a container crash-loops (invalid config), `docker exec` is unreliable;
   run the image's CLI in a ONE-OFF `docker run --rm` with the config/state
   volumes mounted and `--entrypoint` set to the app binary.

## Custom App deploy gotchas (verified 2026-09-09)

When de gebruiker pastes a compose into Apps → Discover → Custom App:

- **Application Name must be lowercase** — it validates against
  `^[a-z]([-a-z0-9]*[a-z0-9])?$` (letters/digits/hyphens, start with a letter).
  `Multica` fails with `String should match pattern '...'`; `multica` passes.
  This error is about the name FIELD, not the compose content.
- **Drop the compose top-level `name:` key** — TrueNAS derives the project name
  from the Application Name field; the key is dead weight and can confuse it.
- Use **host-path bind mounts** under `/mnt/HomeNAS/appdata/<app>/` (not named
  volumes) — that's where TrueNAS keeps app state and where de gebruiker expects it.
- Publish ports on the LAN host (`"8080:8080"`) unless the service is only ever
  reached through a reverse proxy (Cloudflare tunnel).
- **A bind-mounted appdata code repo never self-updates.** An entrypoint that
  clones "on first boot" only clones when the mount lacks `.git`, so changing
  `REPO_URL`/`.env` or pushing new code does NOT refresh `/app`. To replace a
  stale checkout: stop the app, clone fresh to a sibling dir, then copy its
  CONTENTS into the bind mount in place, and rebuild the image. When the mount
  layout changes (a new `/vault` bind, or `CODE_DIR`/`VAULT_DIR` env), the whole
  compose YAML must be REPLACED — restarting the old YAML is not enough.
- **An appdata dataset directory is a ZFS mount point:** `mv` of it fails
  `Device or resource busy` (EBUSY) even with all containers stopped. Back up
  with `cp -a dir/. backup/`, clear with
  `find dir -mindepth 1 -maxdepth 1 -exec rm -rf {} +`, then copy the new
  contents in — never `mv` the dataset dir itself.

## Remote SSH through Cloudflare Tunnel

For native SSH from a remote Windows laptop, a Tunnel route alone is not enough:
plain `ssh user@ssh.example.com` tries Cloudflare edge port 22 and times out.
Use client-side `cloudflared access ssh` as OpenSSH's `ProxyCommand`. The Windows
binary can run portably from the user's profile without admin installation.

Keep HTTP and SSH ingress separate: web hostnames route to HTTP(S), while a
dedicated hostname such as `ssh.example.com` routes to
`ssh://<TrueNAS-LAN-IP>:22`. Leave the route Path empty; copied HTTP path filters
such as `^/blog` prevent correct SSH matching. Protect the hostname with a
Cloudflare Access application and an identity/MFA policy.

Containers already on TrueNAS should SSH directly to the host LAN IP, not loop
out through Cloudflare. Give every agent its own Unix account and SSH key; never
share the human admin key or grant generic passwordless `docker`/shell sudo.
Use root-owned, argument-validating wrappers for narrowly allowed operations.

Detailed setup and diagnostics: `references/cloudflare-tunnel-ssh.md`.

## Per-app references

- `references/cloudflare-ssh-access.md` — SSH naar TrueNAS via Cloudflare Tunnel
  vanaf een laptop zonder adminrechten: portable `cloudflared.exe` als
  ProxyCommand, SSH-aliassen die direct in een container landen, Cloudflare
  Access loginmethodes, TrueNAS sudo-opties en per-agent SSH-keys.
- `references/openclaw-config-migration.md` — "OpenClaw config is invalid"
  (retired keys + missing `agents.ownership`): fix via `openclaw doctor --fix`.
- `references/cloudflare-tunnel-ssh.md` — native OpenSSH through an existing
  Cloudflare Tunnel, VPN diagnostics, and per-container SSH identities.
