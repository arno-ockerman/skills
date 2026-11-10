# Subscription Invoice Backfills

## When to Use

Use this recipe for a bounded historical period when subscription payments settled but invoices may be missing, stuck mid-issuance, or not delivered. Use the lighter scheduled sweep for ordinary webhook healing; use this exact-window workflow when the first day, invoice date, initial mandate payments or proof of delivery matters.

The goal is not merely to create documents: prove, per provider payment, what was paid, whether one legal invoice exists, how it was delivered, and what still needs human review.

## 1. Map payment kinds before querying

Build the source set from provider payment history and classify each settled payment:

| Payment kind | Typical attribution | Common trap |
| --- | --- | --- |
| Initial mandate/setup payment | customer id + payment metadata + stored first-payment id | It often has no provider subscription id because the subscription is created only after it settles. |
| Recurring renewal | provider subscription id + customer id | A current user subscription id does not cover older tiers or canceled subscriptions. |
| Tier-switch payment | historical subscription id + immutable payment metadata | Looking only at the current profile hides the prior plan. |
| Retry/recovery payment | payment metadata + provider history | Descriptions can look like renewals; never infer identity from text alone. |
| Refund/chargeback | original payment relation | Issuance and correction/credit-note state must be reconciled together. |

Enumerate all provider customers or all provider payments for the receiving account. Do not start from `users where subscriptionStatus == active`: canceled, switched or erased accounts can still have settled payments in the requested window.

## 2. Use exact boundaries

Accept explicit ISO timestamps, for example:

```json
{
  "from": "2026-09-01T00:00:00+02:00",
  "until": "2026-10-19T23:59:59.999+02:00",
  "dryRun": true
}
```

Normalize both to instants once and use the half-open interval `[from, until)` internally. Include the normalized values in the report. Keep `lookbackDays` only for recurring scheduled sweeps; never use it for a historical request whose first day matters because `now - N days` cuts at the current clock time.

## 3. Reconcile issuance and delivery separately

For each paid provider payment, derive both states:

### Issuance state

- `missing`: no invoice claim/document/provider invoice;
- `reserved`: number allocated, external side effect not completed;
- `processing`: recent claim — do not auto-retry;
- `ambiguous`: timeout or stale external claim — operator must check the provider before retrying;
- `issued_local`: local PDF has an invoice number and storage path;
- `issued_provider`: provider invoice id/number recorded;
- `reversed` / `credit_required`: original payment was refunded or charged back.

### Delivery state

- `email_queued`, `email_sent`, `email_failed`;
- `peppol_requested`, `peppol_delivered`, `peppol_failed_or_downgraded`;
- `pdf_ready_no_email`;
- `unknown`.

An invoice document's existence proves neither issuance nor delivery. A missing-invoice sweep may create only `missing` invoices; a resend operation works only on already-issued invoices with a retryable delivery state. Never combine the two actions under one opaque "send all invoices" button.

## 4. Prove the production path is live

Before the first production dry-run, verify the exact reconciliation revision reached the runtime:

1. Confirm the merge commit passed the default-branch CI, not only the pull-request checks.
2. Confirm the deployment workflow for that exact commit ran after CI and inspect its individual steps.
3. Verify the reconciliation callable/job exists in the deployed region before invoking it.
4. If a deployment has a failed aggregate conclusion, do not assume nothing shipped: inspect function, rules, index and storage steps separately. A late permission sentinel can fail the workflow after the function deploy succeeded; conversely, a green build proves nothing about production deployment.
5. Resolve or explicitly record unrelated infrastructure failures before apply, but never run against an older callable merely because the operator script is already on `main`.

Treat source merge, CI success, deployment success and runtime availability as four separate gates.

For serverless runtimes, inventory every environment variable and secret read by the complete reconciliation call graph. Bind that full set at the deployed entry point, keep the names in one shared constant, and add a test that fails when a transitive dependency introduces a new required secret without binding it. This catches failures that happen before per-payment isolation and otherwise surface to clients as a generic internal error.

## 5. Dry-run report

Produce counts and minor-unit totals grouped by:

- seller / provider account;
- payment kind;
- invoice issuance state;
- delivery state;
- recipient language;
- missing email;
- incomplete billing address;
- Peppol eligibility and fallback;
- ambiguous provider claim;
- refund/chargeback correction requirement.

List only stable ids in the durable report (payment id, customer id, subscription id, invoice id); omit names, addresses and e-mails. Show a compact operator table during the run, but save the complete machine-readable result for review.

## 6. Historical date decision

Before apply, show both dates explicitly:

- provider `paidAt` / service-period start;
- proposed invoice issue date.

Many invoice paths assign the issue date at generation time, so a historical payment invoiced today receives today's invoice date even though its service period starts on the original paid date. Do not silently backdate. Require an explicit accounting decision and encode it in the run metadata.

## 7. Apply safely

1. Require an authenticated privileged actor and an explicit confirmation token for apply; default is dry-run. Make the token specific to the side effect rather than accepting a generic truthy flag. Prompt for interactive credentials or use a protected secret source; never place passwords directly in command arguments because process lists and shell history can retain them.
2. Validate billing completeness with the same canonical server-side validator used before checkout. Put incomplete records in a blocked list and never issue them with placeholder buyer data.
3. Build the full cross-customer, cross-account plan before issuing anything, then sort it globally oldest-first. Per-customer sorting still lets a newer payment consume an earlier legal invoice number.
4. Claim by deterministic provider payment id in the application datastore **before** calling an external invoice API; providers may accept duplicate creates even with the same payment reference.
5. Treat only explicit terminal statuses as complete. If a deterministic invoice record already exists in a resumable state such as reserved, processing-before-external-send, provider-failed or PDF-ready-before-delivery, resume it through the normal state machine rather than suppressing it or allocating another record.
6. Issue exactly one invoice under the seller identity belonging to the account that received the money.
7. Choose delivery after issuance: Peppol when valid and enabled, otherwise ordinary email, otherwise record `pdf_ready_no_email` for operator action. Allow a same-invoice e-mail fallback only when the provider explicitly reports delivery capability unavailable (for example e-invoicing disabled or recipient not registered on the network); do not downgrade generic validation errors merely because they share the same HTTP status.
8. On an ambiguous provider outcome, stop automatic retry for that payment and flag it; a timeout can mean the provider issued the invoice.
9. Persist run id, actor, exact boundaries, counts, totals and each payment's final state without personal data.

## 8. Verify

If the apply command exits with a generic client error, do not execute it again immediately. Group structured cloud logs by execution or trace id, then determine whether the failure occurred before planning, inside one isolated payment, or after external issuance while recording the run. Log a sanitized message and stack server-side, return a sanitized reason/code/details to the operator tool, and make the tool warn that partial completion is possible.

- Re-run the same exact window in dry-run before any retry: `missing` must be zero for payments already completed, while resumable deterministic claims may remain planned through the normal state machine.
- Verify provider invoice ids by reading them back where supported.
- Verify delivery independently; do not claim "all sent" from an issuance count.
- Compare the sum of invoiced gross amounts with settled provider payments in the window, then account separately for refunded/charged-back payments.
- Review every `ambiguous`, `email_failed`, `pdf_ready_no_email`, Peppol failure and correction-required row.

## Scheduled sweep versus historical backfill

A scheduled sweep may safely use a generous rolling window (for example two billing cycles) because deterministic payment ids make it idempotent. Its job is to heal missed webhooks, not to implement a precise accounting-period request. Historical backfills require exact timestamps, a dry-run and an approved issue-date policy.