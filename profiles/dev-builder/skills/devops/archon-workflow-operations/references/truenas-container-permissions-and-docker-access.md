# TrueNAS container permissions and delegated Docker access

Use this when an Archon custom app restart-loops on TrueNAS, or when a non-root SSH operator needs narrowly delegated Docker control.

## 1. Build a red-capable container probe

Confirm the exact symptom before changing permissions:

```bash
sudo -n /usr/bin/docker inspect archon \
  --format 'status={{.State.Status}} restarting={{.State.Restarting}} exit={{.State.ExitCode}} restart_count={{.RestartCount}} user={{json .Config.User}}'
sudo -n /usr/bin/docker logs --tail 200 --timestamps archon 2>&1
```

For Archon startup, a useful failure signature is:

```text
EACCES: permission denied, open '/.archon/credential-key'
```

Do not treat a preceding `Failed to load .env` line as the cause if startup continues past it. Rank the fatal `startup_failed` exception highest.

## 2. Inspect mounts without exposing secrets

Read only the fields needed:

```bash
sudo -n /usr/bin/docker inspect archon \
  --format 'user={{json .Config.User}} mounts={{json .Mounts}} ports={{json .HostConfig.PortBindings}} restart={{json .HostConfig.RestartPolicy}}'
```

Avoid dumping all of `.Config.Env`; it can expose provider or GitHub credentials. Query selected environment keys individually or only print key names.

Check host ownership, traversal, and ACLs:

```bash
namei -l /mnt/pool/appdata/archon/data
getfacl -p /mnt/pool/appdata/archon/data
```

Test every bind mount as the configured container UID/GID, not as root:

```bash
sudo -n /usr/bin/docker run --rm --user <uid>:<gid> \
  -v /host/path:/target \
  --entrypoint /bin/sh <archon-image> \
  -c 'r=no; w=no; x=no; [ -r /target ] && r=yes; [ -w /target ] && w=yes; [ -x /target ] && x=yes; printf "read=%s write=%s execute=%s\n" "$r" "$w" "$x"'
```

On zsh, do not name a loop variable `path`; `path` is tied to the `PATH` array and assigning it can make commands such as `sudo` and `sed` appear missing. Use `src` or `mount_path`.

## 3. Repair bind-mount access with ACLs

Prefer a targeted ACL over `chmod 777` or blindly changing dataset ownership. If the SSH operator owns the files, it can usually add the ACL directly:

```bash
setfacl -R -m u:<container_uid>:rwX,m:rwx \
  /mnt/pool/appdata/archon/data \
  /mnt/pool/appdata/archon/home

find /mnt/pool/appdata/archon/data /mnt/pool/appdata/archon/home \
  -type d -exec setfacl -m d:u:<container_uid>:rwx,d:m:rwx {} +
```

The default ACL makes future files and directories writable by the container. Verify with `getfacl` before restarting.

## 4. Verify the fix

Restart only after ACL verification:

```bash
sudo -n /usr/bin/docker restart archon
```

Then sample state twice far enough apart to catch a restart loop. The restart count must remain stable, `Restarting` must be false, and logs should reach both `server_listening` and `server_ready`.

Also verify the local or public HTTP endpoint when command approval permits. A stable Docker state plus `server_ready` is strong container evidence, but do not claim external reachability without an actual HTTP response.

## 5. TrueNAS built-in Docker group handling

Before suggesting a UI path, inspect the group through middleware:

```bash
midclt call group.query '[["group","=","docker"]]'
```

If the group reports `builtin: true` and `immutable: true`, TrueNAS can disable member editing and omit it from user auxiliary-group selectors. Confirm with a non-mutating query first. Do not use `usermod`; changes outside the TrueNAS configuration database can be overwritten.

For an automation account that intentionally needs Docker, use a TrueNAS-managed sudo rule instead:

- UI: **Credentials → Users → <user> → Edit → Additional Details → Sudo Commands**.
- Allow the exact Docker binary, typically `/usr/bin/docker`.
- For unattended automation, use the no-password field only after acknowledging that Docker access is effectively host-root.

Middleware equivalent (discover IDs first; never hardcode session-specific IDs):

```bash
midclt call user.update <user_id> '{"sudo_commands_nopasswd":["/usr/bin/docker"]}'
```

Preserve any existing sudo command lists when updating. Verify:

```bash
sudo -n -l
sudo -n /usr/bin/docker ps
```

Granting a narrow executable path makes the configuration auditable, but `/usr/bin/docker` itself still provides root-equivalent capabilities through privileged containers and host mounts.
