---
name: multica-operations
description: "Use when creating or updating Multica projects and todos."
---

# Multica Operations

Multica is de gebruiker's personal board (issues grouped by project/status), self-hosted on TrueNAS on the AI-tools stack. Hermes writes to it over an HTTP API; a cron (`multica-sync.py`) mirrors the board into `/opt/ai-context/ProductivityCenter/Multica-Board.md`. This skill is how to read and write that board directly from a session (create projects, add todos/issues, update statuses, sync the mirror).

## Where the pieces live

- Config: `/opt/ai-tools/config/multica/config.json` — `api_url` (e.g. `http://<host>:8080`), `workspace_slug`, `fallback_project`, alias map `projects`.
- Token: `/opt/ai-tools/config/multica/token` (0600). Read it from the file in code; NEVER print or echo it.
- Bridge: `/opt/ai-tools/bin/multica-bridge.py` (Hermes session hooks auto-create/update an issue per session; `discover` subcommand lists workspaces+projects).
- Sync: `/opt/ai-tools/bin/multica-sync.py` writes the board mirror to `ProductivityCenter/Multica-Board.md`. Run it after creating issues so the vault board reflects them.
- Status values a task may take: `backlog`, `todo`, `in_progress`, `done`, `cancelled`, `verified`.

## Procedure: create a project + todos

Do this in one Python step via `urllib` (reuse the bridge's HTTP pattern), always idempotent so a re-run does not duplicate:

1. Load config + token; set header `Authorization: Bearer <token>`, `Content-Type: application/json`, `X-Workspace-Slug: <workspace_slug>`.
2. `GET /api/projects` → find project by normalized title (lowercase, no spaces). If missing, `POST /api/projects` with `{"title": ...}` → returns `id`. Reuse a project that exists — never create a duplicate.
3. `GET /api/issues?limit=200` → collect existing titles, normalized, to dedupe.
4. For each desired todo not already present, `POST /api/issues` with `{"title", "status", "project_id", "description"}`. Capture the returned `identifier` (e.g. `ARNO-85`) for the handoff.
5. Run `multica-sync.py` so the vault board mirror shows the new issues.

Verify by reading back the created ids/identifiers from the POST response; a successful POST is not proof until you report the returned `identifier`.

## Pitfalls

- **Dedupe by normalized title before POST.** Re-running the same script must not create a second copy of a project or issue. Collect existing titles first; skip any whose `title.lower()` (spaces stripped) is already present.
- **Never print the bearer token.** Read it from the file inside the script; print only non-secret results (project id, issue identifiers, counts). The token file may hold a placeholder/comment instead of a real PAT — if the value contains whitespace/newlines or starts with `#`, treat it as unconfigured rather than injecting it into headers.
- **Status values must be exact** (`backlog`/`todo`/`in_progress`/`done`). The sync renderer groups by these; a typo becomes its own board bucket.
- **Empty `/api/issues` may be a list or `{issues: [...]}`; `/api/projects` may be a list or `{projects: [...]}`.** Normalize both before iterating so pagination/response-shape changes don't silently drop rows.
- **The `write_file` tool is blocked outside `HERMES_WRITE_SAFE_ROOT` (`/opt/data`).** Multica docs/board live under `/opt/ai-context`, which is outside that root. To write/update vault files, stage the file under `/opt/data/...` with `write_file`, then `cp` it to the `/opt/ai-context/...` target via the terminal tool. (Also applies to any vault write, not just Multica.)
- **The Hermes session hooks already create a per-session issue** (`multica-bridge.py` on `pre_llm_call`). Do not create a second issue for the same task tracking; use the bridge for session tracking and the manual API route for intentional backlog/todo items.

## Related

The board is part of de gebruiker's source-of-truth vault (`/opt/ai-context/ProductivityCenter/`). Personal-CRM and other ProductivityCenter conventions live under the `personal-crm-workflows` skill; this one is specific to the Multica board/issue API.
