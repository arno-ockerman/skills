---
name: truenas-operations
description: "Operate and troubleshoot TrueNAS SCALE hosts from Hermes: SSH access, local users/groups, datasets and ACLs, Docker/container access, custom app Compose YAML, dataset migrations, and safe automation against shared mounted repositories."
version: 1.0.0
created_by: agent
metadata:
  hermes:
    tags: [truenas, scale, ssh, users, groups, docker, datasets, acl, automation]
---

# TrueNAS Operations

Use this skill when configuring or troubleshooting a TrueNAS SCALE host, especially from Hermes or another service account.

## Operating principles

- Inspect the live host before changing it; do not infer users, groups, memberships, paths, or permissions from prior conversation alone.
- Prefer the TrueNAS UI/API for persistent account, group, dataset, ACL, and service configuration. Avoid hand-editing appliance-managed files.
- Preserve least privilege. Docker group membership is effectively root-equivalent access.
- Treat usernames as case-sensitive in SSH configuration and command probes.
- After changing supplementary groups, close all sessions for that user and reconnect before verifying.
- Distinguish dataset filesystem permissions from SSH login permissions and from Docker socket access; test each separately.
- Treat container paths and host paths as different namespaces. A path that exists inside a container need not exist on the host; probe every bind-mount source and build context from the host before trusting a compose file or a documented path.
- `docker exec` defaults to root. For logins or CLIs whose state is consumed by an app running as UID/GID 568, execute them with `docker exec -u 568:568`; otherwise root-owned mode-600 credentials look valid to root but are invisible to the app. Verify owner, mode, and a real authenticated API call as UID 568.
- Verify a shared dataset by WRITING to it as the consuming UID, not by reading. A dataset owned by `root` with mode `755` looks fine in listings and still blocks every app UID.
- Before writing client connection instructions, establish how the operator ALREADY reaches that NAS — an existing working entry for a sibling service, or the origins its published apps use. Mirror that transport. A direct host-and-port block is wrong whenever the NAS is published only through an identity-aware tunnel.

## Standard workflow

1. **Identify the release and target**
   - Determine TrueNAS SCALE version where UI labels may differ.
   - Confirm host, exact case-sensitive username, and intended capability.
2. **Probe read-only state first**
   - Use `getent passwd <user>`, `getent group <group>`, `id <user>`, and targeted `test -r/-w/-x` checks.
   - For SSH aliases, use the exact config file with `ssh -F <config> <alias>` when the alias is profile-local rather than under the active `$HOME`.
3. **Apply the smallest persistent change**
   - Users: **Credentials → Users** (older releases may say **Local Users**) → select user → **Edit**.
   - Supplementary membership: **Additional Details → Groups → Auxiliary Groups**.
   - Keep the user's primary group unchanged unless the task explicitly requires changing it.
4. **Refresh identity context**
   - Disconnect old SSH sessions and reconnect; existing processes retain their old supplementary group list.
5. **Verify the capability, not only configuration**
   - Membership: `id <user>`.
   - Docker: `docker ps` or a narrower intended command.
   - Dataset access: explicit read/write/execute probes against the exact path.
6. **Report security impact and rollback**
   - State what privilege was added and how to remove it in the same UI.

## Docker access

Before adding a user to Docker access:

```bash
getent group docker
id <user>
```

If the group exists, add it as an **Auxiliary Group** in the UI. Reconnect and verify `id` includes the Docker GID, then run `docker ps`.

Warn explicitly: a Docker-group member can typically mount host paths or launch privileged containers and should be treated as root-equivalent. See `references/docker-group-access.md`.

## Shared dataset Git automation

When multiple Hermes profiles or schedulers can sync the same repository, search all profile/default cron stores before treating `.git/index.lock` as merely stale. Serialize the entire Git transaction with one shared `flock`; do not only add ad-hoc retries around `git commit`. See `references/concurrent-git-sync.md`.

## Shared app datasets and UID 568

Every app container that shares a dataset does so as UID/GID 568. A dataset created with owner `root` and mode `755` is readable but NOT writable by that UID, which surfaces as a confusing permission failure from a container that otherwise starts correctly.

- Compare against a dataset that already works: `stat -c '%A %U:%G %u:%g %n' <path>` on the host and the same probe inside the container.
- Give the dataset owner `apps:apps` (= `568:568`) so it matches the sibling app datasets.
- Confirm with a write probe as the consuming UID: `touch <path>/.w && rm <path>/.w`.

UID 568 is one identity under several names: `apps` on the host, and whatever the container image named it (`hermes`, `agent`, ...). Do not create a host account that claims UID 568 — it collides with every app already using that identity and gains nothing.

## Migrating repositories between datasets

Copy, verify, then remove — never move first. Verify per repository that HEAD, branch, origin, upstream, the complete working-tree status, and the stash list are identical on both sides, then run `git fsck`. A Python `venv` inside a copied tree is broken by definition and must be rebuilt.

Removing or archiving the source is a separate, later gate, and equality is the wrong test for it: once the destination is in use it legitimately gains commits. Require that the destination CONTAINS the source's HEAD and that the source holds no working-tree change the destination lacks.

The same reference covers filling the dataset IN from a Git host: inventory that host's repositories and diff them against existing clones by remote URL rather than directory name, clone private repositories with `gh repo clone`, and never create a second working copy of a repository that commits on a timer. Procedure, the reference-update sweep, and the pitfalls: `references/shared-dataset-repo-migration.md`.

## Custom App Compose YAML

When authoring a custom app through **Apps → Install via YAML**: `dockerfile_inline` is supported, `$$` escapes a `$` that the *container* shell must expand, and every bind-mount source must already exist on the host or Docker creates an empty root-owned directory in its place. Validate the rendered entrypoint before deploying.

Deploy an independently operated daemon as its own TrueNAS app; never make it durable by adding an s6 service under another app's image filesystem, because an image update replaces that filesystem even when mounted config survives. Give coding-agent services their own memory limit, persistent state, healthcheck, restart policy, and rollback version. See `references/custom-app-compose-yaml.md` and `references/coding-agent-service-containers.md`.

## TrueNAS-managed Hermes upgrades

When Hermes runs as a TrueNAS/Docker app, update it through the TrueNAS Apps flow rather than mutating the container with `hermes update`. Snapshot the complete persistent dataset recursively, validate every profile database, and treat the app image plus persistent state as one rollback boundary. Multi-profile gateways also need unique API ports and post-restart log verification. See `references/hermes-app-upgrades.md`.

## TrueNAS-managed OpenClaw recovery

Derive OpenClaw's active config path from the live container mounts, not old Compose notes. A whole-home mount such as `<dataset>:/home/node` makes `<dataset>/.openclaw/openclaw.json` active; an older `<dataset>/config:/home/node/.openclaw` file may look current while being unused. Before `openclaw doctor --fix`, back up the active config, shared SQLite state, and auth profile files. After migration, run `config validate`, explicitly bind every enabled channel account in a multi-agent roster (for example `agents bind --agent main --bind telegram:default`), restart the gateway, and verify Docker health, HTTP, gateway RPC health, and a live channel credential probe. Allow for slow first startup while state migrations run.

## T3 Code post-upgrade worktree `ref_not_found`

When T3 reports `GitVcsDriver.createWorktree.createBranch ... (ref_not_found)`, inspect the failed run in `userdata/statev2.sqlite` before changing Git. The `run.created` / `run.updated` event contains `workspacePreparation.baseRef`. A known failure mode is a draft persisting `master` while the repository only has `main`, especially when the project was added while clone/default-branch discovery was still settling.

- Set `init.defaultBranch=main` in T3's actual `HOME` to prevent future unborn repositories from advertising `master`.
- For an already-persisted failed draft, either select `main` in T3 and retry, or create local compatibility refs (`refs/heads/master` and, when `startFromOrigin=true`, `refs/remotes/origin/master`) pointing at the corresponding `main` refs.
- Verify with the real seam: create a temporary branch from the repaired start ref, `git worktree add` it, inspect HEAD, then remove the worktree and temporary branch. Do not claim the fix from `rev-parse` alone.

## Verification checklist

- Exact SSH username casing confirmed.
- User and target group both exist.
- Primary group unchanged unless intentional.
- New SSH login sees expected supplementary groups.
- Intended command/path operation succeeds.
- No stale Git operation state or divergent local/remote branch remains after repository automation.
- A shared writable dataset accepted a write probe as the consuming UID, not merely a read.
- For a dataset migration: destination passed an identity check plus a smoke test, and the source was left intact until then.
- Security impact communicated.

## Authoritative sources

Use current TrueNAS documentation as source of truth because menu labels evolve:
- Users: https://www.truenas.com/docs/scale/credentials/users/manageusers/
- Users screen fields: https://www.truenas.com/docs/scale/credentials/users/usersscreen/
- Groups: https://www.truenas.com/docs/scale/credentials/groups/managelocalgroups/
