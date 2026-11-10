# SECURITY DEFINER RPC Hardening Patterns

## The Core Problem

**Vulnerable pattern:** SECURITY DEFINER function accepts identity parameters from client
```sql
-- ❌ VULNERABLE: Client controls who gets credits/bookings
CREATE FUNCTION add_credits(p_club_id UUID, p_user_id TEXT, p_amount INT, ...)
SECURITY DEFINER ...

-- Client call:
supabase.rpc('add_credits', { p_user_id: 'victim-id', p_amount: 999999 })
```

**Exploit:** Authenticated attacker calls RPC with target user's ID → function runs as DEFINER (bypasses RLS) → manipulates victim's data.

## Secure Pattern: Derive Identity from Auth Context

```sql
-- ✅ SECURE: Identity derived from JWT, not parameter
CREATE OR REPLACE FUNCTION add_credits(
  p_club_id UUID,
  p_amount INTEGER,
  p_type TEXT,
  p_description TEXT,
  p_related_booking_id UUID DEFAULT NULL,
  p_metadata JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id TEXT := auth.uid()::TEXT;  -- Derived from JWT
  v_wallet_id UUID;
  v_transaction_id UUID;
BEGIN
  -- 1. Auth check
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Input validation
  IF COALESCE(p_amount, 0) <= 0 THEN
    RAISE EXCEPTION 'Credit amount must be positive';
  END IF;

  -- 3. Authorization: verify caller is admin of THIS club
  IF NOT is_club_admin(p_club_id) THEN
    RAISE EXCEPTION 'Only club admins can add credits';
  END IF;

  -- 4. Business logic using v_user_id (NOT p_user_id)
  INSERT INTO public.wallets (club_id, user_id, balance, total_earned, total_spent)
  VALUES (p_club_id, v_user_id, p_amount, p_amount, 0)
  ON CONFLICT (club_id, user_id) DO UPDATE SET
    balance = public.wallets.balance + EXCLUDED.balance,
    total_earned = public.wallets.total_earned + EXCLUDED.total_earned,
    updated_at = NOW()
  RETURNING id INTO v_wallet_id;

  INSERT INTO public.credit_transactions (...)
  VALUES (p_club_id, v_wallet_id, v_user_id, p_amount, ...)
  RETURNING id INTO v_transaction_id;

  RETURN v_transaction_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_credits(UUID, INTEGER, TEXT, TEXT, UUID, JSONB) TO authenticated;
```

## Hardening Checklist for Every SECURITY DEFINER RPC

| Check | Implementation |
|-------|----------------|
| **No identity params** | Remove `p_user_id`, `p_club_id` (for tenant), derive from `auth.uid()` + verify membership |
| **Auth guard** | `IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;` |
| **Input validation** | Check amounts > 0, enums valid, UUIDs well-formed |
| **Tenant membership** | `IF NOT EXISTS (SELECT 1 FROM club_members WHERE club_id = p_club_id AND user_id = v_user_id AND status = 'active') THEN RAISE EXCEPTION 'Not a member'; END IF;` |
| **Role authorization** | For admin operations: `IF NOT is_club_admin(p_club_id) THEN RAISE EXCEPTION 'Insufficient permissions'; END IF;` |
| **Row locking** | `SELECT ... FOR UPDATE` on mutated rows to prevent race conditions |
| **SET search_path** | `SET search_path = public` prevents search path injection |
| **Minimal grants** | `GRANT EXECUTE ON FUNCTION ... TO authenticated;` (not public) |

## Common RPC Categories & Fix Patterns

### 1. Credit/Wallet Operations
**Vulnerable:** `add_credits(p_user_id, ...)`, `deduct_credits(p_user_id, ...)`
**Fix:** Derive `v_user_id := auth.uid()::TEXT`; verify club membership; for admin grants, verify `is_club_admin(p_club_id)`

### 2. Booking Operations
**Vulnerable:** `book_workout_session(p_user_id, p_club_id, p_session_id)`
**Fix:** Remove `p_user_id`; derive from auth; verify membership in `p_club_id`; check capacity/credits atomically with `FOR UPDATE`

### 3. Cancellation Operations
**Vulnerable:** `cancel_workout_booking(p_user_id, p_booking_id)`
**Fix:** Remove `p_user_id`; in `SELECT ... FOR UPDATE` add `AND user_id = v_user_id` — ensures user can only cancel own bookings

### 4. Admin Operations (Owner/Staff)
**Pattern:** Accept `p_club_id` (tenant scope) but verify `is_club_admin(p_club_id)` before any mutation

### 5. Read-Only RPCs (SECURITY DEFINER for performance)
**Pattern:** Can keep `p_club_id` param but add `WHERE club_id = p_club_id AND club_id IN (SELECT club_id FROM club_members WHERE user_id = auth.uid()::TEXT AND status = 'active')`

## Migration Strategy: Replace In Place

**Don't just add new migration** — old vulnerable function stays callable. Must overwrite:

```sql
-- In migration: CREATE OR REPLACE FUNCTION public.book_workout_session(...)
-- This REPLACES the old version, same name, new signature
-- Old calls with p_user_id will fail (function signature changed) → client code must also update
```

**Client code update required:**
```typescript
// Before (vulnerable)
supabase.rpc('book_workout_session', { p_user_id: user.id, p_club_id, p_session_id })

// After (secure)
supabase.rpc('book_workout_session', { p_club_id, p_session_id })
// Server derives user_id from auth.uid()
```

## Verification Query: Find Vulnerable RPCs

```sql
-- Find SECURITY DEFINER functions with user_id/club_id parameters
SELECT 
  n.nspname AS schema,
  p.proname AS function_name,
  pg_get_function_arguments(p.oid) AS arguments,
  pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prosecdef  -- SECURITY DEFINER
  AND n.nspname = 'public'
  AND (
    pg_get_function_arguments(p.oid) ILIKE '%user_id%'
    OR pg_get_function_arguments(p.oid) ILIKE '%club_id%'
  )
ORDER BY p.proname;
```

## Club-app Specific Fixes Applied

From `supabase/migrations/20260610_security_rpc_fixes.sql`:

| Function | Old Signature | New Signature | Key Changes |
|----------|---------------|---------------|-------------|
| `add_credits` | `(p_club_id, p_user_id, p_amount, ...)` | `(p_club_id, p_amount, ...)` | Derive `v_user_id := auth.uid()`; add `is_club_admin()` check |
| `deduct_credits` | `(p_club_id, p_user_id, p_amount, ...)` | `(p_club_id, p_amount, ...)` | Derive user; verify wallet ownership + balance |
| `book_workout_session` | `(p_user_id, p_club_id, p_session_id)` | `(p_club_id, p_session_id)` | Derive user; verify membership; check credits |
| `cancel_workout_booking` | `(p_user_id, p_booking_id, ...)` | `(p_booking_id, ...)` | Derive user; `SELECT ... FOR UPDATE WHERE user_id = v_user_id` |

**Critical gap:** `booking-flow-schema.sql` still contains OLD vulnerable versions. Must replace there too, not just in migration file.