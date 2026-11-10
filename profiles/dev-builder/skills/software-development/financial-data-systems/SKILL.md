---
name: financial-data-systems
description: "Use when auditing payment/subscription billing or reporting."
version: 1.0.0
metadata:
  hermes:
    tags: [software-development, payments, finance, reconciliation, dashboards]
    related_skills: [implementation-workflows, codebase-design, grounded-citations]
---

# Financial Data Systems

## Overview

Use this class-level skill for revenue dashboards, payment reconciliation, cost reporting, transaction ledgers, and historical financial backfills. It applies across providers and stacks: the core problem is not charting, but making every displayed number explainable from immutable source events.

## Workflow

### 1. Define financial semantics before UI

Get explicit decisions for:

- **Actor:** owner-only versus ordinary admins. Enforce this server-side; hiding a tab is not authorization.
- **Time basis:** provider payment date, settlement date, invoice period, or accrual period.
- **Timezone:** calendar month in the business timezone, represented as `[monthStart, nextMonthStart)`.
- **Money view:** gross revenue, refunds/chargebacks, provider fees, operating costs, cash received, and profit are different values.
- **Scope:** enumerate every product stream and every payment account; include `unclassified` rather than guessing.
- **Tax:** never imply tax/accounting correctness unless VAT and recognition rules are explicitly approved.

### 2. Trace current persistence end-to-end

Inspect each payment flow before designing aggregation:

1. payment creation metadata;
2. webhook handling;
3. application-document writes;
4. refunds and chargebacks;
5. payment account routing;
6. invoices and reconciliation jobs;
7. the cancellation and account-deletion pipeline — which code path, if any, stops the provider-side recurring subscription.

For multi-account products, trace one invariant end to end: **the legal invoice seller must be the business whose provider account received the money**. Normalize the destination once, then derive the provider credentials, immutable transaction snapshot, seller key, numbering series, bookkeeping recipient, and invoice-delivery route from that normalized result. Persist the resolved destination and custom account id on the payment or registration before checkout, so later edits to the product cannot change the seller of an existing payment. When connecting a custom provider account, verify the organisation and invoicing capability and create/update its seller identity as one workflow; never leave a selectable payment account without a corresponding complete seller record.

Historical revenue must use the actual provider amount and timestamp or an immutable paid-time snapshot. Never reconstruct history from mutable product configuration such as today's price.

A recurring subscription lives at the provider, not in your database. Every path that ends a customer relationship — user cancel, tier switch, admin cancel, self-service account deletion, retention purge — must stop the provider subscription in the same operation and must leave an anonymised billing tombstone (payer id, provider customer id, provider subscription id; no name, address or e-mail) behind. Publish that tombstone to the same document the profile lived in, but treat it as a **replacement**: a merge-less `set` already drops every other field, so the old "delete the profile" step must be removed for that path, not run after it. Make the two mutually exclusive and let one pure predicate decide, so a paying account keeps the tombstone and an account that never touched the provider is still hard-deleted. See `references/subscription-lifecycle-incidents.md` for the diagnosis and repair runbook.

### 3. Separate legal identity from invoice delivery

Model billing identity and delivery eligibility as distinct decisions:

- Keep country, legal/company name, VAT number, and enterprise/registration number as separate fields. A company can be valid without a VAT number, and an enterprise number must not be silently promoted to a VAT number.
- Normalize identifiers at the boundary, preserve the user's legal value for display where needed, and derive provider recipient type explicitly rather than from one optional field.
- Generate the accounting invoice for every paid subscription that requires one; choose e-mail, Peppol, or another e-invoice rail afterward from verified eligibility.
- Request Peppol only for recipients with the required structured business identity, and persist provider delivery status separately from invoice issuance status.
- Atomically claim an external invoice-delivery side effect before transmission. Separate definitive provider refusals from ambiguous outcomes: an explicit HTTP validation/delivery refusal may release the claim for an approved fallback, but a transport error, unreadable success response, an HTTP 5xx or throttling/timeout status (408/425/429), process crash, or failure to persist the returned provider ID may mean the invoice already exists — a non-2xx response is not proof the create was refused. Persist those cases as an explicit review-required state, propagate a typed/sentinel error through every caller, and block both provider resend and local-PDF fallback. Never age an `issuing` claim into automatic retry; only operator reconciliation may clear it.
- Send a deterministic provider idempotency key, but never rely on it as the only duplicate defense because provider support and retention windows vary.
- Keep provider feature flags and secret wiring out of business eligibility checks. A missing toggle must not silently suppress a legally required invoice or delivery channel.
- For serverless billing functions, bind every secret read anywhere in the transitive call path, not only API keys referenced in the entry file. Centralize the complete secret-name set and test it explicitly; an unbound mode/feature secret can abort reconciliation before per-payment error isolation runs.
- Classify e-invoice fallback from the provider's structured error semantics, never from HTTP status alone. Retry the same claimed invoice through ordinary e-mail only for explicit delivery-capability failures such as disabled e-invoicing or a recipient absent from the network; keep generic validation failures such as an invalid recipient non-retryable.
- Make one structured billing object canonical and use legacy root fields only as fallback. While old readers remain, synchronize or explicitly clear those fields on save so removing a VAT number cannot leave a stale Peppol endpoint behind.
- When billing details are required before the first charge, enforce **field-level completeness server-side before creating the provider payment**; checking only that an address object exists lets partial placeholders pass, and a UI review step is not an authorization boundary. Reuse the same canonical validator in checkout, profile editing and invoice issuance, while allowing the legally valid identity variants the product supports (consumer, company without VAT, company with VAT).
- Keep seller identity separate per receiving account: each account needs its own legal details, invoice prefix/sequence, structured address, bookkeeping destination, and invoicing opt-in. If provider issuance fails and a local PDF fallback is allowed, generate it under that same seller identity; never fall back to the platform owner merely because their configuration is always available.
- Generate UBL line pricing so `PriceAmount / BaseQuantity × InvoicedQuantity = LineExtensionAmount`; when `PriceAmount` is a per-unit value, set `BaseQuantity` to one.
- Compute recurring service periods with calendar clamping, not raw `setMonth` rollover. Derive the clamped next-period start and subtract one day so month-end payments neither overflow nor overlap the next cycle.

Test the routing matrix explicitly: company with VAT/e-invoice eligibility, company with only an enterprise number, consumer/no company identity, malformed identifiers, provider delivery failure, ambiguous provider outcome, concurrent delivery claims, month-end and leap-year periods, multi-unit UBL reconciliation, and retry/idempotency. Assert the exact provider payload and persisted statuses; do not create live invoices during ordinary automated tests.

### 4. Put complexity behind one deep seam

Prefer one server-side report interface:

```ts
getFinanceReport({ monthKey }): Promise<{
  month: FinanceMonthReport;
  previousMonth: FinanceMonthReport;
  sync: FinanceSyncSummary;
  page: FinanceLedgerPage;
}>;
```

The client must not know provider pagination, credentials, account routing, billing-export schemas, collection names, or reconciliation rules.

### 5. Normalize into an idempotent ledger

- Store money as signed integer minor units, never floating point.
- Use deterministic IDs such as `{source}_{account}_{eventType}_{sourceId}`.
- Preserve source ID and immutable occurrence timestamp.
- Separate kinds: income, refund, chargeback, provider fee, expense, adjustment.
- Separate categories: subscription, challenge, event, cloud, other, unclassified.
- Store minimum necessary personal data.
- Correct manual entries through void/replacement with actor and reason; do not erase audit history.

### 6. Backfill with reconciliation, not trust

1. Trace **every payment kind separately** before choosing the source query: initial mandate/setup payment, recurring renewal, tier switch, retry, refund and chargeback. Do not assume an initial subscription payment already has a provider subscription id — the subscription is often created only after that payment settles.
2. Implement provider pagination and explicit `[from, until]` timestamps in the business timezone. A rolling `lookbackDays` window is an operational convenience, not an exact historical boundary: rounding up includes payments from the previous day and rounding down misses the first hours of the requested day.
3. Reconcile from immutable provider customer/payment history, not only the user's current `active` subscription. Preserve each payment's historical subscription identifier, but keep a second attribution route (`customerId`, payment metadata, stored first-payment id) for setup payments that have no subscription id.
4. Separate three predicates in the result: **invoice exists**, **invoice issued**, and **invoice delivered**. Define completion from explicit terminal statuses, not document existence: a stale `reserved`, `processing`, provider-failed or other resumable record must remain eligible for the existing issuance state machine, while an ambiguous external outcome requires operator verification. A missing-invoice sweep must not be presented as a resend tool.
5. Before the production dry-run, prove the exact revision passed default-branch CI, was deployed, and is available in the target runtime. Inspect deployment steps individually rather than trusting only the aggregate workflow conclusion: a late IAM/index sentinel can mark the run failed after functions shipped, while green CI alone proves no deployment occurred. Then run a dry-run with counts and totals per account, grouped by payment kind and delivery state. Include missing email/address, provider-issued vs local-PDF fallback, Peppol eligibility, and ambiguous locks.
6. Before apply, decide the historical invoice-date policy explicitly. Backfill implementations commonly stamp the issue date with "now" while deriving the service period from the original payment date; confirm that accounting treatment instead of silently backdating or pretending both dates are the same.
7. Compare gross, refunds, fees, and unclassified rows to provider reports.
8. Build the complete eligible plan before any issuance side effect. Exclude incomplete billing identities into a blocked report, then sort the remaining plan globally oldest-first; sorting inside each customer/account loop can assign later payments earlier invoice numbers.
9. Apply with deterministic payment-based IDs and provider-side claims held before issuance. Re-enter an existing resumable claim through the normal issuance state machine instead of allocating a second invoice record.
10. If an apply call fails, assume partial completion until disproved. Correlate structured runtime logs by execution/trace id to separate entry-point or secret-binding failures from isolated payment failures; expose a sanitized server reason to the operator CLI, and require a fresh dry-run before any apply retry.
11. Re-run the same exact window to prove idempotency; it must report zero new issues, while delivery retries remain a separate reviewed action.
12. Save a reconciliation report without personal data.

A failed source/account produces a visible `partial` result, never a plausible-looking complete total. See `references/subscription-invoice-backfills.md` for the audit matrix and rollout recipe.

### 7. Treat costs as separate adapters

Application payment records do not reveal infrastructure cost. Model separate adapters for:

- provider balance/transaction data for processing fees;
- cloud billing exports for project/service/SKU costs and credits;
- manual expense entry for MVP and non-API costs.

Enable official cloud billing exports early because historical backfill may be limited. Prefer exports/APIs over scraping provider consoles.

### 8. Roll out in evidence order

1. Approve actor, time basis, scope, tax wording, and net formula.
2. Add pure money/month/report tests.
3. Add the idempotent ledger writer.
4. Dual-write from existing webhooks without changing operational behavior.
5. Add server-authorized report and expense interfaces; deny direct client access.
6. Dry-run and reconcile one known month.
7. Apply the backfill and review every unclassified item.
8. Release the dashboard.
9. Add scheduled current/previous-month reconciliation only after manual sync is proven.

## Required tests

- integer money arithmetic;
- local month and DST boundaries;
- previous-month year rollover;
- duplicate webhook and backfill delivery;
- refunds and chargebacks;
- unknown metadata;
- multi-account routing;
- owner/admin/client authorization;
- partial sync and retry;
- empty month and zero-baseline percentage;
- CSV total equals screen total;
- existing checkout/webhook/invoice regressions;
- invoice routing for company-with-VAT, company-without-VAT, and consumer identities;
- first/setup-payment invoice creation separately from recurring-renewal invoicing;
- server-side rejection of partial billing objects before the first charge, plus acceptance of every supported complete identity variant;
- e-invoice/Peppol request payload, status persistence, failure retry, and no duplicate invoice creation;
- ambiguous provider create outcomes: simulate an accepted request whose response body/connection is lost, assert the claim becomes review-required, and assert every caller blocks both local fallback and automatic provider retry.

## Pitfalls

- Summing current product prices for historical payments.
- Calling gross revenue “profit”.
- Mixing payment and settlement dates silently.
- Omitting unnamed revenue streams or custom accounts.
- Letting any non-empty custom account id override an explicit non-custom payment destination. Derive the seller key from normalized routing and only consume the account id when the normalized destination is custom, because stale denormalized fields otherwise put the wrong legal entity on the invoice.
- Testing only where money is charged in a multi-account flow. Assert the full matrix — destination → provider credential → persisted routing snapshot → seller key → number sequence → delivery/fallback identity — because payment routing can be correct while invoicing silently names another business.
- Treating UI visibility as security.
- Building charts before one month reconciles exactly.
- Blocking a truthful MVP on full cost automation; manual cost entry is a valid first adapter.
- Deleting an application account without stopping the provider-side recurring subscription — the provider bills on its own schedule and has no notion of a deleted app user, so “preserve the billing records for retention” silently becomes indefinite monthly charges.
- Hard-deleting the application document that joins the payer's e-mail to their provider customer id. It is usually the only such join, so once it is gone the subscription is undiscoverable from the application side and can only be found by scanning the provider.
- Starting a reconciliation sweep from an application state filter such as “users where subscriptionStatus == active”, or from a collection the deletion flow removes. A subscriber whose profile was deleted is excluded by the query itself, so the sweep reports a clean run while the mandate keeps collecting: enumerate orphan candidates from the provider too.
- Letting a provider webhook write unconditionally to an application document that may no longer exist. The failed write surfaces as an error, the provider retries the notification, and the retry loop never converges — make those writes existence-tolerant (merge/upsert or a pre-check).
- Blocking on production credentials before reporting a diagnosis that repository code already proves. Read the cancellation, deletion and webhook code paths first, state the root cause with file/line evidence plus a workaround the operator can run in the provider dashboard, and treat credential access as an optional second step.
- Writing an operator/repair script into the product repository when the sandbox only permits writes under your own profile root. Keep it in your profile tooling directory and run it with the repository as the working directory — see `references/subscription-lifecycle-incidents.md`.
- Asserting only the *order* of the tombstone and the profile delete ("tombstone, then delete") instead of their *mutual exclusion*. That test passes while the tombstone is being written and immediately wiped, which is the bug it was supposed to catch. Assert the document survives: one test per branch, plus an explicit "never both" assertion.
- Relying on unit tests alone for a replacement-document migration. The handoff logic can satisfy every mocked ordering assertion and still destroy the record in the real flow; the end-to-end test that re-reads the document after the operation is what proves it. Treat a new integration/e2e failure after a green unit run as the expected case, not an anomaly.
- Assuming a test directory shares the repo's module conventions. A functions/test subtree can be CommonJS while the app is ESM, forbidding `require()`-style imports and requiring `.js` extensions on relative specifiers. Copy the import style of the newest existing test file in that same directory before writing a new one, or the lint gate fails after the push.
- Keeping the tombstone while deleting a sibling private document is correct (the tombstone holds identifiers only), but do not extend that reasoning to documents that carry the payer's name, address or billing details: those must be deleted, not tombstoned.
- Guarding an erasure handoff with an early return on a missing primary record. The guard that skips the *billing* work (no profile means nothing to cancel and no identifiers to tombstone) must not also skip the *personal-data* deletes: an interrupted earlier run reaches exactly that state — primary document gone, private document (IBAN, tax id) still present — and if the account-deletion flow deletes the identity-provider account afterwards, nothing can ever remove the leftover. Skip the billing half only, and attempt every document delete on every path so a failure is reported instead of swallowed.
- Verifying the identity-provider account still exists before deleting the primary record's siblings. If account deletion is the last step and runs unconditionally, any earlier step that silently no-ops becomes an irreversible leak; trace whether a failure actually blocks it.
- Measuring retained billing records with a boolean instead of a query. "The profile has a subscription id" is not "a subscription document is retained": a tier/plan switch leaves older documents behind, older rows may lack the denormalised owner field, and the referenced document may not exist at all. Count the query result and add the referenced document only when it really exists.
- Filtering a subscription-invoice backfill on provider `subscriptionId` alone. The first mandate/setup payment often predates subscription creation and therefore has no such id; attribute it through the customer, payment metadata or the stored `firstPaymentId`, or the first paid period is silently never invoiced.
- Calling any existing invoice document "sent". A document can be only reserved, mid-processing, PDF-only because the email is missing, or issued with delivery unresolved; report and retry issuance and delivery as separate state machines so a missing-invoice sweep cannot hide undelivered invoices.
- Using integer lookback days for a legally scoped date range. The server computes `now - N days`, not local midnight: rounding up sends invoices outside the range and rounding down misses the requested day's morning. Add explicit ISO `from`/`until` plus a dry-run for historical issuance.
- Reusing the ordinary webhook retry rule for invoicing. A payment webhook can safely acknowledge the charge while invoice generation fails non-blockingly, but returning success means the provider will not retry the invoice; pair that flow with a scheduled missing-invoice reconciliation and visible run records.
- Re-running a live backfill after a generic callable error. The request may have issued some invoices before the client saw the failure; inspect correlated runtime logs and run the identical window in dry-run before permitting another apply.
- Treating a code-review bot's inline comments as always current. Each comment carries the commit it was raised against; when the head has moved on, re-check the flagged code before implementing, and verify each suggestion against the actual source. Answer each thread individually — one reply per finding, saying what changed or why it was already fixed — rather than one summary comment.

- Filtering a periodic sweep that reports unresolved/ambiguous claims to a rolling time window. A review-required claim blocks both provider resend and local fallback indefinitely, so a 24-hour (or any rolling) filter means one missed run or failed alert e-mail silently hides the claim from view forever. Report every unresolved claim regardless of age, and keep the sweep a single-field `status` equality query so it needs no composite index — which also lets the alert keep running when the deploy service account lacks index-admin rights.
- Letting the local-fallback reservation path allocate a second invoice when a payment already carries a provider claim. A provider-issued invoice has a provider id but no local structured communication, so a reuse-check keyed on "local invoice number + structured communication" misses it and overwrites the claim with a duplicate local invoice. Guard the fallback by checking for a provider claim (provider invoice id, or an `issuing`/review-required status) before allocating a local one, regardless of the seller's current invoicing-mode flag.
- Reporting a multi-path invoice backfill with a single "created" counter that only increments on one path. When provider e-invoices (Peppol/Mollie) issue on a parallel path to the local-PDF fallback, that counter reads 0 while real invoices already reached the bookkeeping system, so the operator believes nothing was issued and risks a duplicate run. Sum every issuance path into the same created/total — or report each path separately — so "0 created" unambiguously means nothing was issued.
- Trusting a dry-run to prove a backfill's write path is safe. A dry-run only reads, so it cannot catch a write-only failure such as a Firestore `undefined` field in the email-queue document; the run stays green while the first live invoice throws. Exercise the exact document the live path writes (build it and validate against the SDK) before declaring the fix deployable, and write optional document fields with conditional spread — `...(x ? { field: x } : {})`, never `field: x` — because Firestore rejects `undefined` values.

## Supporting references

- `references/payment-dashboard-reconciliation.md` — provider-oriented data model, backfill checklist, external billing notes, and source links.
- `references/subscription-lifecycle-incidents.md` — diagnosing and repairing recurring-subscription incidents: orphaned charges after cancellation/account deletion, finding a subscription by payer e-mail, safe cancellation, and operator-script conventions.
- `references/subscription-invoice-backfills.md` — exact-window subscription invoice issuance and delivery reconciliation, including initial payments, dry-run/apply gates and idempotency.
