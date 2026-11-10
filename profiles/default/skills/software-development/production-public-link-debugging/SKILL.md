---
name: production-public-link-debugging
description: Use when a production public link misbehaves. Verify first.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [production, web, links, routing, debugging, deployment]
    related_skills: [github-issue-to-pr, github-workflow, tdd]
---

# Production Public-Link Debugging

## Purpose

Debug public links shared through Instagram, WhatsApp, QR codes, or other in-app browsers without assuming the platform stripped the URL or that the persisted identifier is invalid.

## When to Use

Use this skill when a public route falls back to generic content, loses attribution, behaves differently inside an in-app browser, or appears inconsistent with the current source code.

## Procedure

1. Capture the exact URL copied from the sharing platform, including its query string, and compare it with the URL opened in a normal browser.
2. Reproduce the route in a normal browser and the originating in-app browser. Record the final URL, visible fallback page, redirects, and whether the query parameter remains present. Treat a platform-generated tracking URL as authoritative evidence: if Instagram or another platform drops an application query parameter and keeps only `fbclid`/tracking data, move the attribution token into a path segment rather than trying to recover the missing query value.
3. Trace the route from the router to the data lookup. Identify the exact identifier contract: for example, a `club_members.id` rather than a user ID, slug, or display name.
4. Query the linked production database read-only to verify the identifier, parent entity, role/status, and public eligibility. Never infer invalidity from a generic fallback page.
5. Check the deployed revision, environment, database migration state, and client loading order. Distinguish a merged commit from a live production deployment: inspect the workflow condition and deployment run, because a merge can leave production on the old frontend build when production deployment is manual or skipped. If the current source already parses the parameter, investigate stale deployment, missing migration, race conditions, redirects, caching, and silent fallback behavior before changing the data model.
6. Add a regression test at the public behavior seam. Cover the valid identifier path, the invalid/stale identifier path, and the timing/loading path if the page can render before the lookup completes.
7. Implement the smallest complete fix. Preserve tenant scope and server-side authorization; never accept an arbitrary identifier from the URL without validating it against the correct parent entity.
8. Verify the exact production or candidate URL after deployment and confirm that the shared path preserves attribution through the next action, such as signup or booking.

## Rules and pitfalls

- Copy the exact shared URL before debugging — manually retyping it can hide stripped, duplicated, or encoded parameters.
- Validate persisted IDs against live scope and status before changing link generation — a syntactically valid UUID can still belong to another entity or be inactive.
- Do not silently treat an unresolved public identifier as a successful generic visit when attribution matters — the user loses the intended flow without diagnostic evidence.
- Resolve required link context before clearing the page's loading state — otherwise the page can render generic content and accept a CTA before attribution is ready.
- Keep public lookups narrowly scoped to the parent entity and permitted public fields — broadening the query to make a link work can leak tenant or identity data.
- Compare source and deployed revisions before editing code — a correct local implementation does not prove the live site contains it.
- Prefer path-based attribution links for social sharing when the platform rewrites or strips custom query parameters — a tracking query parameter cannot restore an application parameter that was removed upstream.
- After merging a fix, verify whether production deployment actually ran; trigger the repository's explicit production workflow only with human approval, because a green PR and a deployed preview do not publish `main` to the public site.

## Verification checklist

- [ ] Exact URL and query parameters captured.
- [ ] Normal-browser and in-app-browser behavior compared.
- [ ] Identifier contract confirmed from source and schema.
- [ ] Live record verified read-only with parent scope and status.
- [ ] Deployment, migration, and loading order checked.
- [ ] Regression test covers valid, invalid, and timing behavior where applicable.
- [ ] Candidate or production URL verified after the change.
