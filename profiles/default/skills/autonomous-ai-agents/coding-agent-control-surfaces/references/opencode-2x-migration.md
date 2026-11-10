# OpenCode 1.x → 2.x migration

T3's `compatibilityAdvisory` can demand `>=2.0.18` while the installed
binary is on the 1.x train (`graceful` = works, limited). Migrating is a
direct binary swap, not `opencode upgrade` — that command only walks the
current major train (1.x → latest 1.x) and cannot reach 2.x.

## Where the versions live
- The `anomalyco/opencode` GitHub releases ship ONLY 1.x tags — do not
  look for 2.x there.
- V2 is the `@opencode/cli` npm scope (dist-tag `latest`).
- The native linux-x64 binary is in the `@opencode/cli-linux-x64` package
  tarball at `package/bin/opencode` (no `bin` field; the binary is the
  whole payload).

## Procedure
1. Back up the shared binary first (this is the rollback path):
   ```bash
   cp -a /opt/ai-tools/bin/opencode-real /opt/ai-tools/bin/opencode-real.<old>.bak
   ```
2. Resolve the latest V2 version + confirm the platform package name:
   ```bash
   curl -fsSL https://registry.npmjs.org/@opencode/cli -o /tmp/oc-cli.json
   # dist-tags.latest = version; optionalDependencies names @opencode/cli-linux-x64
   ```
3. Download and extract the platform tarball:
   ```bash
   curl -fsSL https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-<ver>.tgz -o /tmp/oc.tgz
   mkdir -p /tmp/oc && tar xzf /tmp/oc.tgz -C /tmp/oc
   /tmp/oc/package/bin/opencode --version   # expect v2.x
   ```
4. Confirm auth carries over BEFORE swapping — V2 reads the same env vars
   the wrapper sources (`token.env`):
   ```bash
   source /opt/ai-tools/config/shared/env.sh
   source /opt/ai-tools/config/opencode/token.env
   export HOME=/opt/ai-tools/config/opencode/home
   /tmp/oc/package/bin/opencode auth list   # OpenCode Go + DeepSeek must appear
   ```
5. Swap into place and verify through the wrapper:
   ```bash
   install -m 0755 /tmp/oc/package/bin/opencode /opt/ai-tools/bin/opencode-real
   /opt/ai-tools/bin/opencode --version    # v2.x
   /opt/ai-tools/bin/opencode auth list    # keys still visible
   ```
6. Restart T3 (s6 will respawn it — kill the serve PID directly, since the
   non-root user can't `s6-svc` a root-owned supervise FIFO):
   ```bash
   kill $(pgrep -f 't3 serve')
   ```
7. Confirm the advisories cleared: read `caches/opencode.json` →
   `compatibilityAdvisory.status == "supported"` and
   `versionAdvisory.status == "current"`.

## Pitfall: "0 models / did not list any models yet" right after the swap
T3's 2.x adapter inventories models through a persistent OpenCode server
that starts on first session use, not through the CLI (the 1.x adapter used
CLI inventory). Immediately after migration the cache shows `models: []` —
that is transient, not a failure. Confirm the models are really there with
`opencode models` (CLI lists them), then open one OpenCode thread in T3 and
the inventory populates.

## Rollback
```bash
cp /opt/ai-tools/bin/opencode-real.<old>.bak /opt/ai-tools/bin/opencode-real
kill $(pgrep -f 't3 serve')
```