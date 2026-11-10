# Local CRM capture + follow-up datetime pitfall

Use this when ingesting contact/context notes into a local CLI-backed CRM MVP before the production backend is wired up.

## Pattern

1. Search for an existing contact before adding a new one to avoid duplicates.
2. For each person, capture three layers:
   - contact status/temperature/interest/notes
   - latest interaction summary + next action
   - durable memories for goals, objections, habits, source/referral, and next steps
3. Add an explicit follow-up with due date, action type, reason, and priority.
4. Verify with both aggregate counts and a real user-facing query, e.g. due follow-ups or contact briefing.

## Datetime regression to guard against

Local human-entered follow-up dates may be naive strings such as:

```text
2026-07-16 18:00
```

If the app compares these with timezone-aware `datetime.now(timezone.utc)`, Python raises:

```text
TypeError: can't compare offset-naive and offset-aware datetimes
```

Preferred fix: after `datetime.fromisoformat(...)`, normalize naive datetimes by attaching UTC or the app's chosen default timezone before comparison.

```python
due = datetime.fromisoformat(due_raw.replace("Z", "+00:00"))
if due.tzinfo is None:
    due = due.replace(tzinfo=timezone.utc)
```

## Verification

Add a regression test that creates a follow-up with a naive due date and calls the due-followups command/query. The test should fail before the fix with the TypeError and pass after normalization.
