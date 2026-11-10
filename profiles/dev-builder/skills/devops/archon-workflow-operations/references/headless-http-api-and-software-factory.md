# Headless HTTP API + software-factory consumer

Grounded endpoints for driving the 0.12.1 Archon server headlessly (verified against
`https://example.com`). Used by `arno-ockerman/software-factory` ->
`factory/consumer.py`.

## Endpoints

- `GET /api/health` — version, activePlatforms, runningWorkflows.
- `GET /api/workflows` — full catalog (list of `{workflow: {name, description, nodes, inputs, ...}}`).
- `GET /api/codebases` — dynamically resolve the project repository URL to its current codebase id and assistant; never hard-code database ids into a reusable consumer.
- A freshly-added codebase shows `default_branch: null` and `ai_assistant_type: null` until Archon has actually cloned and inspected the repo; a healthy codebase has both populated. Registration in the Web UI is NOT proof the forge token can clone a private repo — read `default_branch: null` as "clone not yet proven", open the project in the UI to trigger the initial clone, and confirm the field resolves to a real branch before declaring the repo reachable.
- `GET /api/conversations` — list bound conversations (id, codebase_id, cwd, platform_type).
- `POST /api/conversations` `{codebaseId}` — returns a fresh conversationId (form `web-<ts>-<rand>`, `id` = DB UUID). A run MUST use a codebase-bound conversation; a bare random-UUID conversationId accepts but never executes.
- `POST /api/workflows/<name>/run` `{conversationId, message, inputs}` — returns `{accepted:true, status:started}` (acceptance only, not success).
- `GET /api/workflows/runs?limit=200` — completed runs only; in-progress work shows in health + the conversation record, NOT here.
- `GET /api/workflows/runs/<id>` — may be `{"metadata":{}}` while alive.

## Cloudflare error 1010 (bot fight mode)

de gebruiker's Cloudflare-fronted services (`example.com`, `example.com`)
block Python `urllib`'s default `Python-urllib/3.x` User-Agent with `403 error code: 1010`.
`curl` (any UA) and urllib WITH a browser UA both return 200. Always set a browser
User-Agent on programmatic HTTP calls:

```python
headers = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"}
```

## Reusable consumer procedure

Build a reusable project factory as context + transport + deterministic harness; keep workflow logic in Archon's bundled pack:

1. Read `GET /api/workflows` and map factory stages to installed workflow names.
2. Resolve the configured repository URL through `GET /api/codebases`; stop when it is not registered.
3. Read the selected workflow's live `inputs` schema and construct only declared fields. Map the user's target semantically (`target`, `work`, `scope`, or `work_order`), derive `repo_host`/`repo_path` from the configured repository, and derive `number` only from an issue URL.
4. Filter stage defaults against the live schema before dispatch. Never send generic fields such as `required_checks`, `protected_paths`, `state_labels`, or `publication` unless that exact workflow declares them — server pack revisions expose different input contracts and unknown fields can reject or misroute a run.
5. Put project gates, protected paths, mission, and stop rules in the run message and versioned project files; do not pretend they are workflow inputs.
6. Make `run` dry-run by default: print the resolved codebase, workflow, message, and filtered inputs without creating a conversation. Require an explicit `--execute` flag for side effects; do not offer an inverted `--dry-run` flag that makes omission dangerous.
7. Gate dangerous stages before any server lookup or dispatch. In particular, refuse merge-queue dispatch while the project policy says `allowMerge: false`.
8. Only after payload approval: create a codebase-bound conversation, dispatch the workflow, and verify execution via health/conversation state rather than treating `{accepted:true}` as success.
9. Make diagnostics fail closed. `doctor` must return a nonzero process exit for an unreachable server, missing required workflow, invalid project config, or unregistered codebase; ensure `main` propagates the command return value through `sys.exit`.
10. Read the repository's actual deploy workflow before describing approval boundaries. If merge-to-main automatically deploys, state that merge approval is also production-deploy approval; a factory `allowDeploy: false` setting does not disable GitHub Actions.

## Reusable installer rules

- Recognize both a `.git` directory and a `.git` file as a valid repository; linked worktrees use a file that points to the parent repository metadata.
- Separate project-owned context from factory-owned transport. Preserve mission, rules, project config, harness policy, and holdout guidance on sync; back up and replace only factory-owned files.
- Exclude `__pycache__`, `.pyc`, and other generated/binary files while walking a text template tree. Add their ignore rules to target projects because compiling the installed consumer creates them.
- Test init, default dry-run, sync preservation, backup behavior, live doctor, negative doctor exits, payload shaping, and dangerous-stage refusal before publishing the factory.
- Load `harness.config.json` in the deterministic runner. Until holdout or mutation execution exists, reject enabled settings with a nonzero exit; never print PASS after silently skipping a configured check.
- During project adoption, inspect automated review comments even when required CI is green. Fix valid findings in the reusable template first, sync factory-owned files into the project, patch project-owned context separately, then rerun CI.
- Edit factory-owned docs (`FACTORY.md`, `factory/WORKFLOW_POLICY.md`, `factory/MIGRATION.md`, the consumer and pack) in the factory template and re-`sync`, not in the target project: `sync` overwrites them (with a `.factory/backup/` copy) so an in-project edit is silently lost. Project-owned files (`MISSION.md`, `FACTORY_RULES.md`, `factory/project.config.json`, `harness/END-TO-END.md`, `harness/harness.config.json`, `.factory/holdout/HOLDOUT.md`) are preserved on sync and must be edited in the project.
- Neutralize an inherited auto-deploy (fork keeps the old project/secret bindings) by switching its trigger to `workflow_dispatch` and adding a job-level `if: ${{ false }}` — never rely on a `workflow_run` completion check or on deleting the workflow, and do not delete the job's project-bound steps until a separate human-approved infrastructure PR replaces the bindings.
- Verify deterministic gates in ISOLATION before blaming the factory setup: a Firebase/Functions project's `npm run verify` (`test:rules` + emulators) is long and flaky under memory pressure — individual rules tests time out at ~15s and a worker-pool probe can flake — while `verify:fast` (typecheck+lint+unit), `functions build`, and `functions test` pass deterministically. Prove each gate separately and report the full-gate flakiness as a known project risk, not a setup defect. The defining signature of flakiness (vs a real regression) is that the SET of failing tests CHANGES between full-suite runs while each test passes in isolation; when you see that, stop chasing a fix and file it as a separate issue instead.

- Commit the factory shell (`factory/`, `harness/`, `FACTORY.md`, `MISSION.md`, `factory/project.config.json`, `.github/`) to the branch Archon actually checks out — the codebase's `default_branch`, normally `main`. Adopting the shell on a side branch means the server-side clone sees none of it and every run works against a bare repo; merge the adoption branch to the default branch (a human-approved merge under the project's own rules) before the first factory run.

## Workflow input keys (verified 0.13.2)

Build inputs by reading each workflow's declared `inputs` and sending ONLY those keys — unknown keys are never sent. Key mappings the consumer uses:

- `archon-ship`: `target` (issue/plan URL), `errors`, `publish` (`false` = triage records labels it would apply), `branch`, `pull_request`, `part`.
- `archon-triage`: `target`, `publish`. `archon-investigate`: `target`. `archon-plan`: `work`, `report`. `archon-implement`: `work`. `archon-review`: `scope`, `errors`, `work_order`. `archon-deliver`/`archon-pr`: `branch`, `draft`, `pull_request`, `errors`.
- Queue/event contracts changed in 0.13.2 and no longer expose `mode`: `archon-intake` has `repo_host`, `repo_path`, `number`, `action`, `kind`, `label`, `label_actor`; `archon-build-queue` has `repo_host`, `repo_path`, `number`, `retriage_as`, `round_limit`; `archon-merge-queue` has `repo_host`, `repo_path`, `limit`, `merge_method`, `retriage_as`; `archon-discoveries` has `repo_host`, `repo_path`, `limit`, `since`, `until`.
- `archon-validate`: `scope`, `comparison`. `archon-upkeep`: `target`, `errors`.
- Treat every server upgrade as a contract migration: run factory `doctor`, update only the reusable pack's required/default inputs, sync consumers, and prove doctor has no workflow-contract failures before dispatch.
- `archon-ship` has NO merge node: merging is a separate `archon-merge-queue` step, so `ship` alone never merges.

## Safety design (software-factory consumer)

- **Server-only**: no local-CLI fallback (`/opt/ai-tools/bin/archon` is v0.6.0 and lacks the SDLC pack, and a CLI path could bypass shared safety checks).
- **Dry-run by default**: `consumer.py run` prints the resolved payload and creates NO conversation unless `--execute` is passed. Verify the conversation count (`GET /api/conversations`) stays flat to prove a dry-run did not dispatch.
- **Merge/deploy gated in config**: `merge_queue` AND `build_queue` are refused unless `project.config.json` -> `workflow.allowMerge` is true (default false). Gate these queue stages deterministically in code before any server lookup — a queue stage is repository-scoped and must not run just because a `ship`-style issue label happened to be present.
- **Readiness gate before execution**: a mutating stage (`implement`, `deliver`, `pr`, `ship` by default) refuses `--execute` until the target is an **open** issue on the configured repository carrying the human-applied `factory-ready` label. Guard order matters: authority guards (allowMerge/allowDeploy) and the dry-run branch run FIRST, then the readiness check, then `create_conversation` — so no check can ever create a conversation or dispatch. Resolve the label with `gh issue view <url> --json state,labels,url` (argv, no shell) and fail closed when gh is absent, unauthenticated, or returns non-JSON; keep the check out of the dry-run path so the payload is still reviewable before labeling. Configure label + guarded stages via `workflow.readyLabel` / `workflow.requireReadyIssueFor` in `project.config.json`. When a review flags that only one stage is guarded, widen `requireReadyIssueFor` to every mutating stage and give the queue stages their own authority guard rather than lumping them into the issue-label gate (they are not issue-scoped).

## software-factory consumer pattern

`arno-ockerman/software-factory` keeps only context + a thin consumer + harness in each
project and delegates ALL execution to the server's bundled SDLC pack by workflow NAME
(`pack.json` -> `archon.workflows` maps stage -> `archon-ship`/`archon-triage`/...).
Run flow: live catalog/schema -> resolve repository to codebase -> dry-run the filtered
payload -> create a bound conversation -> dispatch `POST /api/workflows/<wf>/run`.
Use server mode when the shared CLI does not expose the same bundled workflow pack;
do not infer server capabilities from a different CLI revision.