# Hermes App upgrades on TrueNAS SCALE

Use this playbook when Hermes is installed as a TrueNAS/Docker app and the requested upgrade replaces the image or app revision.

## Core rule

Treat this as an image-managed application upgrade. Use the TrueNAS Apps update flow; do not run `hermes update` inside the container. Newer Hermes releases intentionally reject unsafe in-place updates for image/package-managed installs.

Before upgrading, inventory non-Hermes daemons supervised inside the container as well as persistent data. A service definition under `/run/service`, `/etc/services.d`, or another image-local path disappears when TrueNAS replaces the image. Move any independently operated daemon to its own Custom App before relying on it; sharing persistent datasets and CLI wrappers is fine, sharing another app's lifecycle is not.

## Preflight

1. Confirm version and install method with `hermes --version` (use the installed binary's absolute path if necessary).
2. Confirm `/opt/data` is a persistent dataset/mount, not container-local storage.
3. Inventory the default profile and every named profile under `/opt/data/profiles/`.
4. Check free space and the sizes of `config.yaml`, `.env`, `auth.json`, and `state.db` without exposing secrets.
5. Open every SQLite state database read-only and run `PRAGMA quick_check`; stop if any result is not `ok`.
6. Run `hermes config check` for the default root and each named profile. Migrate configuration before upgrading only when the installed release supports the target migration safely.
7. Review current release notes and the full tag range. A date-tag jump may contain a major core-version change even when the target itself is called a patch release.

## Snapshot and rollback boundary

Immediately before updating, create a recursive ZFS snapshot covering the whole persistent Hermes tree, including child datasets. Record the current app version and chart/revision.

A rollback must restore both sides of the boundary:

- restore the previous TrueNAS app/image version; and
- restore the matching ZFS snapshot if the newer Hermes version may have migrated config or databases.

Do not roll back only the image while leaving newly migrated state databases in place.

## Update

1. Use **TrueNAS Apps → Hermes → Update**.
2. Let TrueNAS replace and fully restart the container.
3. Do not interrupt the first boot; large `state.db` files or schema/config migrations can make it slower than normal.

## Post-update verification

1. Confirm the expected Hermes core version with `hermes --version`.
2. Run `hermes doctor` and `hermes status --all`.
3. Verify dashboard/public ingress, Telegram or other platform connectivity, webhooks, cron jobs, and every named profile.
4. Verify each enabled API server is bound to its intended unique port. Prefer `127.0.0.1` when only same-container services need access; avoid `0.0.0.0` with an unsandboxed local terminal unless external access is explicitly required and firewalled.
5. Check only log entries created after the new startup timestamp. Historical errors remain in rotated/current logs and do not prove the upgrade is still failing.
6. A one-time `pruning stale sessions.json entry ... left by a crashed gateway` warning means Hermes removed stale routing metadata; treat it as cleanup unless it repeats every boot or active routing fails.

## Multi-profile API port pitfall

Container-level `API_SERVER_*` environment variables can affect every supervised profile gateway. If several gateways inherit one enabled port, they race for the same socket and emit `address already in use`.

Give every enabled profile a unique port and verify the live bind after restart. Example allocation:

- primary profile: `30432`
- default gateway: `30434`
- second profile: `30435`
- third profile: `30436`

The exact numbers are deployment-specific; uniqueness and post-restart verification are the invariants. Also inspect the live process environment when runtime behavior disagrees with `config.yaml`, because supervisor/container environment overrides may win.

## Evidence required before declaring success

- every state database passed `PRAGMA quick_check` before the update;
- a recursive snapshot exists;
- the target core version is live;
- all supervised gateways are running;
- expected local ports accept connections;
- no new API bind errors or network-exposure warnings appear after the latest startup timestamp;
- at least one real platform/dashboard smoke test succeeds.