# Third-party skills I use

These come from vendors or plugin marketplaces. They are **not vendored** here.
Install or update them through their own channel. Usage counts are skill loads
seen in Codex session logs up to 2026-11-10. They are a rough guide for what to
keep.

## Codex plugins (`/opt/ai-tools/config/codex/home/.codex/plugins/cache/`)

| Plugin (marketplace) | Skills I actually use | Loads |
|---|---|---|
| `vercel` (openai-curated-remote) | `observability`, `agent-browser`, `agent-browser-verify`, `react-best-practices` (+30 more, mostly unused) | 160 / 158 / 6 / 3 |
| `plugin-management` (openai-curated-remote) | `plugin-management` | 115 |
| `deep-research-work` | `deep-research` | 19 |
| `sites` (openai-curated-remote) | `sites` | 4 |
| `sentry` (sentry-plugin-marketplace, `getsentry/plugin-codex`) | `sentry-get-started`, `sentry-debug-issue`, … | 8 |
| Others installed: `github`, `gmail`, `google-calendar`, `google-contacts`, `google-drive`, `openai-templates`, `supabase`, `work-pets`, `zoom` | — | — |

Codex built-ins in `.codex/skills/.system/`: `imagegen`, `openai-docs`,
`review-agent`, `skill-creator`, `skill-installer`.

## Claude Code

| Source | Skills |
|---|---|
| Plugin `sentry@claude-plugins-official` 1.4.0 (user scope) | `sentry-get-started`, `sentry-debug-issue`, `sentry-instrument`, `sentry-create-alert`, `sentry-fix-stack-traces`, `sentry-setup-releases`, `sentry-otel-exporter-setup`, `sentry-snapshots-cocoa` |
| claude.ai synced (`.claude/skills/synced/`, managed by Anthropic) | `deep-research`, `docs`, `docx`, `pdf`, `pptx`, `xlsx`, `skill-creator`, `google-workspace`, `morning`, `import-memory`, `built-in-browser`, `chrome-browser`, `computer-use` |

## Project-scoped packs (live in each project's repo, not here)

| Project | Location | Packs |
|---|---|---|
| Club-app | `.claude/skills/`, `.agents/skills/` | Matt Pocock skills (`diagnosing-bugs`, `resolving-merge-conflicts`, `grill-me`, `tdd`, `to-spec`, `to-tickets`, `prototype`, `qa`, `handoff`, …), Expo/EAS skills, Clerk skills, Supabase |
| Archon | `.claude/skills/` | `archon`, `triage`, `manage-run`, `validate-ui`, `rulecheck`, `replicate-issue`, `save-task-list`, `docker-extend` |
| Jarvis-bot | `skills/` | OpenClaw agent skills (ASO, marketing, Supabase ops, health, …) |

If one of these becomes something I use across projects, copy it into
`skills/` (keeping its license and attribution) and run `./sync.sh install`.
