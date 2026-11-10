# TrueNAS Docker deployment notes for Archon

Use this when debugging Archon on TrueNAS SCALE Apps or Docker Compose with host bind mounts and shared `/opt/ai-tools` inside the container.

## Host bind-mount sources must live under datasets

TrueNAS Apps may run with parts of the host root filesystem read-only. If a compose file bind-mounts host paths such as `/opt/ai-tools` or `/opt/ai-context/ProductivityCenter` and those paths do not already exist on the host, Docker can fail during `up` with:

```text
error while creating mount source path '/opt/ai-context/ProductivityCenter': mkdir /opt/ai-context: read-only file system
error while creating mount source path '/opt/ai-tools/...': mkdir /opt/ai-tools: read-only file system
```

Fix: put the host-side data under a TrueNAS dataset, while keeping the expected container paths:

```yaml
volumes:
  - /mnt/HomeNAS/appdata/ai-tools:/opt/ai-tools
  - /mnt/HomeNAS/appdata/ai-context/ProductivityCenter:/opt/ai-context/ProductivityCenter
```

## Docker Archon data/home

Archon Docker data is fixed at `/.archon`; `ARCHON_HOME=/.archon` can be omitted if the container logs that it is ignored.

```yaml
volumes:
  - /mnt/HomeNAS/appdata/archon/data:/.archon
  - /mnt/HomeNAS/appdata/archon/home:/home/appuser
```

## `setup-auth` image mismatch workaround

If the container starts then crashes with:

```text
error: Script not found "setup-auth"
```

it indicates an image/source mismatch around the Docker entrypoint. For diagnosis, bypass the default entrypoint and start the server directly from `/app`:

```yaml
user: "1001:1001"
entrypoint: ["bun"]
command: ["run", "start"]
working_dir: /app
```

Set dataset ownership for the container user:

```bash
chown -R 1001:1001 /mnt/HomeNAS/appdata/archon /mnt/HomeNAS/appdata/ai-tools /mnt/HomeNAS/appdata/ai-context
chmod -R u+rwX,g+rwX /mnt/HomeNAS/appdata/archon /mnt/HomeNAS/appdata/ai-tools /mnt/HomeNAS/appdata/ai-context
```

Avoid complex folded shell entrypoint strings on TrueNAS Apps unless verified; malformed command passing can surface as `chown: missing operand`.

## GitHub CLI auth via shared ai-tools

For Archon workflows using `gh`, ensure both the binary and config/auth are visible in the container.

Recommended compose pieces:

```yaml
env_file:
  - /mnt/HomeNAS/appdata/archon/data/.env

environment:
  GH_CONFIG_DIR: "/opt/ai-tools/config/gh"
  GITHUB_CONFIG_DIR: "/opt/ai-tools/config/gh"
  PATH: "/opt/ai-tools/bin:/opt/ai-tools/work/npm-prefix/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

volumes:
  - /mnt/HomeNAS/appdata/ai-tools:/opt/ai-tools
```

In `/mnt/HomeNAS/appdata/archon/data/.env` use exact uppercase names:

```env
GH_TOKEN=ghp_xxx
GITHUB_TOKEN=ghp_xxx
```

Do **not** also set these in `environment` as `${GH_TOKEN}` / `${GITHUB_TOKEN}` unless the TrueNAS compose substitution source is verified; empty substitutions can override values from `env_file`.

Use a **classic** token here (`ghp_…`). A fine-grained PAT cannot read the Checks API at all, so any workflow that inspects CI check state fails with `Resource not accessible by personal access token` and no permission grant can fix it — see `node-and-python-runtimes-in-ai-tools.md`.

### A variable injected by `env_file` is invisible in the Apps UI

The Custom App UI renders the `environment:` list. `env_file:` is a separate Compose key, so a variable arriving that way does **not** appear among the app's environment variables and cannot be found by searching the UI. Read the rendered compose instead; the running container's label says which file is authoritative:

```bash
docker inspect archon --format '{{index .Config.Labels "com.docker.compose.project.config_files"}}'
```

`/mnt/.ix-apps` is root-only, so read the rendered compose through a throwaway container — mount it read-only and never edit it, it is generated:

```bash
sudo -n /usr/bin/docker run --rm --entrypoint sh \
  -v /mnt/.ix-apps/app_configs/archon:/cfg:ro \
  ghcr.io/coleam00/archon:latest \
  -c 'sed -n "1,30p" /cfg/versions/*/templates/rendered/docker-compose.yaml'
```

Check **both** `env_file:` and `environment:` in that output before concluding a variable is unset. The env file itself (`/.archon/.env` in-container and `/mnt/HomeNAS/appdata/archon/data/.env` on the host are the same file) may be ACL-blocked for the host shell — read it with `docker exec` as the container user rather than from the host, and mask values when printing.

### Recreate, do not restart, after an env change

`env_file` is read when the container is **created**. A plain `docker restart` reuses the existing container and keeps the old environment, so the edit looks like it had no effect. In the TrueNAS UI that means **Stop → Start** (recreates), not **Restart** (reuses). Read the variable back inside the container afterwards to confirm.

Verification inside the running container — always `sh -c`, never `sh -lc` (a login shell sources `/etc/profile`, which overwrites `PATH`; see `chaining-archon-runs.md`):

```bash
docker exec -it archon sh -c 'test -n "$GH_TOKEN" && echo GH_TOKEN_loaded || echo GH_TOKEN_missing'
docker exec -it archon sh -c 'command -v gh && gh --version'
docker exec -it archon sh -c 'gh auth status'
docker exec -it archon sh -c 'gh repo view OWNER/REPO --json nameWithOwner'
```
