# Secure remote operations for Archon on TrueNAS

Use this when Hermes can reach the Archon Web UI/API but cannot inspect or repair the Docker runtime, forcing the user to relay SSH commands manually.

## Preferred access pattern

Give Hermes a dedicated TrueNAS account such as `hermes-ops` with SSH public-key authentication. Do not share the user's personal password in chat.

Prefer a narrow host-side `archonctl` wrapper over unrestricted Docker access. Docker socket or Docker-group access is effectively host-root access. The wrapper should expose only the operations needed for the Archon service, for example:

```text
archonctl status
archonctl logs [lines]
archonctl exec <approved diagnostic>
archonctl rebuild
archonctl redeploy
archonctl health
```

Grant write/ACL access only to the Archon deployment and data paths required for operation. Keep the rest of the TrueNAS host inaccessible. Pin the host key and configure a stable SSH alias such as `truenas-archon`.

## Put deployment under version control

Keep the Dockerfile, Compose YAML, non-secret environment example, verification scripts, recovery notes, and `archonctl` wrapper in a private infrastructure repository. Keep real tokens and provider auth outside Git in the persistent Archon dataset.

This makes image rebuilds reproducible and prevents ad-hoc package installation inside a running container from disappearing on recreate.

## Verification ladder after access is established

1. Inspect the actual Compose/App definition, image tag, mounts, runtime UID/GID, healthcheck, and logs.
2. Compare server and external CLI versions. Version skew can produce workflow-schema or API mismatches even when both endpoints appear healthy; align them before authoring or migrating workflows.
3. Verify Web API health and `activePlatforms`. `Web` alone means the GitHub adapter/webhook path is not active.
4. Run the provider/project preflight from inside an actual workflow worker.
5. Confirm repository visibility and repo-local `.archon/` discovery from the server clone.
6. Exercise one small issue-to-draft-PR run with merge and deploy explicitly prohibited.

## Worker image rule

Install durable prerequisites in the Dockerfile, not interactively in the running container. For de gebruiker's current projects the image commonly needs Node/npm, Bun, Git/GitHub CLI, Codex/Claude as selected, Java 21 and Firebase/Playwright support for Make It Happen, and the Expo/Jest/Playwright/Supabase validation toolchain needed by Club App.

Project package dependencies should still be installed reproducibly in each workflow worktree using the repository's canonical commands.

## API-only fallback

When host access is not yet available, the reachable Archon API can still establish partial state:

- `/api/health` proves server availability, version, active platforms, and queue state.
- `/api/codebases` shows registered repositories.
- `/api/workflows` shows server-visible workflows.

Treat these as discovery only. They do not prove container tools, provider auth, filesystem permissions, GitHub write access, or project test prerequisites.