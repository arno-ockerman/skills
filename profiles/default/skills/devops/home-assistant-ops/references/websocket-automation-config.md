# Reading and updating an automation's config

Two ways to read; only REST writes. REST is keyed by the numeric `id` field (e.g. `1781301881728`), NOT the entity_id (entity_id returns 404 "Resource not found").

```bash
# read
curl -s -H "$AUTH" "$HASS_URL/api/config/automation/config/<id>"
# update — POST full config (alias/triggers/conditions/actions/mode); returns {"result":"ok"}
curl -s -X POST -H "$AUTH" -H "Content-Type: application/json" \
  --data-binary @new_config.json \
  "$HASS_URL/api/config/automation/config/<id>"
```

## Websocket (read-only)

The websocket `automation/config` command is read-only — there is no websocket update command for automations.

Requires `websocket-client` (install into a scratch venv, not Hermes's own env):

```bash
python3 -m venv /opt/data/cache/scratch/yta
/opt/data/cache/scratch/yta/bin/pip install websocket-client
```

```python
import json, ssl, urllib.parse
from websocket import create_connection

base = "https://example.com"
u = urllib.parse.urlparse(base)
ws = create_connection("wss://" + u.netloc + "/api/websocket",
                       sslopt={"cert_reqs": ssl.CERT_NONE}, timeout=30)
def recv(): return json.loads(ws.recv())

for _ in range(5):
    m = recv()
    if m.get("type") == "auth_required": break
ws.send(json.dumps({"type": "auth", "access_token": TOKEN}))
for _ in range(5):
    m = recv()
    if m.get("type") in ("auth_ok", "auth_invalid"): break

ws.send(json.dumps({"id": 1, "type": "automation/config",
                    "entity_id": "automation.<name>"}))
while True:
    m = recv()
    if m.get("id") == 1: break
print(json.dumps(m.get("result"), indent=1))
ws.close()
```

Result shape: `{"config": {"triggers": [...], "conditions": [...], "actions": [...], "mode": "..."}}`.

Gotchas:

- `sslopt={"cert_reqs": ssl.CERT_NONE}` is required — the Cloudflare route uses "No TLS Verify".
- `render_template` websocket command returns its rendered value in a follow-up event, not in the direct ack (`result: null`) — read the next event to get the rendered string.
- A template trigger's `for` clause is stored as `{"minutes": N}` — that is minutes, not seconds.
