# Payment Dashboard Reconciliation Reference

## Reusable provider mapping

For each provider payment, capture at minimum:

- provider account key;
- payment ID;
- status;
- amount and currency;
- provider occurrence timestamp (`paidAt` when cash-basis reporting is approved);
- explicit metadata identifying product type and product ID;
- refund and chargeback references;
- source description for human reconciliation.

For provider balance transactions, retain:

- balance transaction ID and type;
- result/initial amount;
- deductions and fee breakdown;
- linked payment ID from transaction context;
- transaction timestamp.

Never store full provider customer payloads when identifiers are sufficient.

## Suggested normalized event

```ts
type Kind =
  | 'income'
  | 'refund'
  | 'chargeback'
  | 'provider_fee'
  | 'expense'
  | 'adjustment';

interface LedgerEntry {
  id: string;
  kind: Kind;
  category: string;
  amountMinor: number;
  currency: string;
  occurredAt: string;
  monthKey: string;
  source: string;
  sourceId: string;
  accountKey?: string;
  paymentId?: string;
  description: string;
}
```

Monthly net must be one documented formula over signed events, for example:

```text
net = gross income + refunds + chargebacks + provider fees + operating expenses + adjustments
```

Here refunds, fees, and expenses are negative ledger amounts. Do not use this formula as a tax-profit claim.

## Dry-run report

A useful backfill dry-run prints per account and total:

- pages fetched;
- payments inspected;
- paid payments in range;
- gross by category;
- refunds/chargebacks;
- provider fees;
- unsupported currency count;
- unclassified count and source IDs;
- earliest/latest included timestamps;
- source-specific errors;
- status: complete or partial.

The applied run must produce the same totals, and an immediate second apply must report zero newly created financial events.

## Cloud cost ingestion

Keep cloud billing behind a separate adapter. Query an official export filtered to the intended project and month, and include credits/adjustments in the cost formula. Grouping by service/SKU is useful for explanation, but a dashboard should not expose billing-account identifiers.

If historical export coverage is incomplete, record the missing month as a clearly sourced manual expense. Do not silently fill gaps with estimates.

## Primary documentation

- Mollie — List payments: https://docs.mollie.com/reference/list-payments
- Mollie — Get payment: https://docs.mollie.com/reference/get-payment
- Mollie — List balance transactions: https://docs.mollie.com/reference/list-balance-transactions
- Google Cloud — Export billing data to BigQuery: https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery
- Google Cloud — Standard billing export schema: https://docs.cloud.google.com/billing/docs/how-to/export-data-bigquery-tables/standard-usage
