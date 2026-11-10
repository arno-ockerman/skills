---
name: herbalife-daily-outreach
description: "Daily Herbalife outreach: CRM-driven 5-min message brief."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [herbalife, outreach, crm, followup, cron, accountability]
---

# Herbalife daily outreach loop

## When to Use

Load this when de gebruiker asks about daily outreach, prospecting follow-up, "wie moet ik vandaag berichten", CRM logging of sent messages, new-name intake, or when the `daily-outreach-5min` cron brief needs fixing, retargeting, or debugging.

de gebruiker's prospecting system is follow-up first: the bottleneck is almost never leads, it is the warm names sitting untouched. Every day produces max 2 copy-paste messages pulled from CRM data — never 5, never a fresh pitch to a cold list.

## The system (already wired)

- Script: `/opt/data/profiles/herbalife-business/scripts/outreach_daily.py` — pulls open follow-ups from the Personal CRM and prints name, status/temperature, days overdue, reason, notes, contact_id.
- Cron job `daily-outreach-5min` (id `8ca5d159af66`): `0 8 * * 1-5`, script = `outreach_daily.py`, `deliver: origin`, `enabled_toolsets: []` (text formatting only — no tool calls from the cron run).
- Separate job `daily-lead-accountability` (16:30) collects the day's numbers; do not merge them.

Manage with the cronjob tool (`list` first, never guess ids). Stop a loop by pausing the job, not by deleting data.

## CRM access rules

- Source of truth: `/opt/project/Personal-CRM/cli` (Supabase REST backend).
- `uv` is NOT on PATH: prefix `export PATH=/opt/ai-tools/bin:$PATH`.
- Read: `uv run crm followups due --json`, `uv run crm contacts search <query> --json`, `uv run crm briefing contact <id>`.
- Log a sent message: `uv run crm interactions add --contact <id-of-naam> --type whatsapp --summary "..." --next-action "..."` then `uv run crm followups add --contact <id> --due <ISO date> --reason "..." --priority high`.
- Contacts are addressable by display name or id; the CLI requires a query for `contacts search` (no bare list).

## Daily loop

1. 08:00 brief arrives: 2 messages, longest-overdue first.
2. de gebruiker sends message 1 manually (never auto-send; consent/legal-basis is human-in-the-loop by design).
3. He replies `verstuurd <naam>` → log interaction + schedule the next follow-up (3-7 days out).
4. If he shares new context or a new name, write it into the CRM immediately as contact + memory/follow-up.

## Message rules

- Max 3 sentences, informal Flemish-Dutch, no Herbalife pitch in a re-opening message, exactly one question at the end.
- Reference the CRM notes so it reads personal (training goal, budget, weekmenu, kids, etc.).
- Only names that exist in the CRM output. Never invent a contact.

## Pitfalls

- The cron agent cannot run shell commands (script execution is approval-gated with no user present) — keep `enabled_toolsets: []` and put all data collection in the pre-run script.
- Pre-run scripts run from the scheduler, so they may use `uv`; the agent itself must not.
- System clock can be ahead of the session header date — always `date -u` before writing dated content.
- Delivering a test run to `origin` spams the DM; test with `deliver: local`, read `cron/output/<job_id>/<timestamp>.md`, then switch delivery to `origin`.
