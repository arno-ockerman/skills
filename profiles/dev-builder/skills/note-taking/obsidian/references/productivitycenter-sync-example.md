# ProductivityCenter nightly GitHub sync example

This is the concrete example currently used for de gebruiker's AI context vault.

## Repo boundary
- Parent folder: `/opt/ai-context`
- Real Git repo: `/opt/ai-context/ProductivityCenter`
- Parent `.git` was archived because it only wrapped the nested repo and created confusion.

## Scripts
- Real sync: `/opt/data/profiles/dev-builder/scripts/sync-productivitycenter.sh`
- Midnight wrapper: `/opt/data/profiles/dev-builder/scripts/sync-productivitycenter-brussels-midnight.sh`

## Schedule
Because Hermes cron rejected inline `CRON_TZ=Europe/Brussels ...`, the working pattern is:
- cron schedule: `0 * * * *`
- wrapper checks local Brussels wall-clock time
- actual sync only runs when local time is `00:00`

## Job shape
- `no_agent=true`
- script value: `sync-productivitycenter-brussels-midnight.sh`
- no-op runs stay silent
- sync runs emit output only when something meaningful happened or an error occurred

## Durable lessons
1. Verify nested repo boundaries before automating.
2. In this Hermes environment, export `HOME=/opt/data` in Git automation scripts.
3. Set `git config core.filemode false` for note repos to avoid mode-only junk commits.
4. Manual script verification must succeed before creating the cron job.
