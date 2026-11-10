---
name: firebase-deployment
description: Use when deploying or debugging a Firebase deploy.
version: 1.0.0
author: dev-builder
license: MIT
---

# Firebase deployment

## When to Use
- A Firebase deploy (functions, Firestore rules, Firestore indexes, storage) is failing or needs to be run.
- A `firestore:indexes` deploy returns 403 (IAM) or 400 (bad index definition).
- You need to know which service account a deploy authenticates as.

## Deploy shape
- Deploy functions + Firestore rules + Firestore indexes together, storage separately:
  `firebase-tools deploy --only functions,firestore:rules,firestore:indexes` then `--only storage`.
- Keep the index deploy non-blocking: mark that step `continue-on-error: true` and add a final
  "Fail when indexes did not deploy" step guarded by `if: steps.<id>.outcome == 'failure'`
  (use `outcome`, NOT `conclusion`). This keeps a missing index visible without holding back
  function releases. A `continue-on-error` step reports `conclusion: success` even when it
  failed internally — only `steps.<id>.outcome` reflects the real result.

## IAM role for the firestore:indexes deploy
- The `firestore:indexes` deploy needs `roles/datastore.indexAdmin` on the deploy service
  account — NOT `roles/firestore.indexAdmin`. The 403 error names it literally:
  "Grant roles/datastore.indexAdmin to the deploy service account". Grant both if unsure, but
  `datastore.indexAdmin` is the one that unblocks the Firestore Admin API index calls.
- The deploy account is whatever `secrets.FIREBASE_SERVICE_ACCOUNT` (or equivalent) authenticates
  as, which can differ from the default "Firebase Admin SDK" service account. Confirm the exact
  email before granting a role; IAM changes are eventually consistent, so wait ~60s before
  re-running the failed job.

## Single-field index pitfall
- Firestore auto-creates single-field indexes. Declaring one in firestore.indexes.json returns
  HTTP 400 "this index is not necessary, configure using single field index controls" and blocks
  the entire `firestore:indexes` deploy.
- Declare only composite (2+ field) and array-config indexes. Before deploying, parse the file
  and drop any index whose `fields` array has ≤1 entry.

## Verify a function actually deployed (silent skip)
- A 2nd-gen functions deploy can finish `Deploy complete!` with a green run while individual
  functions were silently skipped — typically after a `429 Quota exceeded ... mutation requests`
  error. Firebase prints `updating ... NAME(region)...` for every function, but only functions
  that actually shipped get a `✔ functions[NAME(region)] Successful update operation.` line; a
  skipped function shows only the `updating` line and nothing after it.
- After any deploy you rely on, diff the two sets in the job log — count `updating ... function`
  lines vs `Successful update operation` lines — and confirm the SPECIFIC function you changed is
  in the successful set. A green run and a `head_sha` containing your commit are NOT proof the
  function runs your code; the deploy job reports success while the function still serves the old
  build.
- Fix: `gh run rerun <run-id>` (the mutation quota is per-minute, so a later re-run usually ships
  the skipped functions), then re-check the log for the missing `Successful` line.

## Find the deploy service account without leaking secrets
- Add a temporary step right after auth:
  `gcloud auth list --filter=status:ACTIVE --format="value(account)"`
  This prints only the account email, never the credential material. Remove it once known.
- `workflow_dispatch` and `workflow_run` only resolve against the default branch; a debug
  workflow that exists only on a feature branch returns 404 from `gh workflow run` until merged.
