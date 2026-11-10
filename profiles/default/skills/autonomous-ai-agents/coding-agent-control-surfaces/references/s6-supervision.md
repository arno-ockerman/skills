# s6 dynamic service supervision for third-party servers

Recipe for running a long-lived third-party server (T3 Code, etc.) inside the Hermes s6 container so it survives crashes and restarts like a supervised service.

## Why not `t3 service install`
It writes a systemd/user unit that only survives within the container's ephemeral lifecycle; a container restart loses it. s6 (PID 1) is the real supervisor. This recipe generalizes to any long-running binary the container should keep alive.

## Register a dynamic service
Stage the service dir under a dot-prefixed name so svscan ignores it while incomplete, then move it into place atomically:

```bash
# 1. Stage (dot-prefixed = invisible to svscan)
mkdir -p /run/service/.t3-stage/log/supervise /run/service/.t3-stage/supervise
install -m 0644 <type-file>     /run/service/.t3-stage/type
install -m 0755 <run-file>      /run/service/.t3-stage/run
install -m 0755 <log-run-file>  /run/service/.t3-stage/log/run

# 2. Atomic swap into place (single mv, so svscan never sees a half-written dir)
mv /run/service/.t3-stage /run/service/t3-code

# 3. Rescan
/command/s6-svscanctl -a /run/service

# 4. Verify
/command/s6-svstat /run/service/t3-code   # expect: up (pid ...)
```

## File templates
`type`:
```
longrun
```

`run` (drop to hermes, pin env, exec the server):
```sh
#!/command/with-contenv sh
exec /command/s6-setuidgid hermes env \
  HOME=/opt/data/home \
  PATH=/opt/ai-tools/bin:/usr/local/bin:/usr/bin:/bin \
  T3CODE_HOME=/opt/ai-tools/config/t3code \
  /opt/ai-tools/bin/t3 serve --host 127.0.0.1 --no-browser /opt/project
```

`log/run` (s6-log to a persistent log dir):
```sh
#!/command/with-contenv sh
exec /command/s6-setuidgid hermes /command/s6-log n20 s1000000 /opt/ai-tools/config/t3code/logs
```

## Pitfalls
- **Create the dir atomically (mv).** If svscan scans a half-written dir, s6-supervise (root) creates a root-owned `supervise/control` FIFO and the hermes user gets "Permission denied" on `s6-svc` forever. A broken dir can only be renamed away (`mv` within `/run/service`), not removed in place.
- **No `down` marker unless you want it stopped.** With a root-owned supervise dir the hermes user cannot `s6-svc -u` it back up; it stays "down (not started yet)".
- **Verify with `s6-svstat`, not the process list.** "down (not started yet)" or "Permission denied" means the swap/ownership was wrong; a PID in `ps` alone is not proof the service is supervised.
- **Logs live in `<logdir>/current`** (s6-log). Check there when the server is silent — the service's own stdout may be buffered away from the tool result.
- The s6 service slot is on tmpfs and is wiped on container restart — data/install/logins persist, but the `/run/service` registration must be recreated each boot. Persist it via a cont-init hook or re-run this recipe after restart.
