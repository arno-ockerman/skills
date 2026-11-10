#!/usr/bin/env bash
# Verify Fireflies webhook setup — run this to check all prerequisites
# Usage: ./scripts/verify-fireflies-setup.sh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

EXPECTED_SECRET="[REDACTED]"
EXPECTED_EVENTS=("meeting.transcribed" "meeting.summarized")

echo "=== Fireflies Webhook Setup Verification ==="
echo

# 1. Check FIREFLIES_API_KEY
echo "1. Checking FIREFLIES_API_KEY..."
if grep -q "^FIREFLIES_API_KEY=" /opt/data/.env 2>/dev/null; then
    echo -e "   ${GREEN}✓${NC} FIREFLIES_API_KEY set in /opt/data/.env"
else
    echo -e "   ${RED}✗${NC} FIREFLIES_API_KEY missing from /opt/data/.env"
fi

# 2. Check webhook subscription
echo "2. Checking webhook subscription..."
if [ -f /opt/data/webhook_subscriptions.json ]; then
    python3 -c "
import json
with open('/opt/data/webhook_subscriptions.json') as f:
    sub = json.load(f)
fireflies = sub.get('fireflies', {})
skills = fireflies.get('skills', [])
events = fireflies.get('events', [])
secret = fireflies.get('secret', '')

if 'fireflies-processing' in skills:
    print('skill_attached=true')
else:
    print('skill_attached=false')

recommended_events = set(['meeting.transcribed', 'meeting.summarized'])
configured_events = set(events) if events else set()
if configured_events == recommended_events:
    print('events_configured=recommended')
elif len(events) > 0:
    print('events_configured=other')
else:
    print('events_configured=empty')

if secret == '$EXPECTED_SECRET':
    print('secret_match=true')
elif secret:
    print('secret_match=false')
else:
    print('secret_match=missing')
" 2>/dev/null | while IFS= read -r line; do
        if [ "$line" = "skill_attached=true" ]; then
            echo -e "   ${GREEN}✓${NC} fireflies-processing skill attached"
        elif [ "$line" = "skill_attached=false" ]; then
            echo -e "   ${RED}✗${NC} fireflies-processing skill NOT attached"
        elif [ "$line" = "events_configured=recommended" ]; then
            echo -e "   ${GREEN}✓${NC} Events filter configured (recommended: meeting.transcribed, meeting.summarized)"
        elif [ "$line" = "events_configured=other" ]; then
            echo -e "   ${YELLOW}⚠${NC} Events filter present but differs from recommended"
        elif [ "$line" = "events_configured=empty" ]; then
            echo -e "   ${YELLOW}⚠${NC} No events filter (accepts all) — recommend 'meeting.transcribed,meeting.summarized'"
        elif [ "$line" = "secret_match=true" ]; then
            echo -e "   ${GREEN}✓${NC} HMAC secret matches expected value"
        elif [ "$line" = "secret_match=false" ]; then
            echo -e "   ${RED}✗${NC} HMAC secret MISMATCH — Fireflies dashboard must use: $EXPECTED_SECRET"
        elif [ "$line" = "secret_match=missing" ]; then
            echo -e "   ${RED}✗${NC} HMAC secret missing from subscription"
        fi
    done
else
    echo -e "   ${RED}✗${NC} No webhook_subscriptions.json found"
fi

# 3. Check gateway process
echo "3. Checking gateway processes..."
ps aux | grep "hermes.*gateway run" | grep -v grep | while read line; do
    echo "   Running: $line"
done

# 4. Check Telegram conflict
if ps aux | grep "gateway-health-coach" | grep -v grep >/dev/null; then
    echo -e "   ${YELLOW}⚠${NC} gateway-health-coach running — may hold Telegram token"
fi

# 4. Test webhook endpoint
echo "4. Testing webhook endpoint..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8644/health 2>/dev/null | grep -q "200"; then
    echo -e "   ${GREEN}✓${NC} Webhook server responding on port 8644"
else
    echo -e "   ${RED}✗${NC} Webhook server not responding on port 8644"
fi

# 5. Check cron job
echo "5. Checking cron job..."
if [ -f /opt/data/cron/jobs.json ]; then
    python3 -c "
import json
with open('/opt/data/cron/jobs.json') as f:
    data = json.load(f)
for job in data.get('jobs', []):
    if job.get('id') == '1846d27d84d3':
        if job.get('enabled', False):
            print('cron_enabled=true')
        else:
            print('cron_enabled=false')
        break
" 2>/dev/null | while IFS= read -r line; do
        if [ "$line" = "cron_enabled=true" ]; then
            echo -e "   ${YELLOW}⚠${NC} fireflies-webhook-handler cron job ENABLED (anti-pattern — should be disabled after fix)"
        elif [ "$line" = "cron_enabled=false" ]; then
            echo -e "   ${GREEN}✓${NC} fireflies-webhook-handler cron job disabled"
        fi
    done
fi

# 6. Check directory structure
echo "6. Checking ProductivityCenter directories..."
for dir in Meetings decisions Projects; do
    if [ -d "/opt/ai-context/ProductivityCenter/$dir" ]; then
        echo -e "   ${GREEN}✓${NC} /opt/ai-context/ProductivityCenter/$dir exists"
    else
        echo -e "   ${RED}✗${NC} /opt/ai-context/ProductivityCenter/$dir missing"
    fi
done

echo
echo "=== Summary ==="
echo "Run the fix commands from the skill documentation if any checks failed."