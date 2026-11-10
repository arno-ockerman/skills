# skills

My personal agent skills library. It is the source of truth for the skills that
my t3code agents (Claude Code and Codex) load.

## Skills

| Skill | Use it when |
|---|---|
| [`plan-create-prd`](skills/plan-create-prd/SKILL.md) | A new feature or product idea needs a problem-first PRD (intent: what and why, never how). |
| [`plan-architecture`](skills/plan-architecture/SKILL.md) | A PRD or epic needs its high-level architecture decided: options, trade-offs, a recommendation, and what to spike. |
| [`plan-create-stories`](skills/plan-create-stories/SKILL.md) | A PRD must become engineer-ready GitHub or Jira tickets. |
| [`prd-to-ship-pipeline`](skills/prd-to-ship-pipeline/SKILL.md) | You want to take an idea through PRD → issues → Archon ship runs. |
| [`skill-inventory-audit`](skills/skill-inventory-audit/SKILL.md) | You are pruning or reviewing the installed Claude/Codex skills. |

The planning flow: `plan-create-prd` → `plan-architecture` → `plan-create-stories`,
with `prd-to-ship-pipeline` tying those steps to Archon.

Vendor skills I use but don't own are listed in [THIRD_PARTY.md](THIRD_PARTY.md).
They are referenced, not copied, so they stay on their upstream update path.

## Where they are installed

| Agent | Skills directory |
|---|---|
| Claude Code | `/opt/ai-tools/config/claude/home/.claude/skills/<name>/` |
| Codex | `/opt/ai-tools/config/codex/home/.codex/skills/<name>/` |

The clone lives at `/opt/ai-tools/src/skills`.

## Syncing

```bash
cd /opt/ai-tools/src/skills
./sync.sh status            # repo vs. each agent home; exits 1 on drift
./sync.sh install           # repo -> Claude + Codex homes
./sync.sh collect           # edits made in a home -> repo (tracked skills)
./sync.sh collect my-skill  # adopt a new skill created in a home
```

`sync.sh` only writes the skills in `skills/`. It never touches Claude's
`synced/` folder (claude.ai-managed skills), Codex's `.system/`, or plugin caches.

**Workflow for a change:** edit in `skills/<name>/`, run `./sync.sh install`, then
commit and push. If an agent edited a skill in place, run `./sync.sh collect`,
review `git diff`, then commit.

## Adding a skill

1. `mkdir skills/<name>` and write `skills/<name>/SKILL.md` with `name` and
   `description` frontmatter. The description should start with "Use when…".
2. `./sync.sh install`
3. Add a row to the table above, then commit.
