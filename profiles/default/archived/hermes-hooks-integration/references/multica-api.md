# Multica self-host — API & deploy reference

Condensed from the multica-ai/multica repo (server Go source) and self-host docs,
researched 2026-09-09 for de gebruiker's board integration.

## Architecture

Three Docker images (self-host compose):
- `pgvector/pgvector:pg17` — PostgreSQL (data store).
- `ghcr.io/multica-ai/multica-backend:latest` — Go REST API + WebSocket server (port 8080).
- `ghcr.io/multica-ai/multica-web:latest` — Next.js frontend (port 3000).

Runs migrations on backend startup. Health: `GET /readyz` → `{"status":"ok","checks":{"db":"ok","migrations":"ok"}}`.

## Auth

- Human login: `POST /auth/send-code` (email), then `POST /auth/verify-code` → JWT.
  Self-host without `RESEND_API_KEY`: the verification code prints to the backend
  container logs (`[DEV] Verification code for ...`).
- **Bridge auth — Personal Access Token:** `POST /api/tokens` body `{"name":"...","expires_in_days":90}`
  → `{"token":"..."}` (default 90-day lifetime). Use as `Authorization: Bearer <PAT>`.

## Workspace scoping

Requests are workspace-scoped. Resolve order (from middleware `ResolveWorkspaceIDFromRequest`):
`X-Actor-Source: task_token` (bound), context, then `X-Workspace-Slug` header,
then `workspace_slug` query, then `X-Workspace-ID` header, then `workspace_id` query.
Simplest for a script: set `X-Workspace-Slug: <slug>`.

## Endpoints used by the bridge

- `GET  /api/workspaces` — list workspaces (`id`, `slug`, `name`).
- `GET  /api/projects` — list projects (workspace-scoped) → `id`, `title`.
- `POST /api/projects` — create a project (`{"title":"..."}`).
- `POST /api/issues` — create. Body `CreateIssueRequest`:
  `title` (required), `description`, `status` (default `todo`), `priority` (default `none`),
  `project_id` (uuid, optional), `label_ids`, `parent_issue_id`, `assignee_type`/`assignee_id`,
  `start_date`/`due_date`, `allow_duplicate`.
- `PUT  /api/issues/{id}` — update. Body `UpdateIssueRequest`: `status`, `title`, `title_base`,
  `description`, `priority`, `project_id`, `position`, `expected_revision`, etc. All pointer fields.
- `GET  /api/issues` — list (paged; supports `status:` filter, `page`/`limit`).

## Status values

Built-in catalog: `backlog`, `todo`, `in_progress`, `done`, `cancelled`, `verified`.
The Hermes bridge maps: task given → `in_progress`, working → `in_progress`, finished → `done`.

## TrueNAS SCALE deploy (Custom App)

Paste a compose into Apps → Custom App (de gebruiker's pattern; see
`ProductivityCenter/Projects/truenas/multica/` for the committed files):

- Bind-mount data under `/mnt/HomeNAS/appdata/multica/{pgdata,uploads}` (host paths, not named volumes).
- Publish ports `8080:8080` (backend) and `3000:3000` (frontend) on the LAN host.
- Required env: `JWT_SECRET` (`openssl rand -hex 32`), `POSTGRES_PASSWORD`,
  `DATABASE_URL=postgres://multica:<pw>@postgres:5432/multica?sslmode=disable`,
  `FRONTEND_ORIGIN`/`MULTICA_APP_URL` = the public app origin, `APP_ENV=production`.
- Login first run: dev code from backend logs (no Resend needed); add `RESEND_API_KEY` later.
- For a public domain, front with a reverse proxy (Cloudflare Zero Trust, like de gebruiker's
  `example.com`) — don't bind the raw ports to 0.0.0.0 publicly.

## Two integration directions (don't confuse them)

1. **Hermes → Multica** (this project): Hermes hooks create/update issues; Multica is a passive board mirroring Hermes activity.
2. **Multica → Hermes**: Multica natively lists `hermes` as a supported agent CLI; its daemon detects the `hermes` binary and drives it (assign an issue to a Hermes agent, Multica runs it). That's the reverse flow — de gebruiker chose direction 1.
