# TrueNAS delegated Archon operations and project images

Use this when Hermes should manage a persistent Archon deployment without repeatedly asking de gebruiker to run host commands.

## Dedicated SSH operator

Prefer a dedicated TrueNAS local user such as `Hermes-ops` with key-only SSH access.

1. Generate a dedicated Ed25519 key in the active Hermes profile, not in a shared or unrelated profile.
2. Confirm the **actual account username**, including capitalization. The TrueNAS user card may prominently show *Full Name* and group while the login name is elsewhere; SSH usernames are case-sensitive.
3. Give the account a dedicated home dataset such as `/mnt/<pool>/Homes/Hermes-ops`.
4. Do not use the Archon app dataset itself as the SSH home. OpenSSH strict-mode checks may reject `authorized_keys` when the home is owned by a container UID or writable by other users/groups.
5. Keep home, `.ssh`, and `authorized_keys` owned by the SSH user with restrictive modes (typically 700/700/600).
6. Grant app-dataset ACLs separately from the home directory.
7. Verify with `ssh -vvv` that the intended key fingerprint is offered; if it is offered but rejected, inspect exact username, key installation, home ownership, ACLs, and strict modes before regenerating keys.

## Docker authority

Inspect `/var/run/docker.sock` ownership before choosing access:

- Adding the operator to the socket's group (commonly `docker`) is easy but effectively grants root-equivalent host control.
- A safer alternative is a root-owned, narrowly scoped `archonctl` plus sudoers rules that expose only status, logs, config validation, build, recreate, restart, and preflight operations.
- Do not mount the host Docker socket into Hermes merely for convenience.

Start with read-only SSH checks (`id`, home, dataset access, socket ownership, `docker ps`) before changing the deployment.

## Upgrade-friendly fork overlay

For long-lived customization:

- `origin` points to de gebruiker's fork.
- `upstream` points to `coleam00/Archon`.
- Keep custom deployment files under a clearly owned subtree such as `deploy/arno/`.
- Keep a long-lived customization branch such as `arno/truenas` rebased onto upstream `dev`.
- Store Compose, Dockerfiles, a non-secret `.env.example`, `archonctl`, worker definitions, validation scripts, and recovery docs together.
- Pin the upstream Archon version in image builds; upgrade deliberately and run preflight workflows before switching the live container.

## Project-image limitation

Do not promise native per-repository worker-image routing without checking the installed Archon version.

In Archon 0.9.0:

- Git repository projects use Git worktrees and execute through the Archon application runtime.
- Configurable Docker runner images are for folder projects, not Git repository projects.
- Container-executed provider support is Claude-only; Codex container execution is not implemented.

Practical MVP:

1. Build one shared Archon server image containing the common toolchain required by all Git repo workflows.
2. Keep separate Make It Happen and Club App project images reproducible for deterministic validation and future native worker routing.
3. Do not claim those images are automatically selected per GitHub codebase today.
4. Keep project CLIs pinned through each repository's lockfile where possible rather than installing mutable global versions.

If strict per-project runtime isolation is required immediately, evaluate separate Archon instances or an explicitly orchestrated external validation-container step, including the operational and Docker-socket trade-offs.

## Validation without Docker plugins

When the management environment lacks Compose/Buildx plugins but real host Docker verification will happen later, perform honest static checks rather than claiming a build:

- parse Compose YAML with a YAML parser;
- parse Bake HCL with an HCL parser;
- parse each Dockerfile with a Dockerfile parser;
- run `bash -n` and ShellCheck when available;
- run `git diff --check`.

Clearly label these as static validation. A successful image build, container preflight, and real workflow run must still be performed on the TrueNAS host before deployment is called working.
