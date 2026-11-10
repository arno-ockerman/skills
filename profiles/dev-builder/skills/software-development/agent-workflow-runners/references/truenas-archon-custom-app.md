# TrueNAS SCALE Custom App pattern for Archon

Use this pattern when the user wants an Archon server/container in TrueNAS SCALE but wants to avoid duplicating shared Claude/Codex/auth/skills setup.

## Durable layout

- Archon-owned state: a dedicated dataset, e.g. `/mnt/<pool>/apps/archon/data` mounted to `/.archon`.
- Archon container home: a dedicated dataset, e.g. `/mnt/<pool>/apps/archon/home` mounted to `/home/appuser`.
- Shared external CLI tooling/auth/skills: mount existing `/opt/ai-tools` read-write at `/opt/ai-tools`.
- User context: mount `/opt/ai-context/ProductivityCenter` at the same path.

This keeps Archon's database/runtime state separate while reusing shared Codex/Claude authentication and skills.

## Copy-paste template

See `templates/truenas-archon-custom-app.yml`.

## Pitfalls

- Do not use the compose with `build: .` in TrueNAS Custom App unless intentionally building from a source checkout; prefer `ghcr.io/coleam00/archon:latest`.
- Do not put Archon state under `/opt/ai-tools/config/archon` if the user explicitly wants a separate Archon dataset; mount the new dataset to `/.archon` instead.
- Keep `/opt/ai-tools` mounted so wrappers such as `/opt/ai-tools/bin/codex` and `/opt/ai-tools/bin/claude` can reuse existing authentication.
- If Telegram copy/paste is inconvenient, create a `.yml` artifact and deliver it as media rather than only pasting a long YAML block.
