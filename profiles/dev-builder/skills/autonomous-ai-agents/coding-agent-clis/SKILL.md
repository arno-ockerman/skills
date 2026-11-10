---
name: coding-agent-clis
description: "Use when delegating coding to external agent CLIs such as Claude Code, Codex, or OpenCode."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [coding-agent, cli, delegation, claude-code, codex, opencode]
    related_skills: [hermes-agent, shared-agent-cli-runtime, subagent-driven-development]
---

# Coding Agent CLIs

## Overview

This umbrella covers the class of tasks where Hermes orchestrates an external coding agent CLI instead of doing all work itself. The exact engine may vary — Claude Code, Codex, or OpenCode — but the operator pattern is the same: verify tool readiness, choose bounded vs interactive mode, isolate the working directory, monitor progress, and report concrete outcomes.

## When to use

- The user explicitly asks for a specific coding CLI
- You want a separate autonomous coding worker with its own session loop
- The task benefits from long-running or parallel coding agents
- You need an external agent’s built-in review, worktree, or REPL workflow

## Shared operator rules

1. Verify installation and auth before starting work.
2. Prefer a one-shot bounded command for single tasks.
3. Use an interactive or background session only when follow-up turns are likely.
4. Always scope the agent to the correct repo/workdir.
5. Monitor long-running sessions instead of assuming they are stuck.
6. Report changed files, test results, and remaining risks back to the user.

## Tool-choice matrix

| Need | Best fit |
|---|---|
| Clean one-shot coding with strong print-mode automation | Claude Code |
| PTY-first coding inside a git repo, especially batch worktrees | Codex |
| Provider-agnostic open-source coding agent with `run` and resumable sessions | OpenCode |

## 1. Claude Code subsection

Choose Claude Code when print mode is the cleanest path.

Default pattern:
- prefer `claude -p` for bounded tasks
- use tmux-backed interactive sessions when multi-turn control is needed
- handle trust / permissions dialogs only in interactive mode
- set `--max-turns`, `--allowedTools`, and `workdir` deliberately

Preserved key points:
- print mode is the default for automation
- tmux is the reliable orchestration path for interactive sessions
- monitor with capture-pane when running interactively
- clean up tmux sessions after completion

## 2. Codex subsection

Choose Codex when the workflow is git-repo-centric and PTY execution is acceptable.

Default pattern:
- use `codex exec` for one-shot tasks
- remember Codex expects a git repository
- use background PTY sessions for longer tasks and monitor them with process tools
- use worktrees for safe parallel issue fixing or PR review isolation

Preserved key points:
- always provide PTY mode for interactive Codex flows
- create a scratch git repo for non-repo experiments
- use `--full-auto` or `--yolo` only with explicit intent and awareness of scope

## 3. OpenCode subsection

Choose OpenCode when you want a provider-agnostic external coding worker or a resumable TUI/CLI split.

Default pattern:
- prefer `opencode run` for bounded automation
- use background PTY mode only for iterative sessions
- resume prior sessions when helpful with `-c` or `-s`
- exit interactive sessions with Ctrl+C or process kill, not slash commands

Preserved key points:
- `opencode run` usually does not need PTY
- binary-path mismatches are common; verify `which -a opencode`
- keep one repo/workdir per active session to avoid collisions

## Parallel and worktree guidance

Across all three CLIs:
- use separate workdirs or git worktrees for parallel tasks
- do not let multiple agents edit the same checkout concurrently
- treat each agent run as an isolated worker with explicit monitoring

## Relationship to shared runtime

If the hard part is not the coding task itself but making multiple agents share the same CLI installs, auth, cache, and wrappers, load `shared-agent-cli-runtime`. That skill is infrastructure-focused; this umbrella is execution-focused.

For where each CLI reads its skills in the shared `/opt/ai-tools` runtime, how to install one skill for Claude Code and Codex at once, how to verify discovery without a model call, and how to read or redeem Codex rate-limit reset credits, read `references/shared-skills-and-codex-limits.md`.

## Pitfalls

- launching the wrong mode when a simpler one-shot command would do
- forgetting auth/doctor/version preflights
- trusting a successful browser/OAuth callback without immediately rerunning `auth status`; container-mounted CLI homes can contain credential files owned by another UID, so login may report success while credentials remain unusable
- when a shared Claude home is not writable, run the underlying Claude binary with an explicit writable `HOME` or `CLAUDE_CONFIG_DIR`, then verify persistence in a fresh process before starting work
- running multiple external agents in the same checkout
- assuming a TUI session finished without checking logs or screen state
- a `429`/usage-limit error on Codex is a state, not a defect: read `account/rateLimits/read` for `ordinaryUsageAllowed` and `resetsAt` before touching anything, and never redeem a reset credit on your own initiative (it is irreversible and also wipes weekly usage)
- assuming a CLI subcommand exists because a TUI menu item does: Codex has no `reset` subcommand — that menu drives the app-server method `account/rateLimitResetCredit/consume`
- trusting `hermes prompt-size` when reasoning about MCP tool cost (it does not model MCP tools at all)
- archiving provider-specific knowledge into separate micro-skills instead of keeping it as subsections of this operator guide

## Verification checklist

- [ ] Selected the right CLI for the task shape
- [ ] Verified install/auth/readiness first
- [ ] For skills work: confirmed discovery separately per CLI (`claude -p` for Claude Code, `codex debug prompt-input` for Codex)
- [ ] Used isolated workdir or worktree where needed
- [ ] Monitored the run and captured real outcomes
- [ ] Summarized files changed, tests run, and risks remaining
