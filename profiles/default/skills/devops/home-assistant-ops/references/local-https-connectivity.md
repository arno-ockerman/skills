# Direct local HTTPS alongside Cloudflare

## Procedure

1. Read HA `/api/config` for internal/external URL hints, but ask for or inspect the Companion app's own server settings and home SSID. Server-side settings do not prove which route the phone used.
2. Discover published ports and startup/restart status through read-only container inspection. Correlate reported local times with Docker UTC timestamps and HA's configured timezone. Keep current availability separate from historical incident evidence.
3. Test the origin directly with the intended hostname and SNI, without changing DNS:

```bash
curl --silent --show-error --max-time 15 \
  --resolve example.com:30103:192.0.2.10 \
  -o /dev/null -w 'HTTP=%{http_code} SSL=%{ssl_verify_result}\n' \
  https://example.com:30103/
```

This bypasses the public tunnel while preserving hostname validation. Compare with the IP-address URL to distinguish a name mismatch from a trust-chain failure. Use insecure TLS only as a bounded diagnostic to determine whether the application answers, never as proof that secure access works.
4. Inspect only the public certificate: connect with Python `socket.create_connection`, wrap with `ssl._create_unverified_context()` using the intended `server_hostname`, retrieve `getpeercert(binary_form=True)`, convert via `ssl.DER_cert_to_PEM_cert`, and save under the scratch directory. Decode using:

```bash
openssl x509 -in <public-certificate.pem> -noout \
  -subject -issuer -dates -ext subjectAltName
```

Do not retrieve or print private keys. An unverified inspection connection is not a successful TLS validation.
5. Classify the result before changing anything:
   - SAN mismatch: choose a matching hostname and ensure local resolution.
   - Untrusted issuer: install an appropriate publicly trusted certificate/chain; hostname changes alone are insufficient.
   - Cloudflare Origin CA: suitable for Cloudflare-to-origin traffic, not default direct iPhone/browser trust, even with a matching wildcard and future expiry.
   - Expiry or missing intermediates: address renewal/served chain rather than changing client security settings.
6. Discover certificate renewal ownership, DNS control, and the router's actual DNS capabilities before choosing the implementation. Local DNS plus a trusted certificate is a design option, not a completed or validated deployment. Do not prescribe device-specific router settings without its model. Keep Cloudflare external access intact while preparing the local route.

## Completion gates

- Normal TLS verification succeeds against the direct LAN endpoint using the intended hostname; no `-k` or custom trust bypass.
- The iPhone uses the internal URL on its configured home Wi-Fi and loads the dashboard.
- With Wi-Fi off, the unchanged public Cloudflare URL works over cellular.
- Local-route independence is verified without deliberately disrupting production internet or the alarm.
- Certificate renewal is configured and its ownership/validation method recorded.
- Any required restart is approved separately. Never trigger or disarm the alarm merely to test networking.
