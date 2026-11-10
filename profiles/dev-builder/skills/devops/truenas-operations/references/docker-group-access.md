# Docker group access on TrueNAS SCALE

## Purpose

Grant an existing trusted local user access to the Docker socket while preserving its current primary group.

## Read-only discovery

Run on the TrueNAS host:

```bash
getent group docker
id <exact-case-sensitive-user>
```

Do not assume the group exists or that the user is already a member. The Docker GID can vary by host.

## Persistent UI change

Current UI path:

1. **Credentials → Users** (older versions: **Credentials → Local Users**).
2. Select the local user and click **Edit**.
3. Expand **Additional Details**.
4. Edit **Groups**.
5. In **Auxiliary Groups**, select `docker`.
6. Leave the primary group unchanged.
7. **Save**.

TrueNAS hides some built-in accounts/groups in list views, but the auxiliary-group selector is the intended membership control. If labels differ, consult the docs for the installed TrueNAS release.

## Session refresh and verification

Close all SSH sessions for the user and reconnect. Then:

```bash
id
docker ps
```

`id` must include the Docker group's numeric GID/name. A successful `docker ps` verifies socket access rather than merely UI state.

## Security and rollback

Docker membership is effectively root-equivalent: members can commonly launch privileged containers or mount host filesystems. Grant it only to trusted operators.

Rollback through the same user edit screen by removing `docker` from **Auxiliary Groups**, saving, and reconnecting the user's sessions.

## Sources

- https://www.truenas.com/docs/scale/credentials/users/manageusers/
- https://www.truenas.com/docs/scale/credentials/users/usersscreen/
