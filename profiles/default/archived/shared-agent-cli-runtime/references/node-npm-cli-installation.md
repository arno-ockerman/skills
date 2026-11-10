# Node/npm CLI Installation in Shared Runtime

## Pattern Used

Install npm global packages with custom prefix pointing to the shared runtime:

```bash
npm install -g <package> --prefix /opt/ai/tools
```

This automatically creates symlinks in `/opt/ai-tools/bin/` pointing to `../lib/node_modules/<package>/dist/...`.

## Packages Installed This Session

| Package | CLI Command(s) | Version | Notes |
|---------|---------------|---------|-------|
| `supabase` | `supabase` | 2.106.0 | Supabase CLI |
| `vercel` | `vercel`, `vc` | 54.14.0 | Vercel CLI (aliased as `vc`) |
| `firebase-tools` | `firebase` | 15.20.0 | Firebase CLI — **package is `firebase-tools`, not `firebase`** |
| `clerk` | `clerk` | 1.5.0 | Clerk CLI — **package is `clerk`, not `@clerk/clerk-cli`** |

## Key Discoveries

### Clerk CLI package name
The Clerk CLI is published as `clerk` on npm (not `@clerk/clerk-cli` which returns 404). Verified via:
```bash
npm search clerk  # shows "clerk - Clerk CLI"
```

### Firebase CLI package name
The Firebase CLI is published as `firebase-tools` (not `firebase` which is the SDK).

### Wrapper auto-creation
After `npm install -g --prefix /opt/ai-tools`, symlinks appear in `/opt/ai-tools/bin/`:
```
supabase -> ../lib/node_modules/supabase/dist/supabase.js
vercel -> ../lib/node_modules/vercel/dist/vc.js
vc -> ../lib/node_modules/vercel/dist/vc.js
firebase -> ../lib/node_modules/firebase-tools/lib/bin/firebase.js
clerk -> ../lib/node_modules/clerk/bin/clerk
```

These work immediately when `/opt/ai-tools/bin` is in PATH (via the shared env file).

## Verification

After installation, source the shared env and verify:
```bash
source /opt/ai-tools/bin/tool-env
supabase --version
vercel --version
firebase --version
clerk --version
```

## Related

- Main skill: `shared-agent-cli-runtime` → Node/npm CLIs section
- Bootstrap: `.bashrc` and `.profile` both source `/opt/ai-tools/config/shared/env.sh`