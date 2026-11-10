# TrueNAS SSH through Cloudflare Tunnel

Use this when HTTPS applications already work through a Cloudflare Tunnel but a
remote laptop cannot route directly to the TrueNAS LAN address, especially with
a corporate VPN active.

## Traffic model

```text
Windows OpenSSH
  -> portable cloudflared ProxyCommand over Cloudflare
  -> ssh.example.com published-application route
  -> existing cloudflared connector on the home network
  -> ssh://<TrueNAS-LAN-IP>:22
```

The laptop never connects to the private LAN IP. The connector does. A standard
Tunnel does not expose Cloudflare edge TCP/22, so this direct command is wrong:

```powershell
ssh user@ssh.example.com
```

It typically times out on port 22 even when the Tunnel route is correct.

## Tunnel and Access configuration

1. Reuse the existing healthy Tunnel connector when it already reaches TrueNAS
   web services.
2. Add a dedicated Published application route:
   - hostname: `ssh.example.com`
   - Path: empty
   - Service type: SSH
   - origin: `<TrueNAS-LAN-IP>:22` (equivalent to
     `ssh://<TrueNAS-LAN-IP>:22`)
3. Do not reuse an HTTP hostname for SSH.
4. Remove copied HTTP path filters such as `^/blog`; SSH has no HTTP URL path.
5. Add a Cloudflare Access self-hosted application for the SSH hostname, with a
   narrow identity Allow policy and MFA. Do not use an `Everyone` policy.
6. Keep router TCP/22 forwarding closed.

## Windows without admin installation

Cloudflare publishes a standalone Windows executable. Store it in a user-writable
location such as `C:/Users/<user>/Tools/cloudflared.exe`; no service, registry
change, or PATH modification is required. Employer application-control policy
still applies.

Example OpenSSH config:

```sshconfig
Host truenas-cloudflare
    HostName ssh.example.com
    User admin
    IdentityFile C:/Users/<user>/.ssh/truenas_private_key
    IdentitiesOnly yes
    ProxyCommand C:/Users/<user>/Tools/cloudflared.exe access ssh --hostname %h
```

Connect with:

```powershell
ssh truenas-cloudflare
```

One-off diagnostic command:

```powershell
ssh -vvv `
  -i "C:\Users\<user>\.ssh\truenas_private_key" `
  -o "IdentitiesOnly=yes" `
  -o "ProxyCommand=C:/Users/<user>/Tools/cloudflared.exe access ssh --hostname %h" `
  admin@ssh.example.com
```

`cloudflared access ssh` is a stdio proxy. Running it alone can appear to hang;
test it through OpenSSH instead. A browser may briefly open for Access login,
but the SSH terminal remains native.

## VPN diagnosis

With the corporate VPN active, check in order:

```powershell
Resolve-DnsName ssh.example.com
Test-NetConnection ssh.example.com -Port 443
ssh -vvv truenas-cloudflare
```

Interpretation:

- Direct `ssh ...@ssh.example.com` timeout: missing ProxyCommand; expected for a
  standard Tunnel.
- Cloudflare 403: Access application or Allow policy mismatch.
- Access succeeds, then connection refused: connector cannot reach the origin or
  TrueNAS SSH is not listening.
- `Permission denied (publickey)`: Tunnel works; fix the TrueNAS user/key.
- Works without VPN but not with VPN: likely employer DNS, WebSocket, or
  application-control policy. Do not bypass corporate controls; request approval.

## Agent/container identities

Containers hosted on the same TrueNAS system should connect internally to the
TrueNAS LAN IP. The laptop VPN does not affect them.

Use one identity per agent:

```text
human laptop -> human admin account + human key via Cloudflare
Hermes       -> agent-hermes + Hermes-only key via LAN
Archon       -> agent-archon + Archon-only key via LAN
```

Persist each private key in that app's protected host-path dataset and mount it
only into the matching container, preferably read-only. Add the corresponding
public key to a separate TrueNAS user. Enable strict host-key checking with a
verified `known_hosts` entry.

Start agent accounts without sudo. For privileged operations, allow only
root-owned wrapper programs that strictly validate actions, app names, and paths.
Never grant passwordless generic `docker`, `bash`, `sh`, `python`, `tee`, editors,
or unrestricted sudo: each enables practical root escape. Separate identities
provide revocation and attribution but not containment if all receive full sudo.

## Verified instance: de gebruiker's TrueNAS (2026-09-14)

- Hostname `example.com`; route origin `ssh://192.0.2.10:22`. The
  same Tunnel already serves `example.com` and
  `example.com` (HTTP), so no second connector was created.
- Client: portable `C:\Users\SNK206\Tools\cloudflared.exe`. The work laptop has
  **no admin rights** — nothing may be installed. Host alias `truenas`, key
  `C:\Users\SNK206\.ssh\truenas_private_key_rsa.txt`. Verified working.
- `192.0.2.10` is unreachable from the work laptop; only the home connector
  reaches it. The company VPN stays on.

Error signature seen on Windows:

- `CreateProcessW failed error:2` / `posix_spawnp: No such file or directory`
  → the ProxyCommand path is wrong, or the exe is still named
  `cloudflared-windows-amd64.exe`. Check with `Test-Path`, re-download via
  `Invoke-WebRequest`, then `Unblock-File`.

Access login state: de gebruiker currently gets an email one-time PIN per session. He
declined changing it on 2026-09-14 ("teveel werk"). Reversible path if he asks:
Zero Trust → Integrations → Identity providers → add **Cloudflare** with
"Restrict to account members" (login then uses his Cloudflare account, which is
already TOTP-protected), optionally plus Access settings → independent MFA →
Authenticator application (TOTP), plus a longer Session Duration / MFA
authentication duration. The email OTP method itself cannot use an authenticator
app. This remains a task for de gebruiker; do not claim it is configured.

Concrete per-app values (design agreed, not yet built):

| Agent | Key on host | Path in container | TrueNAS user |
|---|---|---|---|
| Hermes | `/mnt/HomeNAS/appdata/hermes/ssh/truenas/` | `/opt/data/ssh/truenas/` | `agent-hermes` |
| Archon | `/mnt/HomeNAS/appdata/archon/home/.ssh/` | `/home/appuser/.ssh/` | `agent-archon` |

Archon runs `container_name: archon`, `user: "568:568"`, image
`ghcr.io/coleam00/archon:0.9.0`, volume
`/mnt/HomeNAS/appdata/archon/home → /home/appuser` — chown its key to `568:568`.
TrueNAS users need a real home directory (not `/var/empty`) plus Shell and SSH
Access, or SSH login fails.

Check sudo before promising an automated `RemoteCommand`:
`ssh truenas 'sudo -n true && echo ok'`.

Convenience shell aliases (offered 2026-09-14) add `RequestTTY yes` +
`RemoteCommand sudo docker exec -it <container> /bin/bash`. Caveats: resolve
container names dynamically since they shift, `RemoteCommand` breaks `scp`/`sftp`
(use `-o RemoteCommand=none`), Archon may lack `bash` (use `sh`), and `sudo` may
prompt for a password.
