# Archon SDLC pack: the issue-planning → ship intake path

Use when de gebruiker asks which Cole Medin workflow/skill creates GitHub issues so `archon-ship` (or `archon-lifecycle`) can pick them up.

## The answer in one line

`archon-backlog` slices a PRD into an ordered GitHub backlog; `archon-ship` then takes each issue to a reviewed PR (ship runs its own `archon-triage` first). Issues are never created by `ship` or `plan`.

## Where the files live

- Repo: `coleam00/Archon`, directory `.archon/workflows/sdlc/backlog/`
- Not on `main` — present on branch `cleanup/sdlc-workflows-only` and in the integration revision pinned by the factory: `24796870605b0fd576734b79a8d5c781f2b1c1e1`
- Consumer repo: `coleam00/ai-software-factory` (`template/factory/pack.json` holds the pin + workflow entry list)

Fetch a pack file without cloning:

```bash
SHA=24796870605b0fd576734b79a8d5c781f2b1c1e1
curl -s "https://api.github.com/repos/coleam00/Archon/contents/.archon/workflows/sdlc?ref=$SHA"   # dir listing
curl -s "https://raw.githubusercontent.com/coleam00/Archon/$SHA/.archon/workflows/sdlc/backlog/archon-backlog.yaml"
```

`main` returns 404 for these paths — do not conclude the workflow was removed; check the branch/pin.

## archon-backlog shape

`model: large`, `interactive: true`, `mutates_checkout: false`. Inputs: `prd` (path inside the checkout, required), `publication` (`preview` default | `approve` | `auto`), `max_issues` (default 12). Returns `publish`.

Nodes: `read-prd` (uv script) → `slice` (the one judgment node, large tier, writes `backlog.json`) → `check` (uv script: rejects duplicate keys, forward dependencies, a first ticket with dependencies, count over bound) → `authorize` (native approval only when `publication == 'approve'` and count > 0) → `publish` (medium tier, `gh issue create`).

Contract rules that make the output `ship`-able:

- Every ticket body must pass triage's contract test on its own: problem, why, why now, desired outcome, invariants, acceptance criteria with exact values. That is why triage routes it `READY` instead of `NEEDS_CONTRACT_WORK`.
- First ticket = smallest runnable, testable increment (library: first API; CLI: one real command; service: one useful request). No invented ports/health endpoints/build-identity when the project does not declare them.
- Idempotent publication: each ticket carries the marker line `<!-- archon-backlog: <key> -->`; the publisher searches open *and* closed issues for that marker before every write, records existing URLs under `existing`, and never posts twice.
- Empty slice (`count == 0`) is a valid success: nothing is published, no approval is asked.
- Ticket bodies get `Depends on: #<n>` lines using numbers created earlier in the same run.

## Full chain

PRD → `archon-backlog` → GitHub issues → (`archon-triage` when run standalone) → `archon-ship` → `archon-deliver` (PR) → `archon-review` / `archon-validate`; optional composition `archon-lifecycle` adds runtime verification, holdout, bounded repair, discoveries, merge queue, deploy.

Automatic lifecycle intake over the backlog needs an explicit `state_labels` mapping from the caller (READY→`archon-ready`, NEEDS_CONTRACT_WORK→`archon-needs-contract`, BLOCKED→`archon-blocked`, NO_ACTION→`archon-close`, DESIGN_FIRST→`archon-design-first`); `publish=true` on triage is what marks an item as touched so the next tick does not select it again.

## Status on de gebruiker's install (verify again before relying on it)

Query the server, not the CLI: `curl -s https://example.com/api/workflows` (25 workflows on the 0.13.2 docker image).

Present (`source: bundled`), full SDLC pack plus loop primitives: `triage`, `investigate`, `plan`, `implement`, `validate`, `review`, `deliver`, `pr`, `ship`, `upkeep`, `simplify`, `intake`, `build-queue`, `merge-queue`, `discoveries`, `attention`, `forge-check`, `worktree-cleanup`, plus `-block` variants. `archon-ship` now exposes `target`, `errors`, `part`, `publish` (default `false`), `pull_request`, and `branch` — `publish` is what lets a scheduled run turn triage's derived labels on unattended.

Absent from the image (unreleased, branch-only): `archon-backlog`, `archon-lifecycle`, `archon-deploy`, `archon-regress`, `archon-verify-runtime`, `archon-verify-runtime-suite`. Consequence: `archon-backlog` (PRD → sliced issues) must be ported into the repo's `.archon/workflows/` as a project workflow (adapt, don't copy — see the port-adaptation pitfall in SKILL.md), and the `archon-lifecycle` composition is replaced by scheduling the bundled queue workflows directly: `intake` → `build-queue` → `merge-queue` → `discoveries`. de gebruiker prefers this thin scheduler over a custom manager workflow.

The `/opt/ai-tools/bin/archon` CLI predates the sdlc pack: its bundled defaults contain no `archon-ship`/`archon-triage`, and its source checkout has no `sdlc/` directory. Consequence: a CLI run only sees the sdlc workflows once they are vendored into the target repo's `.archon/workflows/` — otherwise run them through the server/Web UI. Do not "fix" the absence by upgrading the shared CLI without checking the server/CLI alignment rules.

## Second path that creates issues

`archon-discoveries` revalidates findings from review/implementation runs, dedupes, and can publish them as issues (`publication=preview|approve|auto`). So Cole has two issue-creating workflows: `backlog` (planned work from a product document) and `discoveries` (verified findings from runs).

## Deprecated predecessor

`.archon/workflows/defaults/legacy/archon-create-issue.yaml` (bug reproduction → `gh issue create`, blocks when it cannot reproduce) is deprecated in favour of the sdlc pack, but is still the only bundled workflow that files a bug report with reproduction evidence.

## Local copy

Fetched copy of the backlog pack: `/opt/data/workspace/archon-sdlc-reference/backlog/` (yaml + commands + scripts, pinned revision).
