---
name: plan-create-stories
description: Use when a PRD must become GitHub or Jira tickets, or when an epic's sibling issues need a contract check before they go to the factory.
argument-hint: <prd-path> --platform <jira|github> [--project KEY] [--epic KEY] [--milestone NAME]
---

# Create Stories: PRD → Ticket Backlog

## Overview

Turn a finished PRD into a backlog of small, well-formed tickets. Each
Implementation Phase in the PRD becomes a group of tickets; each User Story
becomes one or more tickets with explicit acceptance criteria.

This skill is platform-agnostic by design — the **`--platform` flag** decides
whether the backlog lands in Jira or in GitHub Issues. Everything before that
flag (reading the PRD, decomposing it, writing acceptance criteria) is
identical.

## Arguments

| Argument | Required | Meaning |
|----------|----------|---------|
| `<prd-path>` | yes | Path to the PRD produced by `plan-create-prd` |
| `--platform` | yes | `jira` or `github` — where the tickets are created |
| `--project` | jira only | Jira project key (e.g. `HELP`) |
| `--epic` | jira only | Jira epic key to parent the tickets under (e.g. `HELP-1`) |
| `--milestone` | github only | optional GitHub milestone to attach issues to |

If `--platform` is missing, **stop and ask** — do not guess.

## Workflow

### 1. Read and decompose the PRD
- Read `<prd-path>` in full.
- Walk the **Implementation Phases** section. Each phase is a ticket group.
- Walk the **User Stories** section. Each story maps to one ticket (split if it
  hides more than ~a day of work).
- For every ticket, draft:
  - **Title** — imperative, specific (`Add token refresh endpoint`, not `Auth`).
  - **Description** — what and why, linked back to the PRD phase.
  - **Acceptance criteria** — a checklist a reviewer can verify.
  - **Phase label** — which PRD phase it belongs to.
- Keep tickets small. A ticket that can't be described in one screen is two
  tickets.

### 2. Epic contract check (sibling issues together)
Siblings that contradict each other cost far more in a factory run than here.
Read every issue of the epic **together** (the new drafts plus any existing
children from the epic's task list or sub-issues, bodies and comments, via
`gh issue view <n> --comments`) and look for:

- **Field names and shapes**: one concept named twice (`documentIds` vs
  `documents`), or a field one issue reads that no sibling writes.
- **Status domains / enums**: a value one issue uses that the owning issue does
  not define.
- **Ownership**: two issues create or migrate the same collection, rule block,
  callable or file; or nobody owns something several issues read.
- **Order**: an issue needs something only a later issue delivers, without a
  `Depends on`.
- **Decisions**: a ticket contradicts the epic's decision table (an epic
  comment or the one decision doc it names).

Output a short table: conflict | issues | proposed fix | who decides. No
conflicts: one line, `No contract conflicts across #a, #b, #c.`

- A conflict that needs a product decision becomes an **owner question on the
  epic**. Never resolve it by silently editing a ticket.
- A ticket with an open conflict is not ready: do not create it as ready, and
  do not let it get `factory-ready` (see `prd-to-ship-pipeline` step 3).
- Re-run whenever a sibling is added or edited.
- **Budget:** issue texts only, no repo walk, no code reads. Target under 20k
  tokens (Elevate #76 with 12 children, bodies and comments: about 9k).

**Worked example** (Elevate epic #76, original issue texts, checked by hand):

| Conflict | Issues | Proposed fix | Who decides |
|---|---|---|---|
| #77's seed import writes library documents with no file and status `to-produce`; #78 defines `status` as `active / retired` only | #77, #78 | Add a no-file status to the record, or drop no-file docs from the seed | Owner (product) |
| #78 requires `files.nl`; #77 imports documents with no file yet | #77, #78 | Make `files` optional until the doc is active | Owner (same question) |
| Both create `library_documents`: #77's seed import and #78's "create" | #77, #78 | Name one owner of the record and its types | Owner |
| #77's course manager authors `documentIds` but no issue gives admins a read path; rules live in #78 | #77, #78 | Give #77 an admin read path, or order #78 first | Owner |
| #78 serves files only for unlocked modules (#79) but has no `Depends on #79` | #78, #79 | Add the dependency or defer that check | Planner |

The first row is the one Archon found in the factory, at a cost of two triages
(about 1.5M tokens) and a 25-minute wait; the owner's ruling (D22) settled
rows 1 to 4.

### 3. Confirm the plan before creating anything
Print the proposed ticket list (titles + phase grouping), the contract check
result and the target platform. This is the checkpoint: creating real tickets
is not reversible in one click.

### 4. Create the tickets: branch on `--platform`

**`--platform jira`:**
- Use the Atlassian MCP server.
- Create each ticket under `--epic` in `--project`.
- Map: PRD phase → a label or the epic; acceptance criteria → the description.
- Capture each created issue key.

**`--platform github`:**
- Use the `gh` CLI: `gh issue create --title "..." --body "..." [--label phase-N] [--milestone "..."]`.
- Put acceptance criteria in the issue body as a markdown checklist.
- Apply a `phase-N` label per PRD phase (create the label if missing with
  `gh label create`).
- Capture each created issue number/URL.

### 5. Report
- A table: ticket title → phase → created key/number/URL.
- The PRD path the backlog was generated from.
- Next step: each phase is now ready to run as a PIV loop.

## Quality Checks

- ✅ Every ticket traces back to a PRD phase or user story
- ✅ Every ticket has verifiable acceptance criteria
- ✅ Tickets are small (≤ ~1 day of work)
- ✅ The correct platform was used and every create succeeded
- ✅ The epic contract check ran and every conflict is fixed or asked on the epic
- ✅ Phase grouping is preserved (labels/epic) so the backlog stays navigable

## Notes

- Greenfield vs brownfield changes the PRD's *scope* (MVP vs next epic), not
  this skill — `plan-create-stories` runs the same either way.
- Never create tickets without the step-3 confirmation.
- If a phase is too vague to decompose, stop and flag it — that's a PRD gap,
  not a ticket-writing problem.
