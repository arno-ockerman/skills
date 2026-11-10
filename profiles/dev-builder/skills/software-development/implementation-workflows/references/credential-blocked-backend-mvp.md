# Credential-blocked backend MVP pattern

Use when the user wants rapid product progress but the real backend/project credentials are not available yet.

## Pattern

1. Keep the planned production schema/config as the source of truth.
2. Build the first user-facing access layer against a deterministic local adapter, not mocks hidden inside tests.
   - Example: CLI commands backed by a local JSON store.
   - Same command/service boundary should later switch to Supabase/Postgres/API without changing the UX.
3. Add a seed/setup artifact for the future production backend.
   - Example: `schema/003_seed_<workspace>.sql` with placeholders and a query that returns IDs for env vars.
4. Add a runbook that says exactly what to do once credentials exist.
5. Verify with an acceptance flow that exercises the real user path end-to-end in local mode.
6. Commit/push the working scaffold so the project is ready to connect when credentials arrive.

## Good acceptance flow shape

For CRM-like products:

- create entity
- add event/interaction
- add durable facts/memories
- schedule next action/follow-up
- retrieve a briefing/summary that proves the earlier writes are usable

## Pitfalls

- Do not stop at schema/docs if the user asks what can be done before they return; build a runnable local artifact.
- Do not fabricate backend verification when credentials are unavailable. Say what was verified locally and what remains credential-blocked.
- Avoid a throwaway prototype that must be deleted later. The adapter can be temporary, but the CLI/service boundary should be reusable.
- Ignore local generated artifacts (`.venv`, caches, local JSON stores) before committing.
