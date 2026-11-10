// Clerk Webhook Edge Function — Sync Users to Supabase
// Receives Clerk webhook events (user.created, user.updated, user.deleted)
// and syncs user data to Supabase public.users table.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { crypto } from 'https://deno.land/std@0.177.0/crypto/mod.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, svix-id, svix-timestamp, svix-signature',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface ClerkWebhookEvent {
  type: 'user.created' | 'user.updated' | 'user.deleted';
  data: {
    id: string;
    email_addresses: Array<{ id: string; email_address: string; verification: { status: string } }>;
    first_name: string | null;
    last_name: string | null;
    image_url: string | null;
    primary_email_address_id: string;
    updated_at: number;
    deleted_at: number | null;
    public_metadata: Record<string, unknown>;
    private_metadata: Record<string, unknown>;
    unsafe_metadata: Record<string, unknown>;
  };
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonError('Method not allowed', 405);
  }

  try {
    // Verify Clerk webhook signature
    const svixId = req.headers.get('svix-id');
    const svixTimestamp = req.headers.get('svix-timestamp');
    const svixSignature = req.headers.get('svix-signature');

    if (!svixId || !svixTimestamp || !svixSignature) {
      console.warn('[clerk-webhook] Missing Svix headers');
      return jsonError('Missing webhook signature headers', 400);
    }

    const webhookSecret = Deno.env.get('CLERK_WEBHOOK_SECRET') ?? '';
    if (!webhookSecret) {
      console.error('[clerk-webhook] CLERK_WEBHOOK_SECRET not configured');
      return jsonError('Webhook secret not configured', 500);
    }

    // Verify signature
    const payload = await req.text();
    const isValid = await verifyWebhookSignature(payload, svixId, svixTimestamp, svixSignature, webhookSecret);
    if (!isValid) {
      console.warn('[clerk-webhook] Invalid signature');
      return jsonError('Invalid signature', 401);
    }

    const event: ClerkWebhookEvent = JSON.parse(payload);
    console.log(`[clerk-webhook] Received event: ${event.type} for user ${event.data.id}`);

    // Create admin client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    switch (event.type) {
      case 'user.created':
      case 'user.updated':
        await handleUserUpsert(supabase, event.data);
        break;

      case 'user.deleted':
        await handleUserDelete(supabase, event.data.id);
        break;

      default:
        console.log(`[clerk-webhook] Unhandled event type: ${event.type}`);
    }

    return jsonOk({ received: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    console.error('[clerk-webhook] Error:', message);
    return jsonError(message, 500);
  }
});

async function handleUserUpsert(supabase: ReturnType<typeof createClient>, userData: ClerkWebhookEvent['data']) {
  const primaryEmail = userData.email_addresses.find(
    (e) => e.id === userData.primary_email_address_id
  )?.email_address;

  const { error } = await supabase.from('users').upsert(
    {
      id: userData.id,
      email: primaryEmail,
      first_name: userData.first_name,
      last_name: userData.last_name,
      avatar_url: userData.image_url,
      public_metadata: userData.public_metadata,
      private_metadata: userData.private_metadata,
      updated_at: new Date(userData.updated_at).toISOString(),
    },
    { onConflict: 'id' }
  );

  if (error) {
    console.error('[clerk-webhook] Upsert error:', error);
    throw error;
  }

  console.log(`[clerk-webhook] Upserted user ${userData.id}`);
}

async function handleUserDelete(supabase: ReturnType<typeof createClient>, userId: string) {
  const { error } = await supabase.from('users').delete().eq('id', userId);

  if (error) {
    console.error('[clerk-webhook] Delete error:', error);
    throw error;
  }

  console.log(`[clerk-webhook] Deleted user ${userId}`);
}

// Verify Svix webhook signature per Clerk docs
async function verifyWebhookSignature(
  payload: string,
  svixId: string,
  svixTimestamp: string,
  svixSignature: string,
  secret: string
): Promise<boolean> {
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign', 'verify']
    );

    const message = new TextEncoder().encode(`${svixId}.${svixTimestamp}.${payload}`);
    const expectedSignature = await crypto.subtle.sign('HMAC', key, message);
    const expectedBase64 = btoa(String.fromCharCode(...new Uint8Array(expectedSignature)));

    // Clerk sends multiple signatures separated by space; check if any matches
    const signatures = svixSignature.split(' ');
    return signatures.some((sig) => sig === expectedBase64);
  } catch (err) {
    console.error('[clerk-webhook] Signature verification error:', err);
    return false;
  }
}

function jsonOk(data: unknown): Response {
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function jsonError(message: string, status: number): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
```

**Deployment:**
```bash
supabase functions deploy clerk-webhook --project-ref <ref>
supabase secrets set CLERK_WEBHOOK_SECRET=whsec_...cret --project-ref <ref>
```

**Clerk Dashboard Config:**
- Endpoint: `https://<project-ref>.supabase.co/functions/v1/clerk-webhook`
- Events: `user.created`, `user.updated`, `user.deleted`
- Copy signing secret → `CLERK_WEBHOOK_SECRET` in Supabase secrets