# Hosted backend CLI bootstrap pattern

Use this when a user provides a hosted backend project URL/ref plus the credentials needed to finish setup while they are away. The goal is a working remote-backed MVP, not just docs.

## Pattern

1. **Keep secrets local**
   - Put service tokens, DB passwords, API keys, and generated temporary passwords in the project `.env` only.
   - Verify `.env` is ignored before committing.
   - Never echo secrets into logs or final summaries.

2. **Link the local project to the remote backend**
   - Use the provider CLI to init/link the local repo to the remote project.
   - Prefer official migration folders and migration commands over ad-hoc SQL execution so future state is reproducible.

3. **Convert planned schema into migrations**
   - Split into deterministic migrations: initial schema, RLS/security, seed/workspace data, auth linkage, API grants/exposure config.
   - Push migrations to remote and verify the remote migration table/state matches local.

4. **Seed only stable bootstrap records**
   - Create workspace/tenant, owner/coach/admin profile, and agent/system records when the product needs them.
   - Avoid leaving throwaway acceptance-test rows unless the user explicitly approves real test data in production.

5. **Bridge auth and app identity**
   - If the app has its own profile table, create or find the hosted-auth user and link its UUID to the app profile.
   - Store generated temporary passwords only in `.env`; recommend reset-password flow for the user.

6. **Expose API safely**
   - If using PostgREST/Supabase-style APIs, confirm the custom schema is exposed in config and grant usage/select/insert/update/delete as appropriate to the intended roles.
   - Treat `permission denied for schema ...` as a grants/exposed-schema/config issue first, not an application-code issue.

7. **Implement a swappable backend adapter**
   - Keep the local/mock store and remote store behind the same service interface.
   - Select backend by environment variable so tests can run locally while real CLI commands can hit the hosted backend.

8. **Verify with real commands**
   - Run unit tests against the local backend.
   - Run a non-destructive health/whoami/counts command against the remote backend.
   - Only run destructive/write acceptance flows when the user approved real data writes.

9. **Commit only safe artifacts**
   - Commit migrations, config, adapter code, tests, docs/runbook.
   - Do not commit `.env`, generated credentials, or local CLI auth cache.

## Final report shape

- What was linked/configured
- Which migrations were applied and how verified
- Which bootstrap records were created, with non-secret IDs
- Which commands/tests passed with real output
- What was intentionally not done, e.g. no real test contact left behind
- The pushed commit/branch if applicable
