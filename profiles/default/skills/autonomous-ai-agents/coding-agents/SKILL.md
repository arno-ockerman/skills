---
name: coding-agents
description: "Orchestrate external coding agents (Claude Code, Codex, OpenCode) from Hermes: one-shot tasks, interactive PTY sessions, parallel worktrees, PR reviews, cost/performance tuning. Use when delegating coding work to autonomous CLI agents."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [coding-agent, claude-code, codex, opencode, automation, PTY, worktree, PR-review]
    related_skills: [hermes-agent, github-workflow, plan, shared-agent-cli-runtime]
---

# Coding Agents — External CLI Orchestration

Delegate coding tasks to **Claude Code** (Anthropic), **Codex** (OpenAI), or **OpenCode** (provider-agnostic) from Hermes. All three are autonomous coding agents with TUIs/CLIs that can read files, write code, run commands, and manage git workflows.

## Quick Comparison

| Aspect | Claude Code | Codex | OpenCode |
|--------|-------------|-------|----------|
| **Vendor** | Anthropic | OpenAI | OpenCode (provider-agnostic) |
| **Auth** | OAuth (Pro/Max) or `ANTHROPIC_API_KEY` | OAuth or `OPENAI_API_KEY` | `OPENROUTER_API_KEY` or any OpenAI-compatible |
| **Print Mode** | `claude -p` (preferred) | `codex exec` | `opencode run` |
| **Interactive** | tmux + PTY required | background + PTY | background + PTY |
| **Max Turns** | `--max-turns N` (print only) | N/A (use `--full-auto`) | N/A |
| **Budget Cap** | `--max-budget-usd` | N/A | N/A |
| **Worktree** | `claude -w` + `--tmux` | manual `git worktree add` | manual `git worktree add` |
| **PR Review** | `--from-pr N` | `gh pr checkout` + `codex review` | `opencode pr N` |
| **Output Format** | `--output-format json/stream-json` | `--format json` | `--format json` |

---

## Shared Prerequisites

- **Git repository required** — all three refuse to run outside a git repo
- **Use `workdir`** in terminal calls to target the right project
- **For scratch work**: `cd $(mktemp -d) && git init && <agent> ...`
- **PTY for interactive**: `pty=true` in terminal calls for Codex/OpenCode; tmux for Claude Code

---

## Part 1: Claude Code

### Install & Auth
```bash
npm install -g @anthropic-ai/claude-code
claude auth login              # browser OAuth (Pro/Max)
claude auth login --console    # API key billing
claude auth status             # check status
claude doctor                  # health check
```

### Mode 1: Print Mode (`-p`) — PREFERRED for Most Tasks
Non-interactive, exits when done, no PTY needed, skips all dialogs.

```bash
# Basic
terminal(command="claude -p 'Add error handling to all API calls in src/' --allowedTools 'Read,Edit' --max-turns 10", workdir="/path/to/project", timeout=120)

# Structured JSON output
terminal(command="claude -p 'Analyze auth.py for security issues' --output-format json --max-turns 5", workdir="/project", timeout=90)

# Streaming JSON (real-time)
terminal(command="claude -p 'Write a summary' --output-format stream-json --verbose --include-partial-messages", timeout=60)

# Piped input (analyze known content)
terminal(command="cat src/auth.py | claude -p 'Review for bugs' --max-turns 1", timeout=60)

# JSON schema for structured extraction
terminal(command="claude -p 'List all functions in src/' --output-format json --json-schema '{\"type\":\"object\",\"properties\":{\"functions\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"functions\"]}' --max-turns 5", workdir="/project", timeout=90)

# Session continuation
terminal(command="claude -p 'Start refactoring' --output-format json --max-turns 10 > /tmp/session.json", workdir="/project", timeout=180)
terminal(command="claude -p 'Continue and add pooling' --resume $(cat /tmp/session.json | python3 -c 'import json,sys; print(json.load(sys.stdin)[\"session_id\"])') --max-turns 5", workdir="/project", timeout=120)
```

### Mode 2: Interactive PTY via tmux — Multi-Turn Sessions
Full conversational REPL with slash commands (`/compact`, `/review`, `/model`).

```bash
# Start session
terminal(command="tmux new-session -d -s claude-work -x 140 -y 40")
terminal(command="tmux send-keys -t claude-work 'cd /path/to/project && claude' Enter")

# Handle dialogs (CRITICAL)
# Dialog 1: Workspace Trust (Enter for default "Yes")
terminal(command="sleep 4 && tmux send-keys -t claude-work Enter")
# Dialog 2: Bypass Permissions (Down then Enter for "Yes, I accept")
terminal(command="sleep 3 && tmux send-keys -t claude-work Down && sleep 0.3 && tmux send-keys -t claude-work Enter")

# Send task
terminal(command="sleep 5 && tmux send-keys -t claude-work 'Refactor auth module to use JWT tokens' Enter")

# Monitor
terminal(command="sleep 15 && tmux capture-pane -t claude-work -p -S -60")

# Follow-up
terminal(command="tmux send-keys -t claude-work 'Now add unit tests for the new JWT code' Enter")

# Exit
terminal(command="tmux send-keys -t claude-work '/exit' Enter")
```

### Key Flags Reference

| Category | Flags |
|----------|-------|
| **Session** | `-p/--print`, `-c/--continue`, `-r/--resume`, `--fork-session`, `--session-id`, `--no-session-persistence`, `-w/--worktree`, `--tmux`, `--ide`, `--chrome`, `--from-pr` |
| **Model** | `--model <alias>`, `--effort <level>`, `--max-turns <n>`, `--max-budget-usd <n>`, `--fallback-model` |
| **Permissions** | `--dangerously-skip-permissions`, `--allow-dangerously-skip-permissions`, `--permission-mode`, `--allowedTools`, `--disallowedTools`, `--tools` |
| **Output** | `--output-format text/json/stream-json`, `--input-format`, `--json-schema`, `--verbose`, `--include-partial-messages`, `--replay-user-messages` |
| **System Prompt** | `--append-system-prompt`, `--append-system-prompt-file`, `--system-prompt`, `--bare`, `--agents`, `--mcp-config`, `--settings`, `--plugin-dir` |

### PR Review Patterns

**Quick (Print Mode):**
```bash
terminal(command="cd /repo && git diff main...feature-branch | claude -p 'Review for bugs, security, style. Be thorough.' --max-turns 1", timeout=60)
```

**Deep (Interactive + Worktree):**
```bash
terminal(command="tmux new-session -d -s review -x 140 -y 40")
terminal(command="tmux send-keys -t review 'cd /repo && claude -w pr-review' Enter")
terminal(command="sleep 5 && tmux send-keys -t review Enter")  # Trust dialog
terminal(command="sleep 2 && tmux send-keys -t review 'Review all changes vs main. Check for bugs, security, race conditions, missing tests.' Enter")
terminal(command="sleep 30 && tmux capture-pane -t review -p -S -60")
```

**From PR Number:**
```bash
terminal(command="claude -p 'Review this PR thoroughly' --from-pr 42 --max-turns 10", workdir="/repo", timeout=120)
```

### Parallel Instances
```bash
terminal(command="tmux new-session -d -s task1 -x 140 -y 40 && tmux send-keys -t task1 'cd ~/proj && claude -p \"Fix auth bug\" --allowedTools \"Read,Edit\" --max-turns 10' Enter")
terminal(command="tmux new-session -d -s task2 -x 140 -y 40 && tmux send-keys -t task2 'cd ~/proj && claude -p \"Write integration tests\" --allowedTools \"Read,Write,Bash\" --max-turns 15' Enter")
terminal(command="tmux new-session -d -s task3 -x 140 -y 40 && tmux send-keys -t task3 'cd ~/proj && claude -p \"Update README\" --allowedTools \"Read,Edit\" --max-turns 5' Enter")
terminal(command="sleep 30 && for s in task1 task2 task3; do echo '===' $s '==='; tmux capture-pane -t \$s -p -S -5 2>/dev/null; done")
```

### CLAUDE.md — Project Context
Auto-loaded from project root. Use for persistent context:
```markdown
# Project: My API
## Architecture
- FastAPI + SQLAlchemy + PostgreSQL + Redis
- pytest, 90% coverage target
## Key Commands
- `make test`, `make lint`, `make dev`
## Code Standards
- Type hints on all public functions
- Google-style docstrings
- 2-space YAML, 4-space Python
- No wildcard imports
```

---

## Part 2: Codex (OpenAI)

### Install & Auth
```bash
npm install -g @openai/codex
codex auth login   # OAuth flow
codex auth list    # verify
```
Must run inside a git repository. Use `pty=true` for interactive.

### One-Shot Tasks
```bash
terminal(command="codex exec 'Add dark mode toggle to settings'", workdir="~/project", pty=true)

# Scratch work (needs git repo)
terminal(command="cd $(mktemp -d) && git init && codex exec 'Build a snake game in Python'", pty=true)
```

### Background Mode (Long Tasks)
```bash
terminal(command="codex exec --full-auto 'Refactor the auth module'", workdir="~/project", background=true, pty=true)
# Returns session_id

process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")
process(action="submit", session_id="<id>", data="yes")  # if Codex asks
process(action="kill", session_id="<id>")
```

### Key Flags
| Flag | Effect |
|------|--------|
| `exec "prompt"` | One-shot, exits when done |
| `--full-auto` | Sandboxed, auto-approves file changes |
| `--yolo` | No sandbox, no approvals (fastest, most dangerous) |

### PR Reviews
```bash
# Safe review in temp clone
terminal(command="REVIEW=$(mktemp -d) && git clone https://github.com/user/repo.git $REVIEW && cd $REVIEW && gh pr checkout 42 && codex review --base origin/main", pty=true)
```

### Parallel Issue Fixing with Worktrees
```bash
terminal(command="git worktree add -b fix/issue-78 /tmp/issue-78 main", workdir="~/project")
terminal(command="git worktree add -b fix/issue-99 /tmp/issue-99 main", workdir="~/project")

terminal(command="codex --yolo exec 'Fix issue #78: <desc>. Commit when done.'", workdir="/tmp/issue-78", background=true, pty=true)
terminal(command="codex --yolo exec 'Fix issue #99: <desc>. Commit when done.'", workdir="/tmp/issue-99", background=true, pty=true)

# After completion
terminal(command="cd /tmp/issue-78 && git push -u origin fix/issue-78 && gh pr create --repo user/repo --head fix/issue-78 --title 'fix: ...'")
```

### Batch PR Reviews
```bash
terminal(command="git fetch origin '+refs/pull/*/head:refs/remotes/origin/pr/*'", workdir="~/project")
terminal(command="codex exec 'Review PR #86. git diff origin/main...origin/pr/86'", workdir="~/project", background=true, pty=true)
terminal(command="codex exec 'Review PR #87. git diff origin/main...origin/pr/87'", workdir="~/project", background=true, pty=true)
```

---

## Part 3: OpenCode

### Install & Auth
```bash
npm i -g opencode-ai@latest   # or: brew install anomalyco/tap/opencode
opencode auth login           # or set OPENROUTER_API_KEY
opencode auth list            # verify
```
`pty=true` for interactive TUI; `opencode run` doesn't need pty.

### Binary Resolution
```bash
terminal(command="which -a opencode")
terminal(command="opencode --version")
# Pin explicitly if needed: terminal(command="$HOME/.opencode/bin/opencode run '...'")
```

### One-Shot Tasks
```bash
terminal(command="opencode run 'Add retry logic to API calls and update tests'", workdir="~/project")

# Attach context files
terminal(command="opencode run 'Review config for security issues' -f config.yaml -f .env.example", workdir="~/project")

# Show thinking
terminal(command="opencode run 'Debug why tests fail in CI' --thinking", workdir="~/project")

# Force model
terminal(command="opencode run 'Refactor auth module' --model openrouter/anthropic/claude-sonnet-4", workdir="~/project")
```

### Interactive Sessions (Background)
```bash
terminal(command="opencode", workdir="~/project", background=true, pty=true)
# Returns session_id

process(action="submit", session_id="<id>", data="Implement OAuth refresh flow and add tests")
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")
process(action="submit", session_id="<id>", data="Now add error handling for token expiry")

# Exit with Ctrl+C (NOT /exit — opens agent selector!)
process(action="write", session_id="<id>", data="\x03")  # Ctrl+C
# Or: process(action="kill", session_id="<id>")
```

### TUI Keybindings
| Key | Action |
|-----|--------|
| `Enter` | Submit (may need twice) |
| `Tab` | Switch agents (build/plan) |
| `Ctrl+P` | Command palette |
| `Ctrl+X L/M/N/E` | Switch session/model/new session/editor |
| `Ctrl+C` | Exit |

### Resume Sessions
```bash
terminal(command="opencode -c", workdir="~/project", background=true, pty=true)   # Continue last
terminal(command="opencode -s ses_abc123", workdir="~/project", background=true, pty=true)  # Specific
```

### PR Review Workflow
```bash
# Built-in PR command
terminal(command="opencode pr 42", workdir="~/project", pty=true)

# Or isolated review in temp clone
terminal(command="REVIEW=$(mktemp -d) && git clone https://github.com/user/repo.git $REVIEW && cd $REVIEW && opencode run 'Review this PR vs main. Report bugs, security, test gaps, style.' -f $(git diff origin/main --name-only | head -20 | tr '\n' ' ')", pty=true)
```

### Parallel Work Pattern
```bash
terminal(command="opencode run 'Fix issue #101 and commit'", workdir="/tmp/issue-101", background=true, pty=true)
terminal(command="opencode run 'Add parser regression tests and commit'", workdir="/tmp/issue-102", background=true, pty=true)
process(action="list")
```

### Session & Cost Management
```bash
terminal(command="opencode session list")
terminal(command="opencode stats")
terminal(command="opencode stats --days 7 --models anthropic/claude-sonnet-4")
```

---

## Common Patterns Across All Three

### Worktree Isolation for Parallel Work
Always use separate workdirs/worktrees to avoid collisions:
```bash
git worktree add -b fix/issue-X /tmp/issue-X main
# Run agent in /tmp/issue-X
```

### Cost/Performance Tips
- **Claude Code**: `--max-turns 5-10`, `--max-budget-usd`, `--effort low` for simple tasks, `--bare` for CI
- **Codex**: `--full-auto` for building, background for long tasks
- **OpenCode**: `opencode run` for one-shots (no pty), interactive only when iteration needed

### Monitoring Long Tasks
```bash
# Claude Code (tmux)
terminal(command="tmux capture-pane -t <session> -p -S -50")

# Codex/OpenCode (background processes)
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")
```

### Reporting Results
After completion, always summarize to user:
- Files changed
- Tests run/passed
- Remaining risks/next steps
- Git commands to push/create PR

---

## Shared Rules for Hermes Agents

1. **Prefer print mode / `run` / `exec` for single tasks** — cleaner, no dialog handling, structured output
2. **Use tmux (Claude) or background+pty (Codex/OpenCode) for multi-turn work**
3. **Always set `workdir`** — keep agent focused on right project
4. **Set turn/budget limits** — prevents infinite loops and runaway costs
5. **Monitor sessions** — check progress, don't kill slow sessions prematurely
6. **Use worktrees for parallel work** — prevents git collisions
7. **Report concrete outcomes** — files changed, tests, risks, next steps
8. **Clean up tmux sessions** — `tmux kill-session -t <name>` when done

---

## Pitfalls by Agent

### Claude Code
- Interactive REQUIRES tmux — `pty=true` alone works but tmux gives `capture-pane`/`send-keys`
- `--dangerously-skip-permissions` dialog defaults to "No, exit" — must send Down+Enter
- `--max-budget-usd` minimum ~$0.05 (system prompt cache creation)
- `--max-turns` is print-mode only
- Session resumption requires same directory

### Codex
- Git repo required — use `mktemp -d && git init` for scratch
- `pty=true` mandatory for interactive; `exec` doesn't need it
- `--full-auto` for building; background for long tasks

### OpenCode
- `/exit` is NOT valid — opens agent selector; use Ctrl+C
- PATH mismatch can select wrong binary
- Enter may need to be pressed twice to submit in TUI