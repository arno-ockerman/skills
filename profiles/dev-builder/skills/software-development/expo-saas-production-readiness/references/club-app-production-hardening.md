# Club App production hardening reference

Concrete patterns captured from real Expo Router + Vercel + Supabase + Clerk hardening passes.

## Verified effective checks
Use these as the minimum shipping gate for this stack:

- `npm run lint`
- `npm run typecheck`
- `npm test -- --runInBand`
- `npm run export:web`
- `npm run check`
- `npm run e2e:release-critical` or full `npm run e2e` when critical flows changed

In one verified session, the app passed 35 test suites / 197 tests, exported web successfully to `dist`, and passed 5/5 Playwright smoke tests.

## Effective implementation patterns

### Dynamic Expo config
Use `app.config.ts` instead of placeholder-driven `app.json` when production config depends on secrets / CI values.

A good pattern is:

- `APP_ENV=production` requires `EXPO_PROJECT_ID`
- `updates.url = https://u.expo.dev/<EXPO_PROJECT_ID>`
- `extra.eas.projectId = EXPO_PROJECT_ID`

Verify both cases:

1. without `EXPO_PROJECT_ID` in normal mode => config resolves without production-only values
2. with `APP_ENV=production EXPO_PROJECT_ID=...` => config resolves with updates URL and EAS project ID

### Env checker behavior
The env checker must read values from env files, not just shell env.

Useful files to load:

- `.env`
- `.env.local`
- `.env.production`
- `.env.production.local`

This prevents false negatives where Expo build commands succeed because they load `.env.production`, but the custom validator claims keys are missing.

### CLI wrapper behavior
Repo-local wrappers should validate credentials before calling external CLIs.

Examples:

- Vercel: require `VERCEL_TOKEN` or an existing Vercel login session before `vercel pull/build/deploy`
- Supabase: require remote deployment credentials before `db push` / `functions deploy`
- EAS: require `EXPO_TOKEN` before builds

The wrapper should print a direct missing-credentials message and exit non-zero.

### Verification-loop behavior
When cleaning up a production blocker, use this loop:

1. run the broad gate (`lint`, `typecheck`, tests, export, E2E)
2. fix the highest-risk runtime issue first
3. rerun the failed gate
4. rerun the full shipping path
5. finish with an independent diff-focused review if hook order, async flow, or ESLint config changed

This is especially useful after touching auth, payments, bookings, onboarding, or modal state.

### Playwright/browser install behavior
If Playwright's default browser install location is unwritable, do not stop at the first install failure. Re-run browser install and E2E with an explicit writable `PLAYWRIGHT_BROWSERS_PATH`. Capture that in the repo docs or scripts if the project will be verified repeatedly in constrained environments.

### Lint containment behavior
If the repo has large pre-existing lint debt outside the shipping path, do not disable rules globally just to get green output. Prefer one of these:

1. fix the real runtime-risk issues directly
2. scope temporary suppressions to legacy files only
3. keep lint in the verification path, but document why some file-scoped debt remains non-blocking

This preserves value from lint while still allowing production hardening to finish.

### Coverage-artifact hygiene
Generated `coverage/` output often dirties git status after verification. Treat this as repo hygiene, not as a release blocker:

- ignore it in readiness judgment
- clean it before final commit if the repo should stay tidy
- do not mistake generated HTML/JSON deltas for unresolved product code changes

## CI gate lesson
When lint debt is legacy and unrelated to the release path, keep lint available but remove it from the blocking production gate until debt is intentionally cleaned up.

For this stack, the pragmatic blocking gate was:

1. lint (clean or explicitly file-scoped)
2. typecheck
3. tests
4. production web export
5. release-critical E2E

## Doc migration lesson
If the repo used old instructions like:

- "replace `EXPO_PROJECT_ID_PLACEHOLDER` in `app.json`"
- "update `eas.json` placeholders"

patch those immediately after moving to env-driven config.

The new source of truth should be:

- `EXPO_PROJECT_ID`
- `EXPO_TOKEN`
- `APPLE_ID`
- `ASC_APP_ID`
- `APPLE_TEAM_ID`
- `VERCEL_TOKEN`
- Supabase deploy secrets
