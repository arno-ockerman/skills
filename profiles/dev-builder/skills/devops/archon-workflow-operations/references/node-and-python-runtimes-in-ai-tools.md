# Node.js and Python runtimes in the shared ai-tools dataset

Use when a container or CLI needs `node`, `npm`, `npx` or `uv` and the base image does not ship them. `/opt/ai-tools/bin` is on the PATH of every app that mounts the dataset, so putting wrappers there fixes all of them (Hermes, Herdr, Archon) without touching an image.

## What is where

| tool | state |
|---|---|
| `uv` / `uvx` | present as real binaries in `/opt/ai-tools/bin` (0.12.13) |
| `node` / `npm` / `npx` | **wrappers** in `/opt/ai-tools/bin`, real install at `/opt/ai-tools/work/node/v22.23.2` |

Node is pinned to the **22 LTS** line because that is what makeithappen's CI uses (`actions/setup-node` with `node-version: "22"`). Check the target project's CI before picking a version — matching CI avoids "works locally, fails in the pipeline" drift.

## Why wrappers, not symlinks

The Node tarball's `bin/npm` is a symlink to `../lib/node_modules/npm/bin/npm-cli.js` whose shebang is `#!/usr/bin/env node`. That only resolves if `node` is already first on PATH, which is exactly the thing that is broken when you are doing this install. The wrappers invoke the CLI through its own interpreter, so they work regardless of PATH order:

```bash
NODE_ROOT="/opt/ai-tools/work/node/v22.23.2"
exec "$NODE_ROOT/bin/node" "$NODE_ROOT/lib/node_modules/npm/bin/npm-cli.js" "$@"
```

## Installing when your shell has no route to the source

The Hermes container may have IPv6 addresses for `nodejs.org` but no working route (curl returns nothing). If a sibling container does have egress, download from there and extract into the shared dataset — the mounted dataset makes the result visible to everyone:

```bash
sudo -n /usr/bin/docker exec archon sh -c '
  VER=v22.23.2
  BASE=/opt/ai-tools
  mkdir -p $BASE/work/node
  curl -fsSLo /tmp/node-$VER.tar.gz https://nodejs.org/dist/$VER/node-$VER-linux-x64.tar.gz
  rm -rf $BASE/work/node/$VER && mkdir -p $BASE/work/node/$VER
  tar -xzf /tmp/node-$VER.tar.gz -C $BASE/work/node/$VER --strip-components=1
  rm -f /tmp/node-$VER.tar.gz'
```

Do it **as uid 568** (the container's `appuser`), not as root: the dataset is owned `568:568`, and a root-owned tree inside it breaks the other apps. `sudo -n` on this host is scoped to `/usr/bin/docker` only — `sudo mkdir`, `sudo curl` and similar fail with *a password is required*, so route work through `docker exec` instead of trying to sudo your way around the filesystem.

## Always verify without a login shell

`sh -lc` sources `/etc/profile`, which ends with an unconditional `export PATH=…` that wipes `/opt/ai-tools/bin`. A login-shell probe therefore reports a PATH that the real process never sees — and in a container, `sh -lc` can also resolve `node` to a bun shim that is not a Node runtime at all. Verify with `sh -c`:

```bash
sudo -n /usr/bin/docker exec archon sh -c 'for c in node npm npx uv; do printf "%s -> %s\n" "$c" "$(command -v $c || echo MISSING)"; done'
```

A useful end-to-end check that proves more than `--version`: run `npm run` inside a real project directory. It parses `package.json` and lists the scripts, so it exercises resolution, the interpreter and the filesystem in one go.

Avoid running build or test scripts in a worktree while an Archon run is active in it — you will be competing with the agent for the same `node_modules` and build cache.

## A plain `GH_TOKEN` shadows the token that works

When `gh` behaves differently in a container than in your shell, check for a `GH_TOKEN` in the container's env before debugging scopes. `GH_TOKEN` takes precedence over `GH_CONFIG_DIR/hosts.yml`, so a container can authenticate with a *different and less capable* token than the one your shell uses.

Concretely: a fine-grained `github_pat_…` in `GH_TOKEN` could not read `PR.statusCheckRollup` (`GraphQL: Resource not accessible by personal access token`), while the classic `ghp_…` in `hosts.yml` could. Proving it takes one A/B pair:

```bash
# with the env token
sudo -n /usr/bin/docker exec -w /tmp archon sh -c 'gh pr view <n> --repo <owner>/<repo> --json statusCheckRollup --jq ".statusCheckRollup|length"'
# without it (falls through to hosts.yml)
sudo -n /usr/bin/docker exec -e GH_TOKEN= -w /tmp archon sh -c 'unset GH_TOKEN; gh pr view <n> --repo <owner>/<repo> --json statusCheckRollup --jq ".statusCheckRollup|length"'
```

Note `gh auth status` lists **both** identities and marks the env-token one active — so "authenticated" in that output does not mean "has the scope this call needs".

### Fine-grained PATs cannot read the Checks API — plan around it

`statusCheckRollup` merges two context types, and they are not equally obtainable:

| context | reported by | permission | fine-grained PAT? |
|---|---|---|---|
| `StatusContext` | legacy CI (Vercel, …) | `Statuses: read` | yes |
| `CheckRun` | GitHub Actions | `Checks: read` | **no — not grantable** |

GitHub **disabled** the `Checks` permission for fine-grained PATs; only GitHub Apps can use the Checks API. The permission can still appear in the fine-grained permissions documentation while no such checkbox exists in the token settings — trust the settings UI, not the docs table. So a fine-grained `github_pat_…` fails on any repo whose CI reports through Actions, with

```
GraphQL: Resource not accessible by personal access token (…statusCheckRollup…contexts.nodes.0)
```

Let GitHub name the missing permission instead of guessing — `-i` exposes the accepted-permissions header:

```bash
gh api -i repos/<owner>/<repo>/commits/<sha>/check-runs | grep -i x-accepted-github-permissions
# 403 → X-Accepted-Github-Permissions: checks=read
gh api -i repos/<owner>/<repo>/commits/<sha>/status | grep -i x-accepted-github-permissions
# 200 → X-Accepted-Github-Permissions: statuses=read
```

The GraphQL error also names the failing sub-paths (`…statusCheckRollup.nodes.0.commit.statusCheckRollup.contexts.nodes.0`). Older `statusCheckRollup` GraphQL responses carry a `__typename` per context, which is the fastest way to tell `CheckRun` from `StatusContext` when only some contexts fail.

**A 403 naming `checks=read` is a dead end for a fine-grained token — do not send the user hunting for a permission that does not exist.** The fix is a different *kind* of token: a classic PAT carries the `repo` scope, which covers the Checks API, and a GitHub App token works too.

Because `GH_TOKEN` overrides `GH_CONFIG_DIR/hosts.yml`, the practical repair is to remove or comment `GH_TOKEN` in the container's env file so `gh` falls back to the classic token in `hosts.yml`. See `truenas-docker-deployment.md` for locating that file and the recreate-not-restart requirement. Before removing it, check what else reads the variable — a git remote with credentials embedded in its URL does not need `GH_TOKEN`, so pushes keep working.

A differential test isolates *which* input changes the outcome; it does not establish *why*. That is the trap here: toggling the variable proves the token is decisive, while the actual mechanism — an unobtainable permission — makes the "obvious" fix of granting it impossible. Confirm the mechanism against docs, support threads, or source before prescribing a setting change to the user.

Also confirm `Actions: read` for `repos/{owner}/{repo}/actions/workflows`: `check-ci.py` uses it, and on failure it returns `None` (treated as "CI configured") rather than erroring, so a missing permission hides there silently.
