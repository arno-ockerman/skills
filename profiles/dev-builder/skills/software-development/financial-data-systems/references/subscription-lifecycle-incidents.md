# Subscription Lifecycle Incidents

Diagnosing and repairing recurring-subscription incidents where the application and the
payment provider disagree about who is still being billed. The classic shape: a customer
deleted their account (or cancelled in-app) and the provider keeps collecting.

## Why the two sides drift

A recurring subscription is an object at the provider, billed on a schedule the provider
owns. Your database holds a *copy* of its state. Anything that ends a customer
relationship must therefore stop the provider object explicitly, in the same operation:

| Ending path | Must also do |
| --- | --- |
| User cancels in-app | Cancel/replace the provider subscription, then enforce your own entitlement period |
| Tier switch | Cancel the old provider subscription before creating the new one |
| Admin cancel | Same shared helper as the user path — one seam, not two implementations |
| Self-service account deletion | Cancel the provider subscription *and* keep an anonymised billing tombstone |
| Retention purge / idle-account cleanup | Cancel before purging |
| Refund / chargeback | Decide explicitly whether the subscription also ends |

Retention law and billing law point in opposite directions here, and that is exactly how
the bug gets built: "we must keep the invoices for N years" is satisfied by keeping the
`payments`/`subscriptions` rows, so it feels safe to leave the subscription alone. The rows
are the evidence of what was billed; the provider subscription is the *cause of future
billing*. Preserving one and not stopping the other produces indefinite charges.

## Diagnose in this order

1. **Read the deletion/cancellation code path before touching production.** Grep the backend
   for `deleteUser`, `deleteAccount`, `onDelete`, `cancelSubscription`, `deleteMyAccount`.
   Quote the docblock and the relevant lines: an explicit "PRESERVES payments/subscriptions"
   comment with no matching provider `cancel()` call is the root cause, proven, with no
   credentials needed.
2. **Check whether the join from payer to provider survives.** If account deletion
   hard-deletes the profile document, and that document is the only place holding the
   provider customer id next to the e-mail, the link is gone. Note it as a second defect:
   it makes the incident undiscoverable from the application side.
3. **Check whether your reconciler could ever have seen it.** If the sweep starts from a
   query over the very collection the deletion removes, it cannot — the query excludes the
   orphan by construction, so "clean run" means nothing.
4. **Check the webhook's failure mode for a vanished document.** Unconditional writes to a
   deleted document error out, the provider retries the notification, and the retry loop
   never converges. Renewal webhooks are the usual place.
5. Only then go to the provider for live state.

Report steps 1–4 as the answer. They are grounded in the repository and are what the user
actually needs to hear; provider access is a second, optional step (see below).

## Find the subscription when only the payer's e-mail is known

The provider's customer record outlives your account deletion, so the payer's e-mail on the
customer object is the authoritative surviving link:

1. Iterate **every** customer on **every** provider account (a second organisation is easy
   to forget) and match `customer.email` case-insensitively against the payer's address.
2. For each match, list `customerSubscriptions` and `customerPayments` for that customer.
3. Cross-check each subscription id against the preserved `subscriptions` document to
   recover the application user id, tier and any `cancelAtPeriodEnd` flag.
4. Treat `active` **and** `pending` as still-collecting. `canceled`/`completed`/`expired`
   need no action — but verify, do not assume.

Use iteration (paged list endpoints), not a single unpaged fetch; accounts of a few
thousand customers already need paging. Log how many records you scanned per account so a
zero-match result is distinguishable from a failed/partial scan.

## Repair

- Dry-run first: the same code path with a `--apply` flag, printing a table of every
  subscription with status, amount, interval and next charge date. Read-only by default.
- Cancel only what is still collecting, and pass a deterministic idempotency key so a
  re-run cannot double-act (EOL `customerSubscriptions.cancel(id, { customerId,
  idempotencyKey })` is the shape; the same call pattern applies to other providers).
- Treat "already gone" as success, not an error: 404/410 and messages like *not found*,
  *already canceled*, *not active* mean the desired end state already holds.
- **Know your provider's cancellation semantics.** Some providers have no
  `cancelAtPeriodEnd` on the API and end the subscription immediately. If the product
  promises "runs until the end of the paid period", your own application must carry that
  entitlement (`cancelAtPeriodEnd` + next-charge date on the record) while the provider
  object is cancelled right away — otherwise deleting the subscription silently truncates
  a paid period.
- Persist what you did (who, when, which subscription, previous status) in your
  subscription history/audit trail, and merge the cancellation into the preserved rows so
  the reconciliation sweep stops treating it as live.

## After the fix, verify against the provider

1. Re-read the provider subscription and confirm it is no longer `active`/`pending`.
2. Confirm no `nextPaymentDate` remains and no new payment appeared afterwards.
3. Re-run the audit/reconciliation sweep and confirm the payer is no longer reported as a
   live subscription.

A successful API call is not a successful task: read the provider state back.

## Structural fix to propose (never apply silently)

- Cancel the provider subscription inside the account-deletion transaction, before the
  profile is erased, so the erasure cannot succeed while billing continues.
- Replace the deleted profile with an **anonymised billing tombstone** (payer id, provider
  customer ids, subscription ids; no name, address or e-mail) so a future orphan remains
  findable and reconcile-able without retaining personal data.
- Write the tombstone to the **same** document the profile occupied, and treat it as a
  replacement rather than an addition. A merge-less `set` already drops every other field,
  so the profile is gone the moment the tombstone is published; the old "delete the profile"
  step must therefore be skipped on that branch. Leaving it in place is the single easiest
  way to ship a tombstone that never survives: the write succeeds, the delete succeeds, the
  unit tests pass, and the payer is untraceable again. Gate the two branches on one pure
  predicate (does this account hold provider identifiers?), so a paying account keeps the
  tombstone and an account that never touched the provider is still hard-deleted.
- Order the handoff as: cancel at the provider (unguarded — a failure must abort the erasure
  while the profile still exists, so the user can retry) → publish the tombstone → delete
  only the sibling private documents. Never cancel after erasing.
- Make the "could not prove it stopped" case visible on the tombstone (`needsManualCancellation`)
  rather than only in a log line.
- Make every provider webhook's application write existence-tolerant.
- Extend the recurring reconciliation sweep to enumerate orphan candidates *from the
  provider* and flag provider subscriptions with no live application counterpart.
- Verify the tombstone is still there after the flow runs end-to-end. Mocked ordering
  assertions cannot catch a tombstone that is written and immediately deleted; only re-reading
  the document after the real operation can.

Changing deletion/cancellation behaviour touches billing and the privacy contract, so it
goes through the project's product-decision gate (PRD/ADR) rather than being slipped into a
bugfix commit: state which scenario is intended — stop immediately versus honour the paid
period — plus rollout and rollback.

## Operator-script conventions that work

- Keep one-off diagnosis/repair scripts **out of the product repository** and in your own
  tooling directory (for this user: `/opt/data/profiles/dev-builder/tools/`). Repositories
  carry lint gates and review rules for shipped code; a repair script is not shipped code,
  and some sandboxes refuse writes outside the profile root anyway.
- Run them with the product repository as the working directory, and resolve the provider
  SDK from the repo's `node_modules` instead of importing it directly — an ESM script's
  imports resolve relative to the *script file*, so a script outside the repo throws
  `ERR_MODULE_NOT_FOUND` while the same import works from inside it:

  ```js
  import { createRequire } from 'node:module';
  const requireFromRepo = createRequire(resolve(process.cwd(), 'package.json'));
  const { createMollieClient } = requireFromRepo('@mollie/api-client');
  ```

- Read provider keys from the platform's secret manager at runtime (e.g.
  `npx firebase-tools functions:secrets:access <NAME> --project <id>`) rather than writing
  them into files; that call needs an authenticated CLI, so treat a missing login as a
  handoff to the operator, not as a reason to withhold the diagnosis.
- Write the full report to a gitignored `.audit/` file (mode `0600`) and print a compact
  table, so the evidence survives the terminal and can be attached later.
- Never print secret values; print counts, ids and statuses only.
