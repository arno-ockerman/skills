# Granola meeting notes — capture reference

Granola is an AI meeting-notetaker (iOS + macOS; the desktop app is macOS-only, no Windows, and there is a web app at `notes.granola.ai`).

## Third-party CLI does NOT work for mobile-only users
The `github.com/theantichris/granola` CLI reads two files from the **Mac desktop app**:
- `supabase.json` → `workos_tokens.access_token` (WorkOS bearer) → calls `api.granola.ai/v2/get-documents` (notes).
- `cache-v3.json` → local transcript cache.

An iPhone-only user has neither file, so the CLI has no credentials to read. Do not go down this path for mobile-only users.

## Official API (preferred for automated capture)
- Base: `https://public-api.granola.ai` (v1). Auth: `Authorization: Bearer <API key>`.
- `GET /v1/notes?created_after=&updated_after=&folder_id=&cursor=&page_size=` (page_size ≤30) → `{ notes:[NoteSummary], hasMore, cursor }`.
- `GET /v1/notes/{note_id}?include=transcript` → Note with `summary_markdown`, `summary_text`, `private_notes_markdown`, `transcript[]`, `attendees`, `calendar_event`, `web_url`. Oversized transcript → `413 TRANSCRIPT_TOO_LARGE`; then use the transcript endpoint.
- `GET /v1/notes/{note_id}/transcript?cursor=&page_size=` (≤100) → `{ transcript[], hasMore, cursor }`.
- `GET /v1/folders`; `POST /v1/webhook-endpoints` (Business/Enterprise) for event-driven capture instead of polling.
- **Plan requirement:** API keys require **Business or Enterprise**. Free/Basic cannot create API keys (docs FAQ). Key creation: Settings → Connectors → API keys (scopes: "Personal notes" and/or "Public notes").
- Rate limits: 25 burst / 5 s, sustained 5 req/s (300/min); 429 on exceed.
- Only notes with a generated AI summary + transcript appear (still-processing notes are excluded; Get Note → 404).

## MCP (works on Free plan, but chat-oriented)
- URL `https://mcp.granola.ai/mcp` — Streamable HTTP, OAuth 2.0 browser sign-in, Dynamic Client Registration (no client id/secret).
- Tools: `query_granola_meetings`, `get_account_info`. Free plan limited to last 30 days.
- Not a deterministic bulk export — use the REST API for archiving; MCP is for conversational assistants.

## Discovery technique (reusable)
When vendor docs are hard to scrape (JS SPA, or web_extract/web_search backends down), fetch `https://docs.<domain>/llms.txt` (a markdown index of every page) and individual pages at `https://docs.<domain>/<path>.md`. Granola serves both, so the full OpenAPI (`/api-reference/openapi.json`) is curl-fetchable with no auth.

## Gotcha
"Granola has no export path" was a wrong conclusion that predated the official API. Always check the vendor docs index for an API/MCP before declaring a mobile-only tool uncapturable.
