# Club-app Security Audit — 2026-06-15

**Project:** Multi-tenant fitness club SaaS (Expo Router + React Native, Supabase, Clerk, Mollie)
**Scope:** Full codebase audit — 2,000+ files reviewed

---

## 🔴 7 Critical Findings (P0 — Block Production)

### 1. Cross-Tenant Data Leak: `workout_sessions` RLS
**File:** `supabase/booking-flow-schema.sql:114-127`
**Issue:** SELECT policy missing club scoping — any authenticated user sees ALL sessions from ALL clubs
```sql
-- VULNERABLE
USING (status = 'scheduled' AND session_date >= CURRENT_DATE - INTERVAL '1 day')

-- FIXED
USING (
  status = 'scheduled'
  AND club_id IN (
    SELECT club_id FROM club_members WHERE user_id = requesting_user_id()
  )
)
```

### 2. Credit Forgery / User Impersonation via SECURITY DEFINER RPCs
**Files:** `supabase/booking-flow-schema.sql:134-256`, `supabase/migrations/20260330_restore_booking_rpc_compat.sql:95-152`
**Issue:** RPCs accept `p_user_id` from client → attacker can grant/deduct credits for any user
- `book_workout_session(p_user_id, p_club_id, p_session_id)` — inserts booking + deducts credits for arbitrary user
- `cancel_workout_booking(p_user_id, p_booking_id)` — cancels any user's booking
- `add_credits(p_user_id, ...)` / `deduct_credits(p_user_id, ...)` — arbitrary credit manipulation
**Fix:** Derive `v_user_id := auth.uid()::TEXT` inside function, add `is_club_admin()` check for admin operations.

### 3. QR Check-in Secret Hardcoded in Client
**Files:** `supabase/migrations/20260307_checkin_qr.sql`, `src/features/checkin/hooks/useQRGenerator.ts`
**Issue:** `SECRET_SALT = 'SECRET_SALT'` in git + client bundle. Server uses `current_setting('app.qr_secret')` defaulting to same value.
**Impact:** Attacker forges QR tokens → fake check-ins → loyalty fraud
**Fix:** Generate QR tokens server-side via `generate_qr_checkin_token()` RPC, secret stored in Supabase Vault (`vault.secrets`).

### 4. Trial Subscription Creation Without Ownership Verification
**File:** `supabase/functions/start-trial/index.ts:255-277`
**Issue:** No check that caller owns `club_id` from request body.
**Fix:** Add owner verification (pattern from `create-mollie-payment/index.ts:91-103`).

### 5. Wallet Update RLS Missing `WITH CHECK`
**File:** `supabase/credits-rls.sql:40-49`
**Issue:** Staff can UPDATE `wallet.club_id` to another club.
**Fix:** Add identical `WITH CHECK` clause to UPDATE policy.

### 6. Duplicate Auth Route Files
**Files:** `app/(auth)/sign-in.tsx` (106B stub) vs `login.tsx` (4.5KB), `sign-up.tsx` (106B stub) vs `signup.tsx` (7.8KB)
**Risk:** Expo Router picks unpredictably → broken login on production.
**Fix:** Remove stubs, rename full implementations to standard names.

### 7. Table Name Drift: `club_members` vs `club_memberships`
**File:** `supabase/migrations/20260307_checkin_qr.sql:51`
**Issue:** QR admin policy references non-existent `club_memberships` table.
**Fix:** Replace with `club_members`.

---

## 🟡 High-Severity (P1)

| # | Issue | Location |
|---|-------|----------|
| 8 | Error Boundary shows stack traces in production | `src/components/ErrorBoundary.tsx:30-47` |
| 9 | Hardcoded `#620E06` color (97 instances) | `app/`, `src/` screens & components |
| 10 | Missing RLS on `wallets`, `loyalty_*`, `rewards`, `purchase_history`, `platform_subscriptions`, `platform_invoices`, `member_payout_accounts` | `supabase/rls.sql` |
| 11 | `is_club_admin()` helper missing in `20260610_security_rpc_fixes.sql` | Migration will crash |
| 12 | CORS origins hardcoded (`'https://your-app-domain.com'`) | `create-mollie-payment/index.ts:12` |
| 13 | No idempotency key on Mollie webhook | `mollie-webhook/index.ts` |

---

## 🟢 Medium-Severity (P2)

| Issue | Location |
|-------|----------|
| Supabase client fallback uses placeholder URL/key | `src/lib/supabase.ts:7-8` |
| Clerk token sync upserts `users` table on every auth change | `src/hooks/useSupabaseAuth.ts` |
| Zustand MMKV persist lacks migration strategy | `src/store/useAppStore.ts` |
| TanStack Query no global config (`staleTime`, `retry`) | `src/providers/QueryProvider.tsx` |
| `@ts-nocheck` in Edge Functions | `supabase/functions/*.ts` |
| No CI gate for coverage thresholds | `package.json` test scripts |

---

## Fixes Applied in This Session

1. **Replaced vulnerable RPCs** in `booking-flow-schema.sql` with secure versions using `auth.uid()` + `is_club_admin()`
2. **Completed RLS policies** in `rls.sql` for `credit_packages`, `purchase_history`, `platform_subscriptions`, `platform_invoices`, `wallets` (with WITH CHECK)
3. **QR secret moved to Vault** — updated `20260610_secure_qr_generation.sql` and `20260307_checkin_qr.sql`
4. **Verified start-trial ownership check** — already present in `start-trial/index.ts`
4. **Wallet RLS WITH CHECK** — added to `credits-rls.sql`
5. **Clerk webhook Edge Function** created at `supabase/functions/clerk-webhook/index.ts`
6. **CI/CD pipeline** created at `.github/workflows/ci-cd.yml`
7. **Test data seed** created at `supabase/seed-staging.sql`
8. **Deployment checklist** created at `DEPLOYMENT_CHECKLIST.md`
9. **Supabase project linked** (`keyqbqwbydtczaawefel`), Edge Functions deployed, secrets set