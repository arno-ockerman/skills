# Custom app Compose YAML on TrueNAS SCALE

Use this when authoring a third-party app through **Apps → Discover Apps → ⋯ → Install via YAML** rather than the guided wizard.

## What the platform supports

- `build.dockerfile_inline` is supported and documented by TrueNAS, so an app with no published image can still be deployed as one YAML document. Quote the exact README example shape when in doubt.
- Create the datasets and directories BEFORE opening the install screen: TrueNAS explicitly states the screen cannot be saved and resumed to go set up storage afterwards.
- A bind source that does not exist is created by Docker as an empty root-owned directory. The container usually starts as root and can `chown` its way out, so it works — but you lose snapshots, clean separation, and any chance of noticing the typo.

## Escaping and block scalars

- Compose interpolates the entire file, including `environment:` values. A `$` that the CONTAINER shell must expand has to be written `$$`; otherwise compose substitutes at parse time and the container receives an empty string. Inline entrypoint scripts therefore read `$${VAR}` and `$$(...)`.
- A literal block scalar (`command: - |`) is dedented by its common indentation. A heredoc written at the block's own indentation therefore lands in the generated file without stray leading whitespace — do not hand-dedent the heredoc body trying to compensate.
- Keep `$` out of key material and other literal environment values.

## Validate the entrypoint before deploying

You cannot iterate quickly against a failed app deploy, so reproduce the render locally:

1. Parse the compose with any available YAML parser and write out the entrypoint command with `$$` replaced by `$`. If no YAML module is importable, a YAML language server's bundled `yaml` package (under the Hermes LSP `node_modules`) is a usable parser.
2. `bash -n` the rendered script.
3. Build a sandbox copy that removes the privileged steps (`install -d`, `chown`, `chmod`), redirects the persistent paths to a temp directory, and truncates before the daemon start. Run it with representative input.
4. Exercise the failure path: prove that an unfilled placeholder and an empty value each exit non-zero with a readable message, instead of producing a running container that nobody can log into.

Require two observable outcomes: the generated config file contains exactly the expected lines with no junk and no stray indentation, and the input guard rejects invalid input. A guard that fails should fail loudly into the app log.

## Patterns for long-running service containers

- Give every independently operated daemon its own app/container lifecycle. Do not add an s6 service to another product's image-local `/run/service` or `/etc/services.d`; an image upgrade deletes that definition while leaving mounted state behind, producing a confusing "config exists but service vanished" failure.
- Keep the persistent home, host keys, and per-app config on their own datasets so each can be snapshotted independently.
- Run shared coding tools as the dataset's consuming UID/GID and execute interactive login/link commands with the same `docker exec -u` identity; root-owned mode-600 credentials are invisible to the service user.
- Generate SSH host keys on first boot into a persistent path. Otherwise every recreate changes the fingerprint and clients warn on every connection.
- Install `authorized_keys` declaratively from an environment variable at startup so the container is reproducible with no manual state.
- Filter and validate the key input rather than trusting it (`ssh-ed25519`/`ssh-rsa`/`ecdsa-sha2-nistp*` prefix, strip whitespace, accept several lines).
- Never use the `restrict` authorized_keys option on a terminal-multiplexer or agent container: it implies `no-pty`, which breaks the TUI it exists to serve. `from=` restrictions are fine.
- Provide a healthcheck and a `restart` policy. For stable releases, pin an explicit version plus checksum. For an intentionally moving channel such as `nightly`, resolve the channel to an exact version at startup, persist that exact version as the offline fallback, log it, and retain an exact-version rollback switch.
- Schedule channel updates as "check, then restart only if newer" rather than unconditional restarts, because restarts terminate active agent turns.
- Inspect the container cgroup (`memory.current`, `memory.peak`, `memory.max`, `memory.events`) when a provider dies behind a generic transport error. Host free memory is not the container limit; rising `oom_kill` proves the service needs cleanup or a larger isolated limit.

## Handover: the keypair is generated on the CLIENT

The most common misunderstanding when handing over an SSH service container is where the key comes from. State plainly:

- the keypair is generated on the operator's own machine; the private half never leaves it;
- no user, home directory, or `authorized_keys` needs creating on the NAS — the container owns that state;
- the container-side account is created by the image at UID 568, which appears on the host as the existing UID-568 account, so do NOT create a host account claiming that UID.
- give a complete client-side config block (identity file, user, and the network route), not just the route. A `ProxyCommand` transports the connection; it does not authenticate you to `sshd`, so both halves are needed.

### Mirror the transport the operator already uses

Look at how that operator already reaches the same NAS before writing any client instructions — a working entry for a sibling service, or the origins its published apps use. Reuse that transport instead of inventing a direct one; a direct block is silently useless when the NAS is published only through a tunnel.

- For identity-aware tunnel access, the client block is the published hostname plus a proxy command, and it carries NO `Port` line:

  ```sshconfig
  Host <shortname>
      HostName <published-hostname>
      User <container-user>
      IdentityFile ~/.ssh/<dedicated-key>
      IdentitiesOnly yes
      ProxyCommand cloudflared access ssh --hostname %h
  ```

  The first connection opens a browser for the identity provider. The CLI must be installed on the client, and may need its absolute path in `ProxyCommand` when it is not on the PATH the SSH client inherits.
- Also offer a LAN-direct block for the same host. It works on-site without the tunnel, and it doubles as the diagnostic: if LAN works and the tunnel does not, the fault is the published route or its access policy, not the container.
- An access-policy application is a separate step from publishing the route. A published hostname without one is reachable from the internet with only the service's own keys as the control.
- A connector running as `tunnel run` with no local config file is dashboard-managed: every published route lives in the provider's dashboard. Send the operator there instead of searching the host for a config file that does not exist.

## Published ingress from a containerized tunnel client

- A tunnel client running in its own container cannot reach the host via `localhost`; its `localhost` is itself. Target the host's LAN IP in the published-route service URL. An existing working route that uses the host IP rather than `localhost` is the confirmation of this.
- Recommend adding an Access application in front of any newly published hostname. Without it the service is reachable from the internet with only its own keys as the control.
- Note the trade-off when a published port must be reachable from another container: binding it to the host LAN IP also exposes it on the LAN. Say so, and name the compensating control.

## Before editing someone else's deployment

- Verify every bind-mount source and the build context against the HOST before "fixing" a compose file. A compose authored from inside a container can reference paths that exist only inside it, which silently yields empty directories when the daemon resolves them on the host.
- A compose file checked into a repository may be a template rather than the live definition. Changing the mounts, ingress, or environment of a running service needs explicit operator approval: report the finding plus the proposed diff instead of applying it.
