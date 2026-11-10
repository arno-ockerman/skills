# Supabase AI CRM / Relationship Memory Pattern

Use this reference when the user wants a future-proof CRM or relationship-memory system that agents can operate, especially when it may later become a SaaS/product for other coaches or teams.

## Core pattern

Treat Supabase/Postgres as the source of truth, not a spreadsheet or a local mirror.

Build the system in layers:

1. Supabase database as canonical state
2. Safe business operations in a CLI/service layer
3. MCP server exposing the same operations as agent tools
4. Later web/mobile/dashboard product on the same database

Do not give agents arbitrary SQL access for normal product workflows. Expose specific business tools instead.

## Multi-tenant foundation

Even for a single-user MVP, model ownership from day one:

- `workspaces`: business/team/account container
- `coaches` or `users`: human operators
- `workspace_members`: roles such as owner/admin/coach/viewer
- CRM data includes `workspace_id` and usually `coach_id`
- `agents`: AI agent configurations
- `coach_agents`: link coaches to agents
- `communication_channels`: Telegram/WhatsApp/email/app channel mappings

This prevents painful migration when the user later wants to add another coach with their own contacts and AI agent.

## Relationship memory tables

For a coaching CRM where the user asks “where did I leave off with X?”, prefer this structure:

- `contacts`: profile and current relationship state
- `contact_channels`: handles/phone/email/social accounts
- `interactions`: meaningful touchpoints, summaries, next actions
- `artifacts`: source files such as Zoom recordings, voice memos, PDFs, chat exports
- `transcripts`: extracted text from audio/video/chat artifacts
- `contact_memories`: durable facts distilled from conversations
- `followups`: planned actions
- `context_chunks`: agent-readable chunks with optional pgvector embeddings
- `agent_activity_log`: audit trail for agent mutations

## AI retrieval flow

For “what did I last discuss with Sarah?”:

1. Resolve the contact with confidence.
2. Fetch recent interactions.
3. Fetch active durable memories ordered by importance.
4. Fetch open followups.
5. Optionally use semantic search over transcript/context chunks.
6. Answer with last conversation, important context, open promises, and suggested next step.

## CLI → MCP progression

Start with a CLI because it is easy to test and easy for Hermes to call:

- `crm contacts add/search/show`
- `crm interactions add`
- `crm memories add`
- `crm followups add/due/done`
- `crm briefing contact`
- `crm artifacts add/transcribe/summarize`

Then wrap the same service layer as MCP tools:

- `crm_find_contact`
- `crm_get_contact_briefing`
- `crm_add_interaction`
- `crm_add_contact_memory`
- `crm_plan_followup`
- `crm_list_due_followups`
- `crm_add_artifact`
- `crm_transcribe_artifact`

## Security notes

- For MVP/trusted operator use, a service role key can power CLI/MCP, but keep it server-side only.
- For product use, use Supabase Auth + RLS with user JWTs.
- Always log mutations by agents.
- Use explicit workspace/coach scoping in every command/tool.
