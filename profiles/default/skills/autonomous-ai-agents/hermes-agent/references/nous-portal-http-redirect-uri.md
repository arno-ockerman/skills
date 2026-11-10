# Nous Portal: HTTP redirect_uri Rejected on Public Hermes Dashboard

## Failure Signature

Provider-side error during login:

```json
{"detail":"Provider unreachable: redirect_uri may only use http:// for localhost/127.0.0.1, got 'http://<public-host>/auth/callback'"}
```

## Typical Situation

- Hermes dashboard auth enabled
- `dashboard.oauth.client_id` configured
- `dashboard.oauth.portal_url` configured
- Deployment is on a public custom domain
- Hermes is behind Cloudflare or another reverse proxy
- `dashboard.public_url` is unset, so Hermes reconstructs callback URL from proxy/request headers
- Reconstructed callback falls back to `http://...` instead of `https://...`

## Durable Fix

Set the canonical public URL explicitly:

```yaml
dashboard:
  oauth:
    client_id: agent:...
    portal_url: https://portal.nousresearch.com
  public_url: https://your-public-host
```

Then restart the dashboard process or its supervisor.

## Why This Works

When `dashboard.public_url` is set, Hermes uses:

```text
<public_url>/auth/callback
```

verbatim for the OAuth callback instead of trying to infer scheme/host/prefix from `X-Forwarded-*` headers.

## Verification Pattern

1. Open the HTTPS login page.
2. Click the OAuth button.
3. Inspect the provider authorize URL.
4. Confirm `redirect_uri=` points to `https://<public-host>/auth/callback`.
5. Retry login.

## Concrete Example from Session

Working config pattern:

```yaml
dashboard:
  oauth:
    client_id: agent:EXAMPLE_CLIENT_ID
    portal_url: https://portal.nousresearch.com
  public_url: https://example.com
```

Observed result after restart:

- Authorize flow redirected to Nous Portal
- `redirect_uri` became `https://example.com/auth/callback`
- Previous provider error disappeared