---
name: external-platform-workflows
description: "Operate external platform CLIs and messaging integrations: email, social posts, DMs, group mentions, and smart-home devices."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [external-platforms, cli, messaging, email, social-media, smart-home]
---

# External Platform Workflows

Use this class-level umbrella when the agent needs to operate an external service through a dedicated CLI, gateway tool, or platform-specific API: email, X/Twitter, Yuanbao groups/DMs, Philips Hue lights, or similar integrations.

The common class is not the vendor; it is the operating discipline: verify credentials without exposing secrets, choose the platform-specific branch, perform low-risk reads first, confirm before writes with user-visible side effects, and report real handles/status from the platform.

## Workflow selector

| User asks for... | Branch |
|---|---|
| reading, searching, composing, replying, or forwarding email via terminal | Email mailbox CLI |
| posting, replying, liking, searching, DMing, or uploading media on X/Twitter | X/Twitter CLI |
| @mentioning someone in a Yuanbao group or sending Yuanbao DMs | Yuanbao group messaging |
| controlling Hue lights, rooms, scenes, brightness, colors, or schedules | Philips Hue smart home |

## Shared operating rules

1. Check that the required CLI/tool exists and credentials are reachable using the least-secret-revealing status command.
2. Never print, read into context, or ask the user to paste credential files or tokens.
3. Start with a cheap read-only command when possible (`whoami`, auth status, list folders/resources, group/member lookup).
4. Confirm the exact target and message/action before side-effecting writes such as sending email, posting publicly, DMing, following, blocking, deleting, or changing a home device state.
5. For writes, report the platform's returned ID/status/recipient/device name; if verification fails, say so directly.

## Email mailbox CLI

Use when the user wants mailbox operations through an external terminal client such as Himalaya.

Rules preserved from the former `himalaya` skill:
- `himalaya` is separate from the Hermes Email gateway adapter; it operates a mailbox from terminal tools.
- Prefer structured output when available.
- For composing/replying/forwarding, prefer non-interactive piped templates over `$EDITOR` flows.
- Message IDs are folder-relative; re-list after folder changes.
- Store passwords through the user's secure mechanism; never ask them to paste secrets.

High-value pitfall:
- Himalaya folder aliases use `folder.aliases.<name>` in newer versions. Older `[accounts.NAME.folder.alias]` syntax can be silently ignored and cause duplicate sends if SMTP succeeds but save-to-Sent fails and a caller retries the command.

## X/Twitter CLI

Use when the user wants to operate X/Twitter through the official `xurl` CLI.

Rules preserved from the former `xurl` skill:
- Never read or print `~/.xurl`.
- Never use `--verbose` / `-v` in agent sessions because it can expose auth headers.
- Do not run auth commands with inline app secrets; the user must register app credentials outside chat.
- Check `xurl auth status` and a cheap read (`xurl whoami`, `xurl user`, or a tiny search) before writes.
- Confirm before posts, replies, likes, reposts, DMs, follows, blocks, mutes, media uploads, or deletes.

Docker/Hermes pitfall:
- In containerized Hermes, the tool subprocess `HOME` may differ from `HERMES_HOME`. Verify credentials under the exact `HOME` that tool commands use.

## Yuanbao group messaging

Use when a Yuanbao user asks to @mention a group member, query group/member info, or send a Yuanbao DM.

Rules preserved from the former `yuanbao` skill:
- In a Yuanbao group, the assistant's final text is the group message; do not claim you cannot send messages.
- For @mentions, query members first to get the exact nickname, then include `@nickname` in the final reply text.
- For private messages, use the Yuanbao DM tool rather than generic cross-platform `send_message`.
- Extract `group_code` from the current Yuanbao chat id when needed.
- If multiple members match, ask the user to disambiguate before sending.

## Philips Hue smart home

Use when the user wants Hue lights, rooms, zones, scenes, brightness, color temperature, or colors controlled through OpenHue or an equivalent Hue CLI.

Rules preserved from the former `openhue` skill:
- Bridge pairing requires local network access and often a physical bridge-button press on first setup.
- List resources before acting when names are ambiguous; Hue names can be case-sensitive.
- Check whether a bulb supports color before setting RGB/color values.
- For routines, cron jobs are appropriate, but scripts should stay quiet unless a meaningful event or error occurs.

## Adding a new platform branch

Do not create a new top-level micro-skill for every platform CLI unless the platform becomes large enough to need independent invocation. Add a branch here with:
- trigger shape
- credential-safety rules
- read-before-write preflight
- confirmation requirements for side effects
- common commands or tool calls
- vendor-specific pitfalls

## Verification checklist

- [ ] Chose the platform branch and verified prerequisites.
- [ ] Avoided exposing secrets or credential files.
- [ ] Ran a low-risk read/status check before any write.
- [ ] Confirmed externally visible side effects unless the user already gave exact action content and target.
- [ ] Reported real returned status/IDs or clearly stated the blocker.
