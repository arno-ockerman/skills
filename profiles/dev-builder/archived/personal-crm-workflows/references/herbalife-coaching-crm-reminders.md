# Herbalife Coaching CRM Reminders

Session-derived reference for de gebruiker's Personal CRM direction.

## Product direction

de gebruiker explicitly prefers **no dashboard** for the CRM MVP. The valuable product is a conversation-first assistant that can:

- keep people and relationship context;
- answer where the last conversation ended;
- remember next steps;
- proactively remind him about birthdays, planned follow-ups, and personal context;
- support coaching/business duplication later through multi-tenancy.

Supabase is the desired backend so the system can later become agent-driven and support multiple coaches.

## Example contact/context shape

Representative data captured in the CRM:

- Aaron Vanmeerhaeghe: old customer, wants to restart products; currently footballs and cycles a lot; wants to become professional; follow up with concrete start plan.
- Aaron Vandroogenbroeck: old customer, wants to restart sport/products; has financial difficulty around 65 EUR/week and needs better choices.
- Laurence Noppe: customer restarting with a new order; needs plan, week menus, structure, breakfast shake, arm exercises, monthly weight goal around -3 kg first month.
- Mathieu Kestelyn: old customer, trains roughly every two weeks but has not restarted products; use body scan and explain products after HYROX/sports session.
- Sven, reference from Mathieu: prospect, joins club training every two weeks, cycles a lot, nutrition can improve but he does not fully see it yet.

Keep this kind of context as person memories/interactions, not as assistant memory.

## Implementation notes that worked

- Build CLI/service commands first, not dashboard screens.
- Add/update commands should accept relationship/lifecycle/preferred channel/birthday fields so the assistant can maintain CRM data without manual DB edits.
- A `reminders today` command should combine due follow-ups and birthday metadata.
- Daily Hermes reminder job can run hourly while the script itself gates to a target local hour, e.g. 08:00 Europe/Brussels, and remains silent when there are no reminders.
- For manual testing, include an override such as `CRM_REMINDER_FORCE=1` so the reminder script can be exercised outside the scheduled hour.

## Verification checklist

Before saying the CRM reminder workflow is done:

1. Run unit/acceptance tests for CLI flows.
2. Run `crm reminders today` against the configured backend or state why backend execution is blocked.
3. Verify the cron/script path is correct for Hermes jobs.
4. Confirm the script produces no output when no reminders are due.
5. Confirm non-empty reminder output contains contact name, action, and relevant context.

## Avoid capturing

Do not save PR numbers, commit SHAs, today's exact job IDs, or one-off contact update progress into this skill. Those belong in git/Supabase/session history, not procedural memory.
