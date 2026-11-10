# Production Deployment Checklist Template

> Adapted from Club-app deployment. Customize per project.

---

## ✅ Pre-Deploy Code Fixes (Must Complete)

- [ ] All vulnerable RPCs replaced with `auth.uid()` derived identity
- [ ] RLS policies complete on ALL tenant tables (including new tables)
- [ ] `WITH CHECK` clauses on all UPDATE/DELETE policies
- [ ] No hardcoded secrets in client code (QR salts, API keys)
- [ ] Duplicate route files removed (single auth flow per type)
- [ ] Table name consistency verified (`club_members` vs `club_memberships`)
- [ ] Error Boundary hides stacks in production (`__DEV__` guard)
- [ ] Design tokens centralized (no hardcoded colors/spacing)
- [ ] `is_club_admin()` and `requesting_user_id()` helpers exist in DB

---

## 🔐 Infrastructure Configuration

### Supabase Project
- [ ] Project linked: `supabase link --project-ref <ref>`
- [ ] Migrations pushed: `supabase db push` (or run `MASTER_MIGRATION.sql` in SQL Editor)
- [ ] QR secret in Vault: `INSERT INTO vault.secrets (name, secret) VALUES ('qr_secret', gen_random_bytes(32))`
- [ ] Edge Functions deployed:
  - [ ] `clerk-webhook` (user sync)
  - [ ] `create-mollie-payment` / `mollie-webhook` (payments)
  - [ ] `start-trial` (subscription)
- [ ] Secrets set:
  - [ ] `CLERK_WEBHOOK_SECRET` (from Clerk webhook signing secret)
  - [ ] `CLERK_SECRET_KEY` (Clerk API secret)
  - [ ] `MOLLIE_API_KEY` (Mollie live key)
  - [ ] `SUPABASE_SERVICE_ROLE_KEY` (Supabase Dashboard → Settings → API)
- [ ] Third-Party Auth: Clerk connected in Supabase Dashboard → Authentication → Third-Party Auth
- [ ] JWT has `role: authenticated` claim

### Clerk Dashboard
- [ ] Webhook endpoint: `https://<ref>.supabase.co/functions/v1/clerk-webhook`
- [ ] Events selected: `user.created`, `user.updated`, `user.deleted`
- [ ] Signing secret copied → added as `CLERK_WEBHOOK_SECRET` in Supabase
- [ ] Publishable key: `EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY = pk_live_...`

### Vercel (Web)
- [ ] Import GitHub repo → Framework: Other → Build: `npm run export:web` → Output: `web-build`
- [ ] Environment variables:
  - `EXPO_PUBLIC_CLERK_PUBLISHABLE_KEY`
  - `EXPO_PUBLIC_SUPABASE_URL`
  - `EXPO_PUBLIC_SUPABASE_ANON_KEY`
  - `EXPO_PUBLIC_ENABLE_WEB_AUTH=true`
  - `EXPO_PUBLIC_APP_URL=https://<domain>`
- [ ] Custom domain configured (optional)

### Expo EAS (Mobile)
- [ ] `eas build:configure` → iOS + Android, production profile
- [ ] Secrets: `CLERK_PUBLISHABLE_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `EXPO_PUBLIC_ENABLE_WEB_AUTH`
- [ ] `eas build --platform all --profile production`
- [ ] `eas submit --platform all --profile production`

### Mollie (or Stripe)
- [ ] Webhook URL: `https://<ref>.supabase.co/functions/v1/mollie-webhook`
- [ ] Events: `payment.*`, `subscription.*`, `mandate.*`
- [ ] Live API key in Supabase secrets

---

## 🔧 GitHub Actions Secrets

| Secret | Source |
|--------|--------|
| `VERCEL_TOKEN` | Vercel → Settings → Tokens |
| `VERCEL_ORG_ID` | Vercel Project → Settings → General |
| `VERCEL_PROJECT_ID` | Vercel Project → Settings → General |
| `EXPO_TOKEN` | Expo Dashboard → Access Tokens |
| `SUPABASE_ACCESS_TOKEN` | Supabase → Settings → Access Tokens |
| `SUPABASE_PROJECT_REF` | Supabase URL: `https://<ref>.supabase.co` |
| `SUPABASE_DB_PASSWORD` | Supabase → Settings → Database |
| `CLERK_PUBLISHABLE_KEY` | Clerk → API Keys |
| `CLERK_WEBHOOK_SECRET` | Clerk → Webhooks → Signing Secret |
| `CLERK_SECRET_KEY` | Clerk → API Keys |
| `MOLLIE_API_KEY` | Mollie → Developers → API Keys (Live) |
| `MOLLIE_WEBHOOK_SECRET` | Mollie → Webhooks |

---

## 🧪 Smoke Test Checklist (Post-Deploy)

| Flow | Test Steps | Expected |
|------|------------|----------|
| **Signup → Login** | New user registers, verifies email, logs in | Redirect to club select |
| **Club Select** | User sees only their clubs, selects one | Club context loaded |
| **Schedule** | User views sessions | Only selected club sessions |
| **Booking** | User books session with credits | Credits deducted, confirmed |
| **Waitlist** | Book full session | Added to waitlist |
| **Cancellation** | Cancel >2h before | Credits refunded |
| **Check-in** | Staff scans user QR | Check-in recorded |
| **Payment** | Buy credit package via Mollie | Credits granted after payment |
| **Loyalty** | Complete session → check points | Points granted, tier updated |
| **Admin Dashboard** | Owner views dashboard | Only own club data visible |

---

## 📋 Rollback Plan

| Scenario | Action |
|----------|--------|
| Vercel deploy broken | `vercel rollback` or promote previous deployment |
| EAS build failed | Fix code → rebuild (submissions are manual) |
| Supabase migration failed | `supabase db reset --linked` (staging) / backup restore (prod) |
| Edge Function error | Check logs → fix → `supabase functions deploy` |

---

## 📞 Monitoring Setup

- [ ] **Sentry** — frontend + Edge Functions
- [ ] **Supabase Logs** — failed RPCs, RLS violations, webhook failures
- [ ] **Mollie Dashboard** — failed payments, webhook retries
- [ ] **Vercel Analytics** — web performance, Core Web Vitals
- [ ] **Expo Insights** — crash reports, adoption