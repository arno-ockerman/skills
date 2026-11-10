# Outreach safety and remote verification

Load this reference when shipping a consent-aware outreach queue backed by Supabase or another hosted relational backend.

## State-transition safety

Treat each transition as a fresh authorization decision:

1. **Enqueue** — validate contact scope, current consent/legal basis, channel suppression, campaign scope, priority, channel, and scheduled timestamp.
2. **Approve** — reload the contact and suppression list; do not trust the eligibility snapshot captured at enqueue.
3. **Mark sent** — reload eligibility again after approval. A consent withdrawal or opt-out between approval and manual sending must block completion.
4. **Suppress** — insert idempotently, then block every matching open queue item and draft. A channel-specific suppression blocks only that channel; a channel-null record blocks all channels.

Keep normal-user suppression permissions append-only. Grant SELECT/INSERT, remove UPDATE/DELETE policies and table privileges, and reserve correction/deletion for an audited service role.

## Local/remote parity

Validate before writes in the service layer so every adapter behaves the same. Cover at least:

- channel enum
- priority enum
- legal-basis enum and any required evidence for an `other` basis
- ISO timestamp parsing
- IANA timezone parsing
- active workspace/coach ownership for contact and campaign
- queue/draft state compatibility

A local acceptance test that accepts values rejected by remote CHECK constraints is not a valid backend-neutral test.

## Draft safety

Until claim screening exists, generate outbound drafts from a neutral fixed template and the recipient's display name only. Do not echo arbitrary campaign propositions, memories, notes, health conditions, objections, interactions, or earnings language. Treat all of those fields as untrusted content, even when entered by the owner.

## Migration verification

After applying a forward-only migration:

1. Read back the migration list and confirm the exact version is present remotely.
2. Query catalog metadata to confirm every new table exists and has RLS enabled.
3. Query policies and `has_table_privilege` for safety-sensitive tables; policy names alone do not prove DELETE is unavailable.
4. Run the application health command through the real remote adapter and confirm all new collections can be read.

For suppression, verify both facts explicitly:

- authenticated users can insert/read;
- authenticated users cannot delete.

## Remote smoke flow

Use a unique marker such as `outreach-smoke-<random>` and exercise the public CLI or API:

1. Create a consenting contact with documented legal basis.
2. Create a campaign with a neutral proposition.
3. Enqueue outreach and assert queue=`pending`, draft=`pending_approval`.
4. Query today's queue in the coach timezone and assert the item is present. Inspect the actual response shape instead of assuming nested keys.
5. Approve the queue item.
6. Change consent to `withdrawn`.
7. Attempt mark-sent and require a non-zero result containing the eligibility reason.
8. Suppress the same contact/channel twice and require the same suppression ID.
9. Never invoke a real transport; this smoke test validates state transitions only.

## Cleanup and proof

Delete temporary activity logs as well as domain rows; smoke actions often create audit records whose foreign keys do not cascade. Delete by exact IDs and the unique marker inside one administrative transaction, then read back counts for:

- contacts
- campaigns
- queue items
- drafts
- suppressions
- campaign events
- activity logs

Completion requires zero rows for every category. Keep cleanup IDs from actual command output; never reconstruct or guess them.