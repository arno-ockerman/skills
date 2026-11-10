---
name: multi-tenant-saas-security-audit
description: Security audit patterns for multi-tenant SaaS applications (RLS, RPC SECURITY DEFINER, auth integration, tenant isolation)
category: software-development
---

# Multi-Tenant SaaS Security Audit

Class-level skill for auditing security in multi-tenant SaaS applications using Supabase/PostgreSQL, Clerk/Auth, and React Native/Expo frontends.

## Trigger Conditions
- User requests architecture review / code review for production readiness
- Multi-tenant app with row-level security (RLS)
- SECURITY DEFINER RPC functions accepting client-supplied user IDs
- Clerk/Supabase auth integration
- Mobile app (Expo/React Native) + Supabase backend

## Core Audit Patterns

### 1. RLS Tenant Isolation Checks
**Always verify every SELECT policy scopes to tenant:**
```sql
-- BAD: Cross-tenant leak
USING (status = 'scheduled')

-- GOOD: Tenant-scoped
USING (
  status = 'scheduled'
  AND club_id IN (
    SELECT club_id FROM club_members WHERE user_id = requesting_user_id()
  )
)
```

**Checklist:**
- [ ] Every table with tenant data has RLS enabled
- [ ] Every SELECT policy includes tenant membership check
- [ ] UPDATE/DELETE policies have matching `WITH CHECK` clauses
- [ ] No policies use `auth.jwt() ->> 'role'` (Clerk doesn't put roles in JWT)

### 2. SECURITY DEFINER RPC Audit
**Red flag: RPC accepts `p_user_id` / `p_club_id` from client**
```sql
-- VULNERABLE
CREATE FUNCTION book_workout_session(p_user_id UUID, p_club_id UUID, p_session_id UUID)
SECURITY DEFINER ...

-- SECURE: Derive from auth context
CREATE FUNCTION book_workout_session(p_club_id UUID, p_session_id UUID)
SECURITY DEFINER
AS $$
DECLARE v_user_id TEXT := auth.uid()::TEXT;
BEGIN
  -- Verify membership
  IF NOT EXISTS (SELECT 1 FROM club_members WHERE club_id = p_club_id AND user_id = v_user_id AND status = 'active') THEN
    RAISE EXCEPTION 'Not a member';
  END IF;
  ...
```

**Fix pattern:** Replace all client-supplied identity params with `auth.uid()` derived values. Add admin checks where needed (`is_club_admin()` helper).

### 3. Clerk → Supabase Auth Integration
**Required setup:**
- Clerk Third-Party Auth in Supabase (not deprecated JWT template)
- JWT must include `role: authenticated` claim
- Client-side token bridge: `getToken()` → Supabase `Authorization: Bearer <clerk_token>`
- Handle `PGRST301` = Supabase doesn't trust Clerk keys

### 4. Edge Function Security
**Every Supabase Edge Function must:**
- Verify `Authorization: Bearer <token>` header
- Create Supabase client with user's token: `createClient(url, anon, {global: {headers: {authorization}}})`
- Call `auth.getUser()` to validate
- Check ownership/role before mutating tenant data
- Use service role key ONLY for admin operations after verification

### 5. Secrets Management
- **Never** hardcode secrets in client code (QR salts, API keys)
- Use Supabase Vault / Env vars for: `app.qr_secret`, `CLERK_SECRET_KEY`, `MOLLIE_API_KEY`, webhook secrets
- QR tokens: generate server-side (signed JWT or HMAC), not client-side hash

### 6. Common Vulnerability Classes
| Class | Example | Fix |
|-------|---------|-----|
| Cross-tenant read | `workout_sessions` SELECT without club_id check | Add tenant membership subquery |
| User impersonation | RPC accepts `p_user_id` | Use `auth.uid()` inside function |
| Credit forgery | `add_credits(p_user_id, ...)` | Derive user, verify admin role |
| Billing manipulation | `start-trial` without owner check | Verify `club_members.role = 'owner'` |
| Data corruption | UPDATE policy without `WITH CHECK` | Add identical `WITH CHECK` clause |

## Production Readiness Checklist

### Database
- [ ] RLS on ALL tenant tables (including new: wallets, loyalty, rewards, purchases)
- [ ] All RPCs use `auth.uid()` derived identity
- [ ] Helper functions exist (`requesting_user_id()`, `is_club_admin()`)
- [ ] Migrations are idempotent + have rollback plan
- [ ] Supabase Vault configured for secrets

### Auth
- [ ] Clerk Third-Party Auth connected
- [ ] JWT has `role: authenticated`
- [ ] Token bridge works on native + web
- [ ] Email verification required

### Edge Functions
- [ ] All verify auth header
- [ ] All check tenant ownership before mutation
- [ ] CORS origins from env, not hardcoded
- [ ] Idempotency on webhooks (payment_id unique)

### Frontend
- [ ] No hardcoded secrets/colors (design tokens)
- [ ] Error boundaries hide stacks in production
- [ ] Env validation at bootstrap (zod)
- [ ] Single auth route per flow (no duplicate sign-in/sign-up)

### CI/CD
- [ ] Lint → Typecheck → Test → E2E smoke → Build
- [ ] Supabase `db push` in CI for staging
- [ ] Preview deployments per PR

## Pitfalls & Gotchas

1. **`booking-flow-schema.sql` vs migration fixes** — Old vulnerable RPCs often coexist with fixed versions. Must replace ALL occurrences, not just add new migration.

2. **Table name drift** — `club_members` vs `club_memberships` inconsistency breaks policies. Grep for both.

3. **Clerk role claim** — Roles are in `publicMetadata`, not JWT. Policies using `auth.jwt() ->> 'role'` are broken OR dangerous if mapped.

4. **Web auth preview mode** — `EXPO_PUBLIC_ENABLE_WEB_AUTH` must be set + Supabase configured + full restart (`--clear`).

5. **MMKV persist migration** — Zustand `persist` needs `version` + `migrate` for schema changes.

6. **QR check-in** — Client-side hash with hardcoded salt = attendance fraud. Move signing server-side.

## Verification Scripts

See `scripts/` for:
- `check-rls-coverage.sql` — finds tables missing RLS/policies
- `find-vulnerable-rpcs.sql` — finds SECURITY DEFINER funcs with user_id params
- `audit-edge-functions.sh` — checks auth verification patterns

## References
- `references/club-app-audit-2026-06-15.md` — Full audit transcript for Club-app (7 critical findings: cross-tenant RLS leak, credit forgery RPCs, QR secret in client, trial ownership bypass, wallet UPDATE missing WITH CHECK, duplicate auth routes, table name drift)
- `references/rls-patterns.md` — Reusable RLS policy templates
- `references/rpc-hardening.md` — SECURITY DEFINER hardening patterns
- `references/deployment-checklist.md` — Production deployment checklist template
- `references/ci-cd-pipeline.yml` — GitHub Actions workflow (lint → test → e2e → preview → production)
- `references/clerk-webhook.ts` — Edge Function implementation with Svix signature verification
- `references/seed-staging.sql` — Test data seed template (3 clubs, members, sessions, credits, loyalty, rewards)
- `references/qr-vault-pattern.md` — QR secret in Supabase Vault pattern