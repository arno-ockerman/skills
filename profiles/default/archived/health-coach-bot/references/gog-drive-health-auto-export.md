# Shared GOG Google Drive access for Health Auto Export

This reference captures the concrete reusable pattern from this session for accessing Apple Health export files through the shared `/opt/ai-tools` Google CLI integration.

## Why this matters

In this environment, Google auth is centralized under `/opt/ai-tools`. Before setting up a new Google OAuth flow inside Hermes, check whether `gog` is already authenticated.

## Reusable command pattern

Load the shared GOG environment first:

```bash
set -a; source /opt/ai-tools/config/gog/gog.env; set +a
```

Check status:

```bash
/opt/ai-tools/bin/gog status -j
```

Expected useful fields:
- authenticated account email
- credentials path
- client name

## Drive traversal pattern used successfully

Search for the top-level folder:

```bash
/opt/ai-tools/bin/gog drive search Openclaw -j --max 20
```

List a folder's children:

```bash
/opt/ai-tools/bin/gog drive ls --parent <FOLDER_ID> -j --max 100
```

Download a representative file:

```bash
/opt/ai-tools/bin/gog drive download <FILE_ID> --output /opt/data/tmp/health-export/<filename> -j
```

## Folder IDs found in this session

These IDs are session-discovered details; re-verify if anything moves.

- Private Drive folder ID: `<CONFIGURE_LOCALLY>` (removed from public export).
- Private Drive folder ID: `<CONFIGURE_LOCALLY>` (removed from public export).
- Private Drive folder ID: `<CONFIGURE_LOCALLY>` (removed from public export).

## File naming pattern observed

Daily files were named like:

- `Apple-health-daily-2026-06-06.json`
- `Apple-health-daily-2026-06-05.json`
- `Apple-health-daily-2026-06-04.json`

So the durable pattern is:

```text
Apple-health-daily-YYYY-MM-DD.json
```

## Schema hints from the inspected file

A downloaded daily file had top-level shape:

```json
{
  "data": {
    "metrics": [ ... ]
  }
}
```

Observed metric names included:
- `apple_sleeping_wrist_temperature`
- `apple_exercise_time`
- `apple_stand_hour`

## Practical lesson

For health-coach workflows in this environment:
- prefer the existing shared `gog` integration
- traverse Drive folders by ID once discovered
- inspect one daily JSON before designing broader analysis
- treat folder IDs as convenient handles, but not permanent guarantees
