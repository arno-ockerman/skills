# Verify bundled Archon workflow packs before installing

Use this when de gebruiker asks to install workflows that are present in the upstream Archon repository, especially packaged sets such as `.archon/workflows/sdlc/`.

## Principle

Do not infer workflow availability from files in the persistent dataset or from a stale external CLI checkout. Modern Archon releases can compile workflow packs into the server image and expose them with `source: "bundled"`. If the running server already exposes every upstream workflow, copying pack files into the dataset is unnecessary and may create duplicate names or unintended overrides.

## Verification sequence

1. Read the live server version and adapters:

```bash
curl -fsS https://<archon-host>/api/health
```

2. Fetch the server-visible workflow catalog:

```bash
curl -fsS https://<archon-host>/api/workflows
```

Treat this endpoint as authoritative for Web UI/server availability. Record each workflow's `workflow.name` and `source`.

3. Fetch the current upstream GitHub tree recursively and derive workflow names from the target pack. For the SDLC pack, match only package entrypoints shaped like:

```text
.archon/workflows/sdlc/<package>/archon-*.yaml
```

Do not count README files, commands, scripts, or fixtures as workflows.

4. Compare the two name sets programmatically and report:

- upstream workflow names;
- server bundled workflow names;
- `missing_on_server`;
- `extra_on_server`;
- exact-set match.

A reliable server-side SDLC identification signal is that the serialized workflow definition references the namespaced pack prefix:

```text
__archon_pack__bundled:sdlc:
```

5. If `missing_on_server` is empty, stop: no installation is required. Tell de gebruiker the workflows are already usable from **Start a new run** and avoid dataset writes.

6. If workflows are missing, first check server/repository version alignment. Prefer upgrading the server to a release that bundles the pack over manually copying internal package directories. Only install repo-local workflows when an intentional override or project-specific adaptation is required, then validate and verify them through `/api/workflows`.

## Output-size pitfall

`/api/workflows` can approach a megabyte because it returns complete expanded definitions. Save or parse it programmatically; do not inspect or enumerate a truncated terminal response by eye. Declared counts and set equality must come from parsed JSON.
