# Aligning Archon CLI and server versions

Use this when the external Archon CLI and persistent Docker server report different versions.

## First identify the code actually executed

Do not equate a deployment-overlay Git checkout with the server runtime automatically.

- A source CLI wrapper may execute `bun <source>/packages/cli/src/cli.ts`; its version comes from that source checkout.
- A custom Dockerfile containing `FROM ghcr.io/coleam00/archon:${ARCHON_VERSION}` runs the official image tag. The overlay repository commit only supplies deployment files and extra image layers unless local Archon source is explicitly copied/built.
- Compare CLI `archon version`, server `/api/health`, wrapper contents, Dockerfile `FROM`, Compose build args/image tag, and source Git status/commit.

## Safe alignment strategy

If the server is healthy and ahead of the CLI, normally upgrade the CLI to the exact server release instead of downgrading the server. Server downgrades may conflict with persisted schema migrations.

For a source CLI install:

```bash
cd /opt/ai-tools/src/Archon
git status --short                 # must be clean
git fetch origin tag vX.Y.Z
git switch --detach vX.Y.Z
/opt/ai-tools/bun/bin/bun install --frozen-lockfile
/opt/ai-tools/bin/archon version
```

Verify that the release tag exists first with `git ls-remote --tags`. Record the previous exact commit before switching so rollback is deterministic:

```bash
git switch --detach <previous-sha>
/opt/ai-tools/bun/bin/bun install --frozen-lockfile
```

## Upgrade both to a newer release

1. Select one explicit semantic version `X.Y.Z`; never track `dev` implicitly in production.
2. Confirm upstream release notes and tag.
3. Back up Archon data/config and record current image/source SHAs.
4. Build or pull the server image pinned to `X.Y.Z` without switching traffic yet where possible.
5. Recreate the container and verify `/api/health` reports `X.Y.Z` and restart count remains stable.
6. Pin the CLI source/binary to the matching `vX.Y.Z`.
7. Run `archon doctor`, workflow/command validation, a deterministic read-only preflight, then one real provider prompt per configured provider.
8. Run one read-only project workflow before mutating code or opening PRs.

## Pitfalls

- Matching package.json versions in two checkouts does not prove runtime parity; inspect the executable/image actually used.
- Do not rebuild a server merely to fix a stale source CLI if the server is already on the desired release.
- Do not use `git pull` on an unclean shared tooling checkout; stop and reconcile intentionally.
- A successful `/api/health` only proves server liveness/version, not provider auth, GitHub access, or project toolchains.
