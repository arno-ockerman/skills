# First GitHub-issue workflow from Archon Web UI

Use this when a repository is already visible under **Projects** and the user wants their first issue-fixing workflow.

## MVP path: use the bundled workflow first

Do not scaffold repo-local `.archon/` files merely to get the first run working. Bundled workflows are automatically available in the project workflow picker.

1. Open the project in Archon Web UI.
2. Click **Start a new run**.
3. Select `archon-fix-github-issue`.
4. Provide an issue number or full GitHub issue URL, plus repository-specific completion constraints.
5. Start the run and inspect its worktree/branch, validation output, and draft PR.

Example input:

```text
Fix https://github.com/OWNER/REPO/issues/123 end-to-end. Follow the repository agent instructions, run the canonical verification command, and create a draft PR. Do not deploy or merge automatically.
```

## Preflight before spending an agent run

- Confirm the project is present and marked live/available in the UI.
- Confirm `archon-fix-github-issue` appears in the workflow picker.
- Read the repo's `AGENTS.md`/`CLAUDE.md`/`CODEX.md` and include its canonical Definition of Done in the run prompt.
- Confirm GitHub CLI/auth is exposed to the Archon container.
- Prefer a small, clearly scoped issue for the first smoke run. Avoid vague issues and security/auth/data-migration changes until the workflow path is proven.

## Bundled versus repo-local workflow

A bundled workflow is ideal for the first smoke run, but it may pin a provider/model (for example Claude) that differs from the user's preferred Codex setup. Do not claim the run uses Codex without checking the workflow metadata.

Create and commit a repo-local workflow only after the bundled run proves the full path, or when project-specific constraints require it. Typical reasons:

- enforce `provider: codex` and the preferred model;
- mandate a repository-specific verify command;
- always create draft PRs;
- prohibit deploy and auto-merge;
- add project-specific safety checks.

The Web UI/server reads repo-local workflows from its synced GitHub clone, so commit and push `.archon/workflows/`, commands, and config before expecting them to appear there.
