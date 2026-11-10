# Role Profile CRM Integration

Use this when de gebruiker wants a role-specific Hermes profile/persona (for example the Herbalife strategist) to work with the shared Personal CRM.

## Context

The Personal CRM is not a dashboard project. It is the operating memory for daily follow-up: DM planning, people search, briefings, last conversation context, next steps, birthdays, and proactive reminders.

For Herbalife/business coaching, the role profile is often the natural daily conversation partner, so the CRM should be available there too.

## Checklist

1. Confirm the target role profile name and its profile directory.
2. Add a short `## Personal CRM` section to that profile's `SOUL.md`:
   - source-of-truth repo path: `/opt/project/Personal-CRM`
   - CLI path: `/opt/project/Personal-CRM/cli`
   - workflows: add/search/update contacts, add interactions, add memories, add/list follow-ups, generate briefings, check reminders
   - product stance: no dashboard; value is person memory + proactive follow-up
3. Keep the CRM data shared unless de gebruiker explicitly asks for a separate tenant/store.
4. Smoke test the shared CLI before claiming success:
   - `uv run crm health`
   - `uv run crm contacts search <known-name>`
5. Remind de gebruiker that an already-open role-profile chat needs `/reset` or a new session to pick up the modified persona.
6. Decide cron ownership:
   - If reminders just need to reach de gebruiker, an existing dev-builder cron job using the shared CRM data is fine.
   - If reminders should be framed and operated by the strategist, recreate/move the job under the role profile with a self-contained prompt/script.

## Suggested SOUL.md wording

```md
## Personal CRM
- Gebruik de Personal CRM als praktisch opvolgsysteem voor Herbalife-contacten, klanten, oud-klanten en prospects.
- Source-of-truth code: `/opt/project/Personal-CRM`.
- CLI-pad: `/opt/project/Personal-CRM/cli`.
- Gebruik de CRM om personen toe te voegen, op te zoeken, briefings te maken, interacties vast te leggen, memories toe te voegen en follow-ups/reminders te plannen.
- Denk vanuit daily business rhythm: DM's sturen, opvolging doen, afspraken plannen, klanten heractiveren en context onthouden per persoon.
- Als de gebruiker vraagt “waar stond ik met X?”, haal dan de CRM-briefing op en geef: laatste context, open volgende stap, voorgesteld bericht en prioriteit.
- Als de gebruiker nieuwe info deelt over een persoon, sla die praktisch op als contact, interaction, memory en/of follow-up waar zinvol.
- Belangrijk: geen dashboard nodig; de waarde zit in person memory, zoekfunctie, briefings en proactieve reminders.
```

## Pitfalls

- Do not create a second CRM dataset just because a second Hermes profile needs access.
- Do not only update memory; profile behavior should be embedded in `SOUL.md` so the role agent starts with the workflow.
- Do not claim the role profile can access the CRM without a real CLI smoke test.
- Do not forget session reload/reset after persona edits.
