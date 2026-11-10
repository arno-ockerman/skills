---
name: note-taking-tools
description: "Sync knowledge vaults via Git (git-backed-vault-sync) and read/search/create/edit Obsidian notes. Use for personal knowledge management, vault synchronization, and markdown-based note workflows."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [git, vault, sync, Obsidian, markdown, knowledge-management]
    related_skills: [productivity-tools, research-workflow, visual-creative]
---

> Reference: `references/apple-notes-google-drive-capture.md` covers the Google Drive -> ProductivityCenter intake workflow for Apple Notes/Voice Memos, including the key pitfall that Apple Notes ZIP markdown often contains only structure while handwritten content lives in PDF/image attachments.

# Note-Taking Tools — Knowledge Management

Covers Git-backed vault synchronization and Obsidian vault operations.

---

## Quick Selection Guide

| Task | Tool | Subsection |
|------|------|------------|
| Sync note vault via Git with safe commit→rebase→push | git-backed-vault-sync | **1. Git-Backed Vault Sync** |
| Read/search/create/edit Obsidian notes | Obsidian API | **2. Obsidian** |

---

## 1. Git-Backed Vault Sync

### Purpose
Sync a personal knowledge repo (Obsidian vault, Git-backed notes, or any markdown repo) through Git with safe commit→rebase→push flow and checks for credential/home mismatches.

### When to Use
- User wants their note vault synchronized across machines
- User wants automated cron job to push/pull changes
- User wants safe Git operations with credential verification

### Preflight Checklist (Run Before Creating Cron)
1. **Writable repo** — Verify agent can write to repo root and `.git/`
2. **Git safe.directory** — Handle `detected dubious ownership` with `git -c safe.directory=/abs/path`
3. **Remote configured** — Check `origin` exists
4. **Repo initialization state** — Check current branch and commits
5. **Commit identity** — Ensure local `user.name`/`user.email` exist
6. **No-op silence** — Script stays silent when no changes

### Recommended Sync Script Behavior

Stage explicit paths by default so a sync does not absorb the owner's unrelated work. Use `git add -A` only for a dedicated single-writer vault whose sync job intentionally owns every change.

```bash
# 1. Inspect, then stage only the paths this run owns
git status --short
git add -- "${OWNED_PATHS[@]}"

# Dedicated whole-vault autosync only:
# git add -A

# 2. Create timestamped commit only when changes exist
git diff --cached --quiet || git commit -m "vault sync: $(date -Iseconds)"

# 3. Fetch/pull with rebase when upstream branch exists
git fetch origin
if git rev-parse --verify origin/$(git branch --show-current) >/dev/null 2>&1; then
    git pull --rebase origin $(git branch --show-current)
fi

# 4. Push to origin when configured
git push origin $(git branch --show-current) 2>/dev/null || true

# 5. Fail loudly on rebase/push conflicts
```

### Cron Job Setup
```bash
# Using cronjob tool
cronjob create \
  --schedule "30m" \
  --prompt "Run the vault sync script for the knowledge repo at ~/notes. Follow the git-backed-vault-sync preflight checklist. Stay silent on no-op runs." \
  --skills "git-backed-vault-sync" \
  --name "vault-sync"
```

### Pitfalls
- **Don't create cron first** — Preflight conditions must pass first
- **Don't assume global git config** — Use repo-local identity if needed
- **Don't ignore rebase conflicts** — Fail loudly, don't force push
- **Credential mismatches** — Check home directory vs credential paths before sync

---

## 2. Obsidian

### Capabilities
- Read notes by path or search
- Search across vault (content or filename)
- Create new notes with frontmatter
- Edit existing notes (append, replace sections)
- Handle Obsidian-specific syntax: `[[wikilinks]]`, `#tags`, `properties::`

### Read Note
```bash
# By path
read_file "~/Obsidian Vault/Notes/project-alpha.md"

# Search content
search_files "project alpha" --path "~/Obsidian Vault" --file_glob "*.md"

# Search by filename
search_files "project-alpha" --target files --path "~/Obsidian Vault"
```

### Create Note
```bash
write_file "~/Obsidian Vault/Notes/new-note.md" "
---
tags: [project, planning]
created: $(date -Iseconds)
---

# New Note

Content here...
"
```

### Edit Note
```bash
# Append
patch "~/Obsidian Vault/Notes/note.md" "
## Section

Content
" "
## Section

Content

### New Subsection
Additional content
"
```

### Obsidian-Specific Patterns
```markdown
# Wikilinks
See [[Related Note]] for details.

# Tags
#project/alpha #planning

# Properties (YAML frontmatter)
---
status: active
due: 2024-12-31
tags: [project, planning]
---
```

### Sync with Git
```bash
# Inside vault directory: stage only notes changed by this task
git status --short
git add -- path/to/note.md path/to/other-note.md
git commit -m "Obsidian: update project notes"
git push origin main
```

After pushing, read the remote branch and target file back before claiming sync succeeded. A local success message or tracking ref can be stale when another autosync process is active.

### Integration with Git-Backed Sync
The git-backed-vault-sync preflight checklist handles the Git operations. Obsidian vault is just a directory of markdown files — the sync script treats it as any Git repo.

---

## 3. Capture Intake Pipelines (Raw → Processed Notes)

### Purpose
Use this when the user captures source material on another device (voice memos, tablet handwriting, exported PDFs, scans) and wants it folded into a markdown knowledge base without mixing raw artifacts into the final notes layer.

### Recommended Architecture
Keep **raw capture** and **processed knowledge** separate:

- `raw/` = immutable intake archive from cloud/device sync
- `notes/` = durable markdown knowledge after extraction/review
- `raw/manifests/` = machine-readable catalog/status
- `raw/rendered/` = derived page images for visual review when OCR/text extraction is weak
- `references/` = human docs about the workflow
- `scripts/` = sync/extract/review entrypoints

### Good Fit
- iPhone Voice Memos → transcript → notes
- iPad/Apple Pencil notes exported as PDF → text/vision extraction → notes
- Cloud folder intake (Google Drive, Dropbox, etc.) where the source device already has a reliable share flow

### Recommended Job Split
Use **two jobs**, not one giant weekly batch:

1. **Frequent sync+extract job**
   - pull new files from the cloud intake folder
   - normalize filenames
   - store locally under `raw/`
   - update a catalog/manifests file
   - run cheap extraction/transcription immediately
   - stay silent on no-op runs

2. **Weekly agent review job**
   - read only items still marked pending in the catalog
   - inspect transcripts / extracted text / rendered pages
   - write concise markdown notes into `notes/`
   - mark catalog entries as processed with the destination note path

### Why This Split Works
- avoids a large backlog building up before review
- keeps expensive/agentic interpretation separate from deterministic ingestion
- preserves raw evidence for later re-processing when prompts or models improve
- fits personal knowledge systems better than a generic `inbox/` graveyard

### Capture Pattern
1. Create one cloud intake root plus source-specific subfolders.
2. Sync new files into local `raw/<source>/` folders.
3. Maintain a catalog JSON with source path, cloud id, timestamps, checksum/size, extraction status, and processed note path.
4. Extract deterministic artifacts first:
   - audio → transcript text
   - PDF → embedded text if available
   - PDF pages → rendered images for later vision review
5. Let the review agent create or update markdown notes only after extraction exists.

### File-Naming Guidance
Prefer stable, human-readable names that sort well:

- `voice-YYYY-MM-DD-topic.m4a`
- `note-YYYY-MM-DD-topic.pdf`

This makes later dedupe, search, and note linking easier.

### Pitfalls
- **Do not write raw captures directly into `notes/`** — preserve an immutable source layer.
- **Do not rely on one weekly job for everything** — sync/extract should happen more often.
- **Do not assume handwritten PDFs have usable embedded text** — render pages for visual interpretation when extraction is sparse or messy.
- **Do not lose item state** — keep a manifest/catalog so the review job knows what is pending vs processed.
- **Do not create a dead `inbox/` dump** — every captured item should move through a tracked pipeline.

### Support Reference
See `references/raw-to-notes-capture-pipeline.md` for a concrete Google-Drive-based example with cron layout and folder conventions.

---

## Cross-Cutting Patterns

| Pattern | Tools |
|---------|-------|
| Knowledge capture → sync | Obsidian edit → git-sync cron |
| Raw capture → processed notes | Cloud intake → local raw archive → extract → weekly review |
| Research → vault | arXiv/blogwatcher → Obsidian notes → git-sync |
| Project notes → sync | Linear/GitHub issues → Obsidian → git-sync |
| Cross-machine access | git-sync on Machine A → git-sync on Machine B |

---

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Sync script runs but CWD drifts | Use absolute paths in script; `workdir` in cron |
| Obsidian vault not a Git repo | `git init` inside vault first |
| Credential helper fails | Check `git config credential.helper` and `~/.git-credentials` |
| Wikilinks break on sync | Use relative paths; avoid moving files without updating links |
| Binary files in vault | Add to `.gitignore` or use Git LFS |
| Merge conflicts in markdown | Resolve manually; avoid concurrent edits on same note |