# Reusable RLS Policy Patterns

## Core Pattern: Tenant-Scoped Access

```sql
-- Helper: current user from Clerk JWT (sub claim)
CREATE OR REPLACE FUNCTION requesting_user_id()
RETURNS TEXT LANGUAGE SQL STABLE AS $$
  SELECT auth.jwt() ->> 'sub'
$$;

-- Helper: is current user admin of club?
CREATE OR REPLACE FUNCTION is_club_admin(p_club_id UUID)
RETURNS BOOLEAN LANGUAGE SQL STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM club_members
    WHERE club_id = p_club_id
      AND user_id = requesting_user_id()
      AND role IN ('owner', 'staff')  -- or just 'owner' for strict admin
      AND status = 'active'
  )
$$;
```

## Standard Policy Templates

### SELECT — Members Read Own Tenant Data
```sql
CREATE POLICY "Members read own tenant data"
  ON <table> FOR SELECT
  USING (
    tenant_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND status = 'active'
    )
  );
```

### SELECT — Users Read Own Records Only
```sql
CREATE POLICY "Users read own records"
  ON <table> FOR SELECT
  USING (user_id = requesting_user_id());
```

### INSERT — Members Create Own Records
```sql
CREATE POLICY "Members insert own records"
  ON <table> FOR INSERT
  WITH CHECK (
    user_id = requesting_user_id()
    AND tenant_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND status = 'active'
    )
  );
```

### UPDATE — Members Update Own Records (with tenant lock)
```sql
CREATE POLICY "Members update own records"
  ON <table> FOR UPDATE
  USING (user_id = requesting_user_id())
  WITH CHECK (
    user_id = requesting_user_id()
    AND tenant_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND status = 'active'
    )
  );
```

### UPDATE — Admins Update Tenant Records
```sql
CREATE POLICY "Admins update tenant records"
  ON <table> FOR UPDATE
  USING (
    tenant_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND role IN ('owner', 'staff')
        AND status = 'active'
    )
  )
  WITH CHECK (
    tenant_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND role IN ('owner', 'staff')
        AND status = 'active'
    )
  );
```

### DELETE — Admins Delete Tenant Records
```sql
CREATE POLICY "Admins delete tenant records"
  ON <table> FOR DELETE
  USING (
    tenant_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND role = 'owner'
        AND status = 'active'
    )
  );
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong | Fix |
|--------------|----------------|-----|
| `USING (true)` on tenant table | No isolation | Add tenant membership check |
| `auth.jwt() ->> 'role'` | Clerk doesn't put roles in JWT | Use `club_members.role` lookup |
| Missing `WITH CHECK` on UPDATE | Can move record to another tenant | Duplicate USING logic in WITH CHECK |
| No `status = 'active'` check | Suspended members retain access | Add `AND status = 'active'` |
| Owner-only policy using `auth.uid() = admin_id` | `admin_id` may not exist in Clerk JWT | Use `club_members` table |

## Coverage Checklist for New Tables

For every new tenant table, create:
- [ ] `ALTER TABLE <table> ENABLE ROW LEVEL SECURITY;`
- [ ] Member SELECT policy
- [ ] Member INSERT policy (with tenant check)
- [ ] Member UPDATE policy (USING + WITH CHECK)
- [ ] Admin SELECT/INSERT/UPDATE/DELETE policies
- [ ] Index on `tenant_id` + `user_id` for policy performance

## Example: Complete `wallets` Table RLS

```sql
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- Members read own wallet
CREATE POLICY "Members read own wallet"
  ON wallets FOR SELECT
  USING (user_id = requesting_user_id());

-- Members update own wallet (balance changes via RPC, not direct)
CREATE POLICY "Members update own wallet"
  ON wallets FOR UPDATE
  USING (user_id = requesting_user_id())
  WITH CHECK (user_id = requesting_user_id());

-- Admins read all wallets in their club
CREATE POLICY "Admins read club wallets"
  ON wallets FOR SELECT
  USING (
    club_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND role IN ('owner', 'staff')
        AND status = 'active'
    )
  );

-- Admins update wallets in their club (WITH CHECK prevents club_id change)
CREATE POLICY "Admins update club wallets"
  ON wallets FOR UPDATE
  USING (
    club_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND role IN ('owner', 'staff')
        AND status = 'active'
    )
  )
  WITH CHECK (
    club_id IN (
      SELECT club_id FROM club_members
      WHERE user_id = requesting_user_id()
        AND role IN ('owner', 'staff')
        AND status = 'active'
    )
  );
```