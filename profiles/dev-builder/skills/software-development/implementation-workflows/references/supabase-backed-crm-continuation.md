# Supabase-backed CRM continuation pattern

Use after a local CRM/context-capture session when the real Personal CRM repo has Supabase configured.

## Trigger
- User asks whether captured CRM data is in Supabase, or asks to continue building Personal CRM after local test-data capture.
- Repo has `.env` with `SUPABASE_URL` and service/secret key, and CLI health reports `backend: supabase-rest`.

## Pattern
1. **Verify the real source of truth first**
   - Prefer the canonical repo path for Personal CRM (`/opt/project/Personal-CRM`) over older context/prototype copies under `/opt/ai-context`.
   - Run the CLI health check from the real repo and inspect backend + counts before answering where data lives.
2. **Do not assume local captures reached Supabase**
   - Search Supabase-backed CLI for one of the provided names.
   - If counts/search return empty, say directly that previous data was local-only, then migrate/create it in Supabase.
3. **Create realistic data through the CLI, not direct table pokes**
   - Add contact with relationship/lifecycle/channel fields when supported.
   - Add latest interaction, durable contact memories, and explicit follow-up for each person.
   - Use Supabase-valid enum values (`customer`, `prospect`, `personal_context`, `preference`, `product_interest`, `promise`, etc.).
   - Use ISO timestamps with timezone for Supabase `timestamptz` fields.
4. **Build the next small CRM capability via TDD**
   - Add/adjust tests first for the workflow gap found during capture.
   - Common next capability: richer contact capture (`relationship_type`, `lifecycle_stage`, `preferred_channel`) before UI work.
   - Preserve local mode tests with `CRM_BACKEND=local` so `.env` does not accidentally make tests hit Supabase.
5. **Verify with real Supabase output**
   - Run `uv run crm health --json` and confirm counts.
   - Run a real `crm briefing search <name> --json` for one migrated person.
   - Run due follow-ups query where relevant.
6. **Commit safe code changes only**
   - Commit source/docs/tests, never secrets or `.env`.

## Pitfalls
- Do not report “in Supabase” just because a previous local CLI operation succeeded.
- Do not keep working in an older mirrored/prototype folder after the canonical Git repo exists.
- Supabase enums are stricter than local JSON; map user-friendly labels like “oud klant” to valid schema values and preserve nuance in notes/memories.
- Human-entered naive datetimes can pass local storage but fail comparisons; normalize naive datetimes before comparing with aware `now()` and cover it with a regression test.
