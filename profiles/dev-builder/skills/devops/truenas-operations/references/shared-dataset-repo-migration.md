# Migrating repositories between shared datasets

Use this when consolidating per-app clones into one dataset that several agents share, so every agent works the same checkout instead of keeping a private copy.

## Rule: copy, verify, then remove

Never move the source first. A move that fails halfway leaves a repository that is neither in the old place nor complete in the new one, and local uncommitted work is the part you cannot regenerate. Copy, prove the copy equivalent, and only then discuss deleting the source.

## Procedure

1. **Inventory the real repositories.** Walk the candidate roots looking for `.git` (a directory, or a file in a git-worktree/linked checkout). Prune `.venv`, `node_modules`, `dist`, `build`, `target`, `cache`, `__pycache__`, `.pytest_cache` while walking — without pruning, the walk does not terminate on real projects. Record the remote URL, not just the path; a directory without a remote is usually a fixture, not a project.
2. **Capture identity before touching anything**, per repository:

   ```bash
   git -C <repo> rev-parse HEAD
   git -C <repo> branch --show-current
   git -C <repo> remote get-url origin
   git -C <repo> rev-parse --abbrev-ref --symbolic-full-name '@{u}'
   git -C <repo> status --porcelain=v1
   git -C <repo> stash list
   ```

   The working-tree status matters most: uncommitted changes and untracked directories are exactly what a naive clone-and-delete loses.
3. **Copy with a tar pipe**, which preserves symlinks, modes, timestamps, and hardlinks:

   ```bash
   tar -C "$src" -cf - . | tar -C "$dst" -xf -
   ```
4. **Verify equality**, then integrity:

   ```bash
   git -C <dst> fsck --no-progress --no-dangling
   ```

   Require the full identity snapshot from step 2 to match, including the status line order. Report a per-repository verdict rather than a single overall pass.
5. **Smoke-test the destination** by running the project's own fast check from the new path, so a broken copy is caught before the source is at risk.
6. Leave the source in place until the operator confirms the new paths are in use.

## Pitfalls

- **A Python `venv` is not relocatable, and a broken copy can look healthy.** Console scripts carry an absolute shebang and editable installs write an absolute path into a `.pth`, so a copied venv executes against the ORIGINAL source directory and interpreter. It appears to work while silently running stale code. Detect it by grepping the destination venv for the old absolute path, then rebuild rather than repair:

  ```bash
  cd <dst>/<project> && rm -rf .venv && uv sync
  ```

  Re-run the project's tests from the new path afterwards; that is the evidence the rebuild took.
- **`node_modules` IS relocatable.** Confirm by comparing file counts between source and destination instead of assuming you must reinstall. Conversely, do not "fix" a missing `node_modules` without first checking whether the source ever had one.
- **A long copy can outlive a single tool call.** Run the copy in the background, then re-run the SAME idempotent migration command: it skips destinations that already verify and continues with the rest. Verify the destination independently rather than trusting the last output of an interrupted run.
- **`--dry-run` must not print the success sentence.** A dry run that ends with "everything is in place" teaches the operator the opposite of the truth; say explicitly that nothing was copied.

## Filling the dataset from a Git host

Use this when the goal is the whole repository inventory rather than relocating one checkout.

1. **Inventory the host, then diff against disk.** Compare on the REMOTE URL, never the directory name: a matching name is not proof the same repository is present, and a different name is not proof it is absent.

   ```bash
   gh repo list <owner> --limit 500 \
     --json name,visibility,isFork,isArchived,diskUsage,primaryLanguage
   ```

2. **Clone private repositories with `gh repo clone`, not `git clone`.** A plain HTTPS clone has no credential helper and fails asking for a username; `gh repo clone` injects the token from the authenticated session.

   ```bash
   gh repo clone <owner>/<repo> <destination>
   ```

3. **Order the work by size ascending**, so the cheap repositories prove the credentials and the destination before a large one commits you to a long transfer.
4. **Decide per repository and report the bucket each one fell into** — cloned, already present, or deliberately skipped with the reason. A summary that lists only what was cloned hides the decisions the operator needs to review.
5. **Never create a second working copy of a repository that commits on a timer** (a notes or knowledge vault, a sync target). Two checkouts diverge and conflict. When one canonical copy already lives in a shared dataset that every app mounts, that IS the shared copy — cloning it again is a regression, not coverage.
6. **Surface a remote that no longer resolves.** A repository deleted upstream leaves the local clone as the only copy of that history; report it and suggest pushing it somewhere durable.
7. **Report the exceptions instead of smoothing them over:** an upstream repository with no commits clones with a warning and an empty tree, a repository's default branch may not be `main`, and organization-owned repositories are not the operator's personal ones — list them separately and ask before pulling them in.

## Reference sweep after the move

The move is not finished while configs still point at the old absolute path.

- Search profiles, skill references, scripts, cron stores, deploy files, and tool configs for the old path.
- Scope the walk by file extension and prune `logs`, `cache`, `sessions`, `node_modules`, and `__pycache__`. Unpruned, log and cache files produce hundreds of meaningless hits and bury the handful that matter.
- Check scheduler state explicitly: a cron job or board database carrying the old path will fail silently at the next tick.
- Leave project-internal documentation alone during the migration; correcting a repository's own docs is a separate follow-up, never a side effect of a move. See *Correcting the repository's own documentation* below.
- Some targets are outside your write scope: a protected agent-instruction file needs interactive approval, and a write-safe root may exclude sibling datasets. Report the exact diff for the operator to apply. Never route around the refusal through another tool.
- Ignore hits that regenerate: a build cache, a tool-managed history file, compiled output. They are typically untracked and rewrite the old path on next use. Confirm with `git check-ignore -v` before dismissing a hit, so a genuinely tracked file is not waved away.

## Removing or archiving the source

Complete the reference sweep first: the whole reason to remove the source is that something might still resolve to it.

The gate for removal is CONTAINMENT, not equality. Once the destination is in use it legitimately gains commits, so an equality test on HEAD refuses a safe removal and trains you to distrust a correct result. Require:

- the source's HEAD is an ancestor of the destination's HEAD:

  ```bash
  git -C <dst> merge-base --is-ancestor <src-head> HEAD
  ```

- no working-tree entry exists in the source that the destination lacks (set difference of `git status --porcelain=v1`);
- the destination already passed its own migration verification.

A destination that is AHEAD of the source is the expected evidence that the migration is in use. Report it as progress, not as a discrepancy.

Archive before deleting, and prove the archive before removing the original:

1. `tar -czf <archive> -C <parent> <name>` — keep `.git`; the history is the point.
2. `gzip -t <archive>` to prove container integrity.
3. Extract a sample back out and compare byte-for-byte (sha256) against the originals. A clean `tar` exit code proves the archive is readable, not that its content matches.
4. Store the archive's sha256 beside it.
5. Then remove the tree, and put the exact restore command in the report.

- **Compare counts computed the SAME way on both sides.** A directory-only walk against a full archive listing differs by the file count and tells you nothing about completeness.

## Correcting the repository's own documentation

The migration itself leaves a repository's own docs alone. When the operator asks for them afterwards, do it as a separate, tightly scoped commit.

- Gate the edit on the expected number of occurrences and abort WITHOUT writing when the count differs. An unguarded replace in prose can also match a path that is a prefix of a longer path.
- Stage only the files you changed. A shared repository often carries another session's uncommitted work, and a blanket `git commit -a` sweeps it into your change.
- Match the repository's existing commit identity instead of passing one in; history that alternates authors for the same agent is noise.
- Check the repository's real convention before choosing a direct commit versus a branch and PR: look for merge commits and for agent-instruction files. An established direct-to-main history IS the convention.
- Report whether the commit was pushed. A local-only commit is easily mistaken for a published one.

## Verification checklist

- [ ] Identity snapshot matches for every repository, including a non-empty working tree where one existed.
- [ ] `git fsck` clean on every destination.
- [ ] Any venv rebuilt and the project's tests pass from the new path.
- [ ] No executable config, cron entry, or agent instruction still references the old path.
- [ ] Source repositories untouched (until a removal gate passes).
- [ ] For a removal or archive: the destination contains the source HEAD, the source holds no unique change, the archive passed integrity plus byte-sample checks, and the restore command was reported.
- [ ] For a clone-in sweep: every repository on the host is accounted for as cloned, present, or explicitly skipped with a reason.
