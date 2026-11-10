---
name: personal-crm-workflows
description: Build and operate conversation-first personal CRM systems with person memory, follow-ups, birthdays, contextual reminders, and AI/Hermes-driven workflows; especially useful for de gebruiker's coaching CRM where Supabase is the backend and dashboards are intentionally deprioritized.
tags:
  - crm
  - reminders
  - supabase
  - coaching
  - hermes
---

# Personal CRM Workflows

Use this skill when building, extending, or operating a personal CRM where the main interface is the AI/CLI rather than a dashboard. The goal is to remember people, last conversations, important context, and next actions, then proactively remind the user.

## Product principle

For de gebruiker's coaching CRM, do **not** default to a dashboard. The MVP is a conversation-first assistant:

1. Add/search/update people quickly.
2. Store durable person context as memories/interactions.
3. Show "where did we leave this person?" in one concise briefing.
4. Create and surface reminders for birthdays, planned follow-ups, and contextual life events.
5. Keep Supabase as source of truth, with multi-tenancy ready from the start.

## Core data model expectations

Prefer these concepts even if concrete table names differ by repository:

- `workspaces` / tenants: future-proof multi-coach usage.
- `coaches` or `users`: owner of contacts and reminders.
- `contacts`: person identity, lifecycle stage, relationship type, preferred channel, optional birthday metadata.
- `interactions`: dated conversation/activity log.
- `memories`: durable facts about the person, goals, blockers, family context, interests, objections, product history.
- `follow_ups` / reminders: due date, status, reason, contact link, optional priority/context.

## Implementation pattern

1. Resolve and inspect the existing canonical repository before creating plans, notes, schemas, or code elsewhere. For de gebruiker, extend the `Personal-CRM` GitHub repository and its Supabase backend; do not create a parallel outreach/CRM project unless he explicitly asks for one.
2. Inspect the existing CLI, services, migrations, tests, git status, and remote before changing schema or behavior. Preserve unrelated uncommitted changes and add forward-only migrations rather than rewriting applied migrations.
3. Preserve a no-dashboard path: implement CLI/API commands first, then optional UI later.
4. Add or update backend-neutral service functions and both local-test and Supabase store mappings; a feature that works only in local JSON mode is incomplete.
5. Test through the public CLI seam in vertical TDD slices. Include acceptance tests for the actual user flow:
   - add contact
   - add interaction/memory
   - search contact
   - get briefing/last context
   - create/update follow-up
   - list reminders for today
   - prove every open follow-up due before or on today appears in the daily briefing, while future, completed, cancelled, and snoozed items do not
6. Run the full test suite, then exercise the real CLI against the configured backend when credentials are present. After a schema change, apply the migration and read back the exact tables/records before claiming completion; otherwise state the backend limitation clearly.
7. Commit only after tests, migration verification, and the real command smoke test pass; stage only files belonging to the feature when unrelated work is present.

## Outreach copilot extension

When adding lead generation or outreach, build it inside the CRM so contact memory, consent, interactions, and follow-ups remain one source of truth.

1. Model campaigns, lead provenance/legal basis, an outreach queue, message drafts, suppression, and campaign events as workspace/coach-scoped data.
2. Default to human-in-the-loop: generate a draft and queue item, but never send a first message automatically. Use explicit states such as `pending`, `approved`, `blocked`, and `sent` so approval cannot be inferred from scheduling.
3. Re-evaluate eligibility independently at enqueue, approval, and mark-sent. Block declined/withdrawn consent, matching suppression, and missing acceptable legal basis at every transition; approval is not durable permission because circumstances can change while an item waits.
4. Validate channels, priorities, legal bases, scheduled timestamps, timezone names, and workspace/coach ownership in the service layer before the first write. Do not rely on database constraints alone, because local JSON mode must reject the same inputs as Supabase.
5. Make suppression channel-aware, immediately block matching open queue items/drafts, and make repeated suppression idempotent so a unique index cannot turn a safety action into an error. Treat suppression as append-only for normal authenticated users: allow read/insert, reserve deletion for an audited administrative/service role.
6. Log a sent interaction and optional follow-up only after the user confirms manual sending. Approval alone must never create a sent interaction.
7. Keep deterministic draft generation as the dependency-free MVP, but never interpolate raw propositions, memories, objections, health details, or earnings language into outbound copy. Use a neutral safe template until claim screening exists; add LLM generation only after approval and suppression gates are proven.
8. Make daily queues timezone-aware with an explicit coach timezone and quarantine or omit malformed scheduled timestamps instead of treating parse failures as due today.
9. Keep multi-record transitions atomic. Prefer a database RPC/transaction for queue+draft approval and sent+interaction+event+follow-up; if the adapter cannot transact, implement compensating rollback and test injected failures so partial state cannot masquerade as success.
10. Test at least the complete happy path plus missing legal basis, withdrawn consent after approval, suppression before approval, channel-specific suppression, repeated suppression, future enqueue after suppression, invalid enums/timestamps, malformed stored dates, local/Supabase parity, and failure atomicity.
11. After migration, run a real remote smoke flow that creates a uniquely marked contact/campaign, checks pending → today → approved, withdraws consent, proves mark-sent is blocked, proves repeated suppression is idempotent, and then deletes every temporary row and activity log. Read back zero residual rows before declaring completion.

For Belgian consumer-oriented coaching outreach, use opt-in or another documented applicable basis and keep evidence/provenance. General B2B addresses and existing-customer cases are distinct exceptions; do not treat a personal work address as a general company inbox.

See `references/outreach-safety-and-remote-verification.md` for the reusable migration, RLS, smoke-test, and cleanup recipe.

## Role-specific Hermes profile integration

When de gebruiker wants a business/persona profile (for example `herbalife-business`) to use the Personal CRM, treat this as a profile-level workflow integration, not a separate CRM fork:

1. Update the role profile's `SOUL.md` with a concise Personal CRM section: source-of-truth repo path, CLI path, and the expected workflows (`contacts add/search/update`, `briefing`, `interactions`, `memories`, `followups`, `reminders`).
2. Keep the CRM data source shared unless the user explicitly asks for isolation. The strategist should operate the same Supabase-backed CRM so daily DM planning and follow-up context stay in one place.
3. Verify access with a real smoke test from the CRM CLI (for example `crm health` and a small search) before claiming the profile can use it.
4. Tell the user to start a fresh session or `/reset` the role profile so persona changes are loaded.
5. If reminders should belong operationally to the role profile, move or recreate the Hermes cron job under that profile; otherwise it is acceptable for a dev-builder job to send reminders from the same CRM data.

See `references/role-profile-crm-integration.md` for the session-derived checklist and wording pattern.

## Reminder behavior

Daily reminders should be useful and non-spammy:

- Define “today” operationally as every actionable open item with `due_at <= end of today` in the coach timezone, not only items whose due date equals today. Otherwise missed follow-ups disappear permanently after midnight.
- Reconcile the daily reminder output against the canonical open/due follow-up query during smoke tests; a healthy database plus an empty reminder list is not proof that nothing is due.
- Send only when there is something actionable.
- Include contact name, reason, due date/date context, and 2–3 relevant memories.
- Birthday reminders should not need a separate scheduled item if birthday metadata exists.
- Contextual life-event reminders should preserve the human wording: e.g. "vriendin ging bevallen in juli — vraag hoe het gaat".
- If using Hermes cron, make the prompt/script self-contained because cron runs in a fresh session.
- Prefer a script that stays silent on empty output; non-empty stdout becomes the reminder message.

## Commands to look for or add

Useful CLI surface for this class of CRM:

```bash
crm contacts add --name "..." --relationship-type prospect --lifecycle-stage lead --preferred-channel whatsapp --birthday YYYY-MM-DD
crm contacts search "name or context"
crm contacts update <contact_id> --birthday YYYY-MM-DD --preferred-channel whatsapp --notes "..."
crm interactions add <contact_id> --summary "..."
crm followups add <contact_id> --due-date YYYY-MM-DD --reason "..."
crm reminders today
```

Exact flags may differ; inspect the repo first.

## Pitfalls

- Do not treat "CRM" as "build a dashboard" unless the user explicitly asks. For this workflow, reminders + person memory are the product.
- Do not store birthdays only as one-off follow-ups; make them recurring via birthday metadata when possible.
- Watch timezone handling. Supabase timestamps may be naive or aware; normalize before comparing to the coach's end-of-day boundary.
- Never filter a daily action list to exact-date equality; include overdue open work so temporary missed runs cannot hide obligations.
- Avoid stale session-specific memories in persistent memory. Store reusable workflow here; store active CRM data in Supabase or the project source-of-truth.
- When creating cron reminders, verify both the script and the scheduler registration. A cron job without a working script is not done.

## References

- `references/herbalife-coaching-crm-reminders.md` — session-derived reference for de gebruiker's Supabase-backed coaching CRM MVP and reminder implementation pattern.
