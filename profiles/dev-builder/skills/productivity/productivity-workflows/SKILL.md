---
name: productivity-workflows
description: Cross-app productivity operations across workspace SaaS, documents, meeting pipelines, and location enrichment.
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
---

# Productivity Workflows

Use this umbrella when the user is trying to get work done across business tools rather than asking about one isolated file format or one brand name. This skill covers the class of tasks where the agent must inspect, move, summarize, enrich, or mutate information inside productivity systems.

## When to use
- Workspace SaaS automation across Google Workspace, Notion, or Airtable
- Presentation and document handling where the output matters more than the specific tool internals
- Meeting-summary pipeline operations and subscription troubleshooting
- Location enrichment for operational workflows (addresses, nearby places, routes, timezones)
- Cross-tool workflows such as "pull from Drive, summarize, put into Notion" or "extract a PDF, then send a deck"

## Shared operating rules
1. Identify the system of record first: Google, Notion, Airtable, local files, Teams, or map data.
2. Check auth/setup before promising writes. Many of these tools fail because credentials are missing, not because the command syntax is wrong.
3. Read before you write: inspect schema, page structure, file type, or meeting job state before mutating anything.
4. Confirm externally visible side effects before executing them: sending email, sharing files, creating records, deleting rows, modifying docs, or posting summaries.
5. Prefer the narrowest backend that already fits the job — do not OCR a text PDF, do not open a browser for an API task, and do not invent a new sync path when a CLI already exists.

## Decision tree

### Google Workspace
Use this branch for Gmail, Calendar, Drive, Docs, Sheets, or Contacts.

High-value rules:
- If the user only needs email, consider a simpler mail path before a full Workspace OAuth setup.
- Check auth first, then use the Hermes-managed wrapper/CLI path.
- Calendar writes must include timezone-aware ISO timestamps.
- Drive sharing/deletion and Gmail sending are explicit side effects that require confirmation.

### Notion
Use this branch for pages, blocks, markdown export/import, databases/data sources, or Notion-hosted Workers.

High-value rules:
- Prefer the official CLI when installed; otherwise fall back to raw HTTP.
- Modern Notion API semantics distinguish page creation under a `database_id` from querying via `data_source_id`.
- Share the target page/database with the integration before debugging 404s.
- Use markdown endpoints when the real task is agent-readable content rather than block-level structure.

### Airtable
Use this branch for bases, tables, record CRUD, schema inspection, filters, or upserts.

High-value rules:
- Inspect base/table schema before writes.
- URL-encode `filterByFormula` rather than hand-escaping it.
- Prefer `PATCH` over `PUT` so unchanged fields are preserved.
- Respect the 5 req/sec per-base limit and batch in groups of 10 records when possible.

### Supabase / Postgres-backed productivity systems
Use this branch when the user wants a future-proof operational database, CRM, relationship-memory system, or agent-ready backend that may later become a SaaS/product.

High-value rules:
- Treat Supabase/Postgres as the source of truth; local files are docs, exports, caches, or migration artifacts, not equal peers.
- Model multi-tenancy early when future users/coaches/teams are plausible: `workspaces`, `users/coaches`, `workspace_members`, and scoped business rows.
- For AI access, prefer a safe service layer: CLI first for testability, then MCP tools wrapping the same business operations.
- Do not give normal agents arbitrary SQL access; expose tools like `find_contact`, `add_interaction`, `get_briefing`, `plan_followup`, and log mutations.
- For relationship-memory CRM, store source artifacts/transcripts separately from distilled durable memories and follow-ups.
- Reference: `references/supabase-ai-crm.md` contains the reusable Supabase AI CRM / relationship-memory pattern.

### Documents and presentations
Use this branch when the task revolves around PDFs, scans, OCR, or `.pptx` files.

High-value rules:
- For remote PDFs, try `web_extract` first.
- For local PDFs, default to lightweight extraction unless OCR or complex layout is actually required.
- If the file is `.pptx`, treat it as a deck workflow: inspect content, render/thumbnail for QA, and verify visually before declaring success.
- When the user wants a deck edited rather than merely read, keep the verification loop explicit: generate, render to images, inspect, fix, re-check.

### Maps and location enrichment
Use this branch for geocoding, POIs, routes, distance, directions, and timezones.

High-value rules:
- Prefer the local OSM/OSRM-based script path because it avoids API-key friction.
- When a user sends a location pin, extract coordinates directly and operate on them.
- For "open now?" or business-hours questions, verify against fresher web data if OSM hours are absent or suspect.

### Teams meeting pipeline
Use this branch for Teams summaries, transcript ingestion, replaying jobs, validating Graph setup, or subscription maintenance.

High-value rules:
- The operator surface is the Hermes CLI, not a separate tool.
- Validate config and token health before chasing missing summaries.
- Microsoft Graph webhook subscriptions expire after 72 hours and must be actively renewed.
- If summaries stop arriving, check subscription expiry before assuming transcript extraction broke.

## Class-level workflow patterns
- **Collect → transform → publish**: gather from one system, normalize, then post/store in another.
- **Inspect → fix auth/state → replay**: common for Teams, Workspace, and SaaS automations.
- **Extract → review → summarize**: common for PDFs, decks, transcripts, and meeting outputs.
- **Schema first, data second**: common for Airtable, Notion, and Sheets-like tasks.

## Keep vs break out
Stay in this umbrella whenever the task is fundamentally "operate on productivity systems and the information inside them." Break out only when the user clearly needs a specialized creative, coding, or research stack instead.
