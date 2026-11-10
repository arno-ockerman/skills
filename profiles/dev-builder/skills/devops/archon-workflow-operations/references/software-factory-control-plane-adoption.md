# Software factory control-plane adoption

Use when de gebruiker wants to reproduce a public AI software factory, autonomous issue loop, or mission-control dashboard while he already has Archon running.

## Cole's upstream is two divergent architectures (verified 2026-11-04)

- The Nov-2026 video-era factory pins `ai-software-factory` `f6d8f69e` + Archon `1cfb8fc5` and the old `archon-loop`/holdout pack. The current `factory-mission-control` head `e5d881dc` moved to Archon v0.13.2's native intake/build/merge/attention queues and removed holdouts. These are NOT one coherent release — pick a target, never merge both.
- The pinned old-loop consumer cannot use de gebruiker's v0.13.2 server: it requires its exact immutable local Archon source pin. The v0.13.2 queue pack + project-owned `factory-*` workflows is the recommended production target; the old loop is only a replication experiment.
- There is no supported SQLite→Postgres history migration in Archon. Mission Control requires Archon + its `mc` projection triggers in the SAME Neon Postgres DB; SQLite cannot back it. A parallel Postgres-backed Archon instance, clean cutover, or a separately validated ETL are the only safe routes.

## Decompose the demonstrated system first

Treat these as separate deployables with explicit interfaces:

1. **Execution plane:** Archon server, provider authentication, bundled workflow pack, worktrees and run records.
2. **Project consumer:** project mission, governance, deterministic harness, holdouts, runtime resources and a thin client that dispatches server-owned workflows.
3. **Forge ingestion:** GitHub issues, labels, comments, pull requests, reviews and pushes delivered by webhook plus reconciliation/backfill.
4. **Event store:** Postgres tables for Archon runs and projected dashboard data; Realtime is a separate capability, not implied by “Postgres works.”
5. **Control plane:** read-only dashboard, owner queue, health, scorecards, version comparisons and links back to Archon's detailed run console.

Do not describe a dashboard clone as “the factory is installed” until all five boundaries are accounted for.

## Safe adoption order for de gebruiker

1. **Inventory the live system.** Read server health, server version, auth mode, database backend and the authenticated `/api/workflows` catalog. Compare the server with the external CLI; the server catalog is authoritative when the consumer dispatches over HTTP.
2. **Choose one pilot repository.** Port only the current deterministic project layer: `.archon/factory.yaml`, the config compiler, nested setup workflow, SDLC policies and project context. Remove an older flat setup/backlog experiment instead of running both generations together. Keep autonomy supervised and merge/deploy disabled until the complete path is proven.
3. **Validate live contracts.** Resolve the codebase dynamically, read each selected workflow's declared inputs, and fail closed when a required workflow or input is absent. Never copy an upstream `pack.json` contract without checking the live server revision.
4. **Define product evidence.** Write mission/non-goals, protected paths, exact static/unit commands, two to five current user journeys, and provider-appropriate holdouts. For Codex or mixed-provider runs, keep private holdouts outside the repository unless a tested provider-independent fence exists.
5. **Bind runtime evidence to the delivered revision.** Start a fresh candidate instance, verify health and a build identity equal to the candidate commit, exercise user-value transitions, prove a relevant deliberate defect fails, and clean up without disturbing another instance.
6. **Run one supervised lap.** Dry-run the payload first; then execute one small issue with merge held for approval and deploy disabled. Verify the PR, deterministic checks, runtime evidence, independent review and persisted run record.
7. **Add the loop and manager gradually.** Start at one concurrent lap. Increase concurrency only after claims, worktrees, ports, fixture state and cleanup are demonstrably isolated. Keep owner decisions explicit.
8. **Add scheduling last.** A timer must use the same provider/GitHub auth and tool paths as the successful manual run. Scheduling does not authorize merge or deploy.
9. **Add the control plane after trustworthy events exist.** First prove run and GitHub events land correctly; then migrate/backfill, configure factories, deploy the dashboard and verify a live update without reload.

## Deterministic project-layer verification

Treat the repo-owned factory config script as a compiler, not a text installer:

1. parse and validate its schema before writing;
2. preserve unrelated project configuration;
3. fail closed on malformed managed blocks, including unequal marker counts **and reversed marker order**;
4. apply twice and prove the second application produces no diff;
5. cover protected-path parity and disabled-trigger cleanup with focused tests;
6. keep Bun-only tests out of the application test runner's discovery pattern — in a globally scanned Vitest repo, use a Bun-recognized `_test_` filename or an explicit Vitest exclusion rather than importing `bun:test` from `*.test.ts`.

A local full gate that terminates without a recorded assertion is not green. Clean up any orphan emulator children and stale verification lock, record the runner/resource limitation honestly, and require the protected CI full-gate check before merge.

## Exact-dashboard database decision

A dashboard that reads Archon's internal run/event tables and uses database Realtime normally requires Archon and the dashboard projections to share the same Postgres project. Before changing Archon's database URL:

1. identify the current database backend and schema version;
2. take a restorable backup and test restore;
3. rehearse migration against a disposable Archon instance or database branch;
4. run migrations that add dashboard tables/triggers without modifying Archon's owned schema;
5. prove projection failures cannot block an Archon write;
6. switch one supervised worker and verify run creation, events, console reads and dashboard projection;
7. only then move the production execution plane.

If Archon must remain on its existing database, build an explicit replication/ETL boundary and accept that it adds consistency and latency failure modes. Do not claim that path reproduces direct Realtime semantics until measured.

## Mission-control repository adaptation

Public dashboard repositories are often owner-specific even when open source. Before deployment, inspect and replace:

- factory names, repository slugs and Archon console URLs;
- hard-coded source repositories or workflow-pack locations;
- database project assumptions and branch names;
- webhook repository allowlists and signing secret;
- architecture/version parsers tied to one upstream commit convention;
- local-only origin and port allowlists;
- owner-specific metrics, holdout formats and decision-comment parsers.

Prefer a fork with a small versioned configuration file over editing owner-specific constants throughout the code.

## Verification gates

Do not advance to the next automation level unless the current one is observed working:

| Level | Required proof |
|---|---|
| Consumer | Doctor validates live workflow names and required inputs; dry-run creates no conversation/run. |
| Supervised run | One issue produces a PR with deterministic checks, runtime identity evidence and independent review. |
| Merge | Human-approved merge succeeds and the recorded outcome matches GitHub. |
| Deploy | The service health passes and its build identity equals the merged default-branch revision. |
| Scheduling | A timer starts at most the configured concurrency, resumes waiting work safely and leaves no orphan runtime. |
| Dashboard | A new run event and a signed GitHub event appear in the correct factory view live, without browser polling. |

## Pitfalls

- **Do not install an upstream pinned Archon sidecar beside a healthy shared server by default — duplicated runtimes split workflows, auth, databases and operational truth.**
- **Do not infer server workflow support from a stale external CLI — HTTP consumers execute the server's bundled catalog and schema.**
- **Do not migrate Archon to a dashboard database as a UI setup step — it is a production data-plane migration requiring backup, rehearsal and write-path verification.**
- **Do not enable loops, parallelism or timers before one supervised issue completes — automation multiplies unresolved runtime, auth and evidence defects.**
- **Do not equate an accepted dispatch response with a running or successful lap — read back the bound conversation/run and verify persisted events.**
- **Do not call GitHub-only data “observability” until webhook delivery, reconciliation and historical backfill are all defined — each covers a different loss mode.**
- **Do not expose database URLs, Realtime secrets, provider credentials or GitHub tokens to the browser — seal/read data server-side and pass only bounded query results.**
- **Do not let old flat backlog/setup workflows coexist with the deterministic nested setup layer — duplicate control paths create conflicting project authority and drift.**
- **Do not accept managed-block marker counts alone — validate marker order before replacement, because an end marker before its start duplicates prose instead of failing closed.**
