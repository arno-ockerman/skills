---
name: health-coach-bot
description: "Set up and operate a Hermes-based personal health coach bot for meal-photo macro tracking and Apple Health export analysis."
version: 1.0.0
created_by: agent
author: Hermes Agent
license: CC0-1.0
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, telegram, health, nutrition, macros, apple-health, google-drive, gog]
---

# Health Coach Bot

Use this skill when the user wants Hermes to act as a personal health coach focused on meal logging, macro estimation, Apple Watch / Apple Health trend analysis, and gentle accountability.

## When to use

Trigger this skill when the user wants any combination of:
- a separate Hermes persona/profile for health coaching
- a dedicated Telegram bot for meals, macros, movement, or recovery
- meal-photo logging with estimated calories/macros
- Apple Health / Apple Watch export analysis
- trends tied to recovery-aware coaching for inflammatory / rheumatic conditions

## Core approach

Prefer **separate Hermes profiles** over one all-purpose assistant. For this class of work, keep the health coach isolated from coding/project assistance so memory, sessions, and tone do not mix.

Recommended split:
1. `health-coach` — meals, macros, movement, recovery, Apple Health exports
2. `dev-builder` — software/projects

## Setup flow

### 1) Create a dedicated profile
Create a dedicated Hermes profile for health coaching so it gets its own:
- `SOUL.md`
- memory
- sessions
- gateway state
- cron jobs

Design the persona for:
- Dutch, direct, low-fluff coaching
- practical guidance only
- recovery-aware movement and nutrition
- no extreme diet or training advice
- caution with flare-ups, stiffness, fatigue, and poor sleep

### 2) Use a dedicated Telegram bot token
For true separation on Telegram, the health profile needs its **own bot token**.

Rules:
- do **not** reuse the default profile token
- each profile should have its own Telegram bot
- put the token in the profile-local `.env`
- verify with Telegram `getMe` before telling the user it works
- start the profile-specific gateway and verify status

### 3) Make meal logging frictionless
The user should be able to send:
- a meal photo
- short free text
- or both together

Do **not** force perfect structured logging first.

Preferred response shape:
- Log
- Macro-inschatting
- Dagtotaal tot nu
- Goed
- Beter/aanvullen
- Volgende kleine stap

## Macro tracking guidelines

For body recomposition goals (fat loss + muscle gain):
- prioritize protein adequacy
- keep calorie estimates practical rather than precise
- treat photo-based macro estimates as **approximations**
- keep a running day total when the user logs multiple meals in one day
- avoid guilt-heavy or obsessive framing

When the user sends only a photo:
1. identify likely meal components
2. estimate kcal / protein / carbs / fats with explicit uncertainty
3. give one small improvement suggestion at most
4. keep the answer short and useful

## Apple Health integration pattern

Do **not** assume direct HealthKit access from Hermes/Linux.
The stable pattern is:

`Apple Health / Apple Watch -> export app -> JSON/CSV -> Hermes`

In practice, prefer an export tool on iPhone (for example Health Auto Export) and analyze the resulting files from shared storage.

## Google Drive via shared GOG integration

If this environment uses the shared `/opt/ai-tools` tool root, check for an existing `gog` setup before creating a new Google auth flow.

Preferred pattern:
1. check for `/opt/ai-tools/bin/gog`
2. load `/opt/ai-tools/config/gog/gog.env`
3. use `gog status -j` to confirm the authenticated Google account
4. access Drive through that existing integration rather than duplicating OAuth inside Hermes

This matters in shared setups where auth is centralized under `/opt/ai-tools` so both Hermes and other agents reuse the same Google login.

See `references/gog-drive-health-auto-export.md` for the concrete command pattern and folder structure found in this environment.
See `references/health-analysis-output-style.md` for the preferred output style: conclusion-first, interpretation, practical tips, and motivation instead of raw metric dumps.

## Health Auto Export file handling

When the export app writes one file per day:
- locate the parent folder first
- confirm the naming pattern (for example `Apple-health-daily-YYYY-MM-DD.json`)
- download one representative file
- inspect the top-level schema before designing analysis
- identify high-value metrics first instead of trying to use everything

Typical useful categories:
- sleep-related metrics
- exercise time
- stand hours
- heart rate / resting heart rate
- HRV
- steps / walking-running distance
- wrist temperature
- workouts / active energy
- body weight

## Coaching interpretation rules

For users with inflammatory or rheumatic constraints:
- interpret metrics through the lens of recovery, not only performance
- avoid overly strong conclusions from one datapoint
- downshift training recommendations when fatigue, poor sleep, or flare signals are present
- prefer consistency and load management over aggressive optimization

Preferred analysis output for health and Apple Health trend reviews:
- do **not** lead with raw day-by-day numbers unless the user explicitly asks for them
- lead with **conclusions, interpretation, practical next steps, and motivation**
- summarize patterns over rolling windows such as the last 3, 5, and 7 days instead of dumping every datapoint
- connect sleep / recovery / movement trends to likely real-world impact (energy, stiffness, pain, training readiness)
- end with 1-3 concrete improvement tips and a short coaching-style encouragement
- treat detailed metrics as supporting evidence, not the main output

## Pitfalls

- Don’t keep everything in the default Hermes profile if the user wants distinct bot personalities.
- Don’t require exact macros from meal photos; always frame them as estimates.
- Don’t start a second Telegram profile with the same bot token.
- Don’t build a new Google auth flow if `/opt/ai-tools` already provides a working shared `gog` login.
- Don’t claim Apple Health is directly integrated if the actual setup is file export + analysis.

## Verification checklist

Before saying the setup works, verify:
1. the dedicated profile exists
2. the profile-local `.env` contains the bot token
3. Telegram `getMe` returns the expected bot username
4. the profile gateway is running
5. Drive access works through `gog` if health exports live there
6. at least one export file can be located and read
