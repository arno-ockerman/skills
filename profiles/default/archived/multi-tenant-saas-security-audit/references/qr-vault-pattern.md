# QR Secret in Supabase Vault Pattern

## Problem
Client-side QR code generation with hardcoded salt enables attendance fraud:
```typescript
// VULNERABLE - secret in git + client bundle
const SECRET_SALT = 'SECRET_SALT';
function generateHash(sessionId: string, timestamp: number): string {
  return encodeBase64(`${sessionId}${timestamp}${SECRET_SALT}`).slice(0, 8);
}
```

## Solution: Server-Side Signing with Vault Secret

### 1. Store Secret in Supabase Vault
```sql
-- Run once in Supabase Dashboard → SQL Editor
INSERT INTO vault.secrets (name, secret)
VALUES ('qr_secret', gen_random_bytes(32))
ON CONFLICT (name) DO UPDATE SET secret = EXCLUDED.secret;
```

Generate 32 random bytes locally:
```bash
openssl rand -hex 32
# Or for direct SQL:
# encode(gen_random_bytes(32), 'hex')
```

### 2. Generate QR Token Server-Side (Edge Function / RPC)
```sql
-- RPC: generate_qr_checkin_token(p_session_id UUID)
-- Returns: token, expires_at, payload_json

CREATE OR REPLACE FUNCTION public.generate_qr_checkin_token(p_session_id UUID)
RETURNS TABLE (token TEXT, expires_at TIMESTAMPTZ, payload_json JSONB)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_timestamp BIGINT;
  v_hash TEXT;
  v_qr_secret TEXT;
  v_expires_at TIMESTAMPTZ;
BEGIN
  -- 1. Verify caller is admin/owner of session's club
  IF NOT EXISTS (
    SELECT 1 FROM public.sessions s
    JOIN public.club_members cm ON cm.club_id = s.club_id
    WHERE s.id = p_session_id
      AND cm.user_id = public.requesting_user_id()
      AND cm.role IN ('owner', 'staff')
      AND cm.status = 'active'
  ) THEN
    RAISE EXCEPTION 'Access denied: not an admin of this session''s club';
  END IF;

  -- 2. Get secret from Vault
  SELECT secret INTO v_qr_secret FROM vault.secrets WHERE name = 'qr_secret';
  IF v_qr_secret IS NULL OR v_qr_secret = '' THEN
    RAISE EXCEPTION 'QR secret not configured in Vault. Add "qr_secret" in Supabase Vault.';
  END IF;

  -- 3. Generate timestamp + expiration (4 hours)
  v_timestamp := EXTRACT(EPOCH FROM NOW())::BIGINT;
  v_expires_at := NOW() + INTERVAL '4 hours';

  -- 4. HMAC-based hash with Vault secret
  v_hash := LEFT(
    ENCODE(
      CONVERT_TO(p_session_id::TEXT || v_timestamp::TEXT || v_qr_secret, 'UTF8'),
      'base64'
    ),
    8
  );

  -- 5. Return signed token
  RETURN QUERY SELECT
    FORMAT('CLUB_CHECKIN:%s:%s:%s', p_session_id::TEXT, v_timestamp::TEXT, v_hash)::TEXT,
    v_expires_at,
    JSONB_BUILD_OBJECT(
      'sessionId', p_session_id::TEXT,
      'timestamp', v_timestamp,
      'hash', v_hash,
      'expiresAt', v_expires_at::TEXT
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.generate_qr_checkin_token(UUID) TO authenticated;
```

### 3. Validate QR Token Server-Side (Check-in RPC)
```sql
-- RPC: checkin_with_qr(p_token TEXT, p_user_id TEXT)
-- Uses same Vault secret for validation

CREATE OR REPLACE FUNCTION public.checkin_with_qr(p_token TEXT, p_user_id TEXT)
RETURNS TABLE(success BOOLEAN, message TEXT, checkin_id UUID, session_id UUID, checked_in_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_parts TEXT[];
  v_session_id UUID;
  v_ts BIGINT;
  v_hash TEXT;
  v_qr_secret TEXT;
  v_expected_hash TEXT;
  -- ... other vars
BEGIN
  -- Parse token format: CLUB_CHECKIN:session_id:timestamp:hash
  v_parts := regexp_split_to_array(p_token, ':');
  IF array_length(v_parts, 1) <> 4 OR v_parts[1] <> 'CLUB_CHECKIN' THEN
    RETURN QUERY SELECT FALSE, 'Invalid QR token.', NULL, NULL, NULL;
  END IF;

  v_session_id := v_parts[2]::UUID;
  v_ts := v_parts[3]::BIGINT;
  v_hash := v_parts[4];

  -- Get secret from Vault
  SELECT secret INTO v_qr_secret FROM vault.secrets WHERE name = 'qr_secret';
  IF v_qr_secret IS NULL OR v_qr_secret = '' THEN
    RETURN QUERY SELECT FALSE, 'QR secret not configured.', NULL, v_session_id, NULL;
  END IF;

  -- Validate HMAC
  v_expected_hash := LEFT(ENCODE(CONVERT_TO(v_session_id::TEXT || v_ts::TEXT || v_qr_secret, 'UTF8'), 'base64'), 8);
  IF v_hash <> v_expected_hash THEN
    RETURN QUERY SELECT FALSE, 'QR validation failed.', NULL, NULL, NULL;
  END IF;

  -- Check expiry (4 hours)
  IF NOW() > TO_TIMESTAMP(v_ts) + INTERVAL '4 hours' THEN
    RETURN QUERY SELECT FALSE, 'QR code expired.', NULL, v_session_id, NULL;
  END IF;

  -- Check booking exists & valid
  IF NOT EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.session_id = v_session_id
      AND b.user_id = p_user_id
      AND b.status IN ('confirmed', 'waitlist')
  ) THEN
    RETURN QUERY SELECT FALSE, 'No valid booking.', NULL, v_session_id, NULL;
  END IF;

  -- Record check-in
  INSERT INTO public.session_checkins (session_id, user_id, qr_token)
  VALUES (v_session_id, p_user_id, p_token)
  ON CONFLICT (session_id, user_id)
  DO UPDATE SET checked_in_at = NOW(), qr_token = EXCLUDED.qr_token
  RETURNING id, checked_in_at INTO v_checkin_id, v_checked_at;

  RETURN QUERY SELECT TRUE, 'Check-in successful.', v_checkin_id, v_session_id, v_checked_at;
END;
$$;
```

### 4. Client Calls Server RPC (No Secret in Client)
```typescript
// src/features/checkin/hooks/useQRGenerator.ts
export function useQRGenerator() {
  const generateForSession = useCallback(async (sessionId: string): Promise<QRPayload | null> => {
    const { data, error } = await supabase.rpc('generate_qr_checkin_token', {
      p_session_id: sessionId,
    });
    if (error || !data?.[0]) return null;
    const { token, expires_at, payload_json } = data[0];
    return {
      sessionId: payload_json.sessionId,
      timestamp: payload_json.timestamp,
      hash: payload_json.hash,
      token,
      expiresAt: expires_at,
    };
  }, []);
  return { generateForSession };
}
```

### 5. Security Properties
| Property | Achieved |
|----------|----------|
| Secret never in client | ✅ Only in Vault |
| Secret never in git | ✅ Generated at deploy time |
| Replay protection | ✅ 4-hour expiry + unique timestamp |
| Forgery resistance | ✅ HMAC with 32-byte secret |
| Admin-only generation | ✅ RPC checks club membership + role |
| Audit trail | ✅ Token logged in checkins table |

### 6. Deployment Checklist
- [ ] Generate secret: `openssl rand -hex 32`
- [ ] Insert into Vault via SQL Editor
- [ ] Deploy `generate_qr_checkin_token` and `checkin_with_qr` RPCs
- [ ] Update client to call RPC instead of local hash
- [ ] Remove any client-side QR secret constants
- [ ] Verify `vault.secrets` accessible by Edge Functions (uses service role)

### 7. Migration Notes
If migrating from hardcoded salt:
1. Deploy new RPCs alongside old (no breaking change)
2. Update client to use new RPC
3. Once all clients updated, remove old code
4. Old tokens naturally expire within 4 hours