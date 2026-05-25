#!/bin/bash
# Usage Monitor - Reads Claude plan usage from unified rate limit headers
# Uses OAuth token from macOS keychain + minimal 1-token message call

set -e

export LC_NUMERIC=C

KEYCHAIN_SERVICE="Claude Code-credentials"
KEYCHAIN_ACCOUNT="${USER}"
API_BASE="https://api.anthropic.com/v1"
API_VERSION="2023-06-01"
BETA_HEADER="oauth-2025-04-20"
# Probe with Haiku to get unified rate limit headers (cheapest working model)
PROBE_MODEL="claude-haiku-4-5-20251001"

# Extract OAuth token from macOS keychain
CREDS=$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null) || {
    echo "Error: Could not read Claude Code credentials from keychain."
    echo "Make sure you're logged into Claude Code (run 'claude' and authenticate)."
    exit 1
}

ACCESS_TOKEN=$(echo "$CREDS" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['claudeAiOauth']['accessToken'])" 2>/dev/null) || {
    echo "Error: Could not extract OAuth token from credentials."
    exit 1
}

SUB_TYPE=$(echo "$CREDS" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['claudeAiOauth'].get('subscriptionType','unknown'))" 2>/dev/null)
RATE_TIER=$(echo "$CREDS" | python3 -c "import sys,json; print(json.loads(sys.stdin.read())['claudeAiOauth'].get('rateLimitTier','unknown'))" 2>/dev/null)

# Send minimal message to get rate limit headers
HEADERS_FILE=$(mktemp)
BODY_FILE=$(mktemp)
trap "rm -f $HEADERS_FILE $BODY_FILE" EXIT

HTTP_CODE=$(curl -s -w "%{http_code}" \
    -o "$BODY_FILE" -D "$HEADERS_FILE" \
    -X POST "${API_BASE}/messages" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "anthropic-version: ${API_VERSION}" \
    -H "anthropic-beta: ${BETA_HEADER}" \
    -H "content-type: application/json" \
    -d "{\"model\":\"${PROBE_MODEL}\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}]}" \
    2>/dev/null) || HTTP_CODE="000"

if [[ "$HTTP_CODE" == "401" ]] || [[ "$HTTP_CODE" == "403" ]]; then
    echo "Error: OAuth token expired or invalid (HTTP $HTTP_CODE)."
    echo "Re-authenticate Claude Code: run 'claude' and log in again."
    exit 1
fi

if [[ "$HTTP_CODE" != "200" ]] && [[ "$HTTP_CODE" != "429" ]]; then
    echo "Error: Unexpected response (HTTP $HTTP_CODE)."
    cat "$BODY_FILE" 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('error',{}).get('message','Unknown error'))
except:
    print(sys.stdin.read()[:200])
" 2>/dev/null
    exit 1
fi

# Render dashboard
python3 - "$HEADERS_FILE" "$SUB_TYPE" "$RATE_TIER" << 'PYEOF'
import sys
import re
from datetime import datetime, timezone

headers_file = sys.argv[1]
sub_type = sys.argv[2]
rate_tier = sys.argv[3]

# Parse headers
headers = {}
with open(headers_file) as f:
    for line in f:
        line = line.strip().rstrip('\r')
        if ':' not in line:
            continue
        key, _, val = line.partition(':')
        key = key.strip().lower()
        val = val.strip()
        if key.startswith('anthropic-ratelimit-unified'):
            short = key.replace('anthropic-ratelimit-unified-', '')
            headers[short] = val

# ANSI colors
RED = '\033[31m'
GREEN = '\033[32m'
YELLOW = '\033[33m'
BLUE = '\033[34m'
MAGENTA = '\033[35m'
CYAN = '\033[36m'
WHITE = '\033[37m'
BOLD = '\033[1m'
DIM = '\033[2m'
RESET = '\033[0m'

ANSI_RE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

def display_width(s):
    clean = ANSI_RE.sub('', s)
    w = 0
    for ch in clean:
        if ord(ch) > 0x1F300:
            w += 2
        else:
            w += 1
    return w

BOX = 61

def pad(content):
    dw = display_width(content)
    return content + ' ' * max(0, BOX - dw)

def row(content):
    return pad(f"{WHITE}|{RESET}  {content}") + f"{WHITE}|{RESET}"

def blank():
    return f"{WHITE}|{RESET}{' ' * BOX}{WHITE}|{RESET}"

def sep():
    return f"{WHITE}+{'-' * BOX}+{RESET}"

def bar(utilization, width=25):
    pct = utilization * 100
    filled = int(utilization * width)
    empty = width - filled

    if pct >= 90:
        color = RED
    elif pct >= 70:
        color = YELLOW
    else:
        color = GREEN

    bar_str = f"{color}{'#' * filled}{DIM}{'.' * empty}{RESET}"
    return f"{bar_str} {pct:.0f}%"

def format_reset(epoch_str):
    try:
        epoch = int(epoch_str)
        dt = datetime.fromtimestamp(epoch, tz=timezone.utc)
        now = datetime.now(timezone.utc)
        diff = (dt - now).total_seconds()

        if diff <= 0:
            return "now"

        local_dt = dt.astimezone()
        day_name = local_dt.strftime("%a")
        time_str = local_dt.strftime("%I:%M %p").lstrip("0")

        if diff < 3600:
            mins = int(diff // 60)
            return f"in {mins}m ({day_name} {time_str})"
        elif diff < 86400:
            hours = int(diff // 3600)
            mins = int((diff % 3600) // 60)
            return f"in {hours}h {mins}m ({day_name} {time_str})"
        else:
            days = int(diff // 86400)
            hours = int((diff % 86400) // 3600)
            return f"in {days}d {hours}h ({day_name} {time_str})"
    except (ValueError, OSError):
        return epoch_str

# Extract unified rate limit data
session_util = float(headers.get('5h-utilization', '0'))
session_reset = headers.get('5h-reset', '')
session_status = headers.get('5h-status', 'unknown')

weekly_util = float(headers.get('7d-utilization', '0'))
weekly_reset = headers.get('7d-reset', '')
weekly_status = headers.get('7d-status', 'unknown')

sonnet_util = float(headers.get('7d_sonnet-utilization', '0'))
sonnet_reset = headers.get('7d_sonnet-reset', '')
sonnet_status = headers.get('7d_sonnet-status', 'unknown')

overage_status = headers.get('overage-status', 'unknown')
overage_reason = headers.get('overage-disabled-reason', '')
representative = headers.get('representative-claim', '')
fallback_pct = headers.get('fallback-percentage', '')

overall_status = headers.get('status', 'unknown')

# Plan label
plan_map = {
    'pro': 'Pro',
    'max': 'Max',
    'team': 'Team',
    'enterprise': 'Enterprise',
}
plan_label = plan_map.get(sub_type, sub_type.title() if sub_type else 'Unknown')

# Build output
lines = []
lines.append("")
lines.append(sep())
l = f"{WHITE}|{RESET}  {CYAN}CLAUDE CODE{RESET} - {MAGENTA}USAGE DASHBOARD{RESET}"
lines.append(pad(l) + f"{WHITE}|{RESET}")
lines.append(sep())
lines.append(blank())

# Account section
lines.append(row(f"{BLUE}@  ACCOUNT{RESET}"))
lines.append(row(f"   Plan:      {GREEN}{plan_label}{RESET}"))
lines.append(row(f"   Tier:      {DIM}{rate_tier}{RESET}"))
if overall_status == "allowed":
    lines.append(row(f"   Status:    {GREEN}Active{RESET}"))
elif overall_status == "throttled":
    lines.append(row(f"   Status:    {YELLOW}Throttled{RESET}"))
elif overall_status == "rejected":
    lines.append(row(f"   Status:    {RED}Rate Limited{RESET}"))
else:
    lines.append(row(f"   Status:    {DIM}{overall_status}{RESET}"))
lines.append(blank())

# Current session (5h window)
session_color = RED if session_util >= 0.9 else (YELLOW if session_util >= 0.7 else BLUE)
lines.append(row(f"{session_color}#  CURRENT SESSION{RESET}"))
lines.append(row(f"   Usage:     {bar(session_util)}"))
lines.append(row(f"   Resets:    {DIM}{format_reset(session_reset)}{RESET}"))
if representative == 'five_hour':
    lines.append(row(f"   {DIM}(active limit for this session){RESET}"))
lines.append(blank())

# Weekly limits
weekly_color = RED if weekly_util >= 0.9 else (YELLOW if weekly_util >= 0.7 else BLUE)
lines.append(row(f"{weekly_color}#  WEEKLY - ALL MODELS{RESET}"))
lines.append(row(f"   Usage:     {bar(weekly_util)}"))
lines.append(row(f"   Resets:    {DIM}{format_reset(weekly_reset)}{RESET}"))
lines.append(blank())

# Sonnet weekly (only shown when headers present)
has_sonnet = '7d_sonnet-utilization' in headers
if has_sonnet:
    sonnet_color = RED if sonnet_util >= 0.9 else (YELLOW if sonnet_util >= 0.7 else BLUE)
    lines.append(row(f"{sonnet_color}#  WEEKLY - SONNET ONLY{RESET}"))
    lines.append(row(f"   Usage:     {bar(sonnet_util)}"))
    lines.append(row(f"   Resets:    {DIM}{format_reset(sonnet_reset)}{RESET}"))
    lines.append(blank())

# Extra usage / overage
lines.append(row(f"{BLUE}#  EXTRA USAGE{RESET}"))
if overage_status == 'allowed':
    lines.append(row(f"   Status:    {GREEN}Enabled{RESET}"))
elif overage_reason:
    reason_map = {
        'org_level_disabled': 'Disabled (org setting)',
        'no_billing': 'Disabled (no billing)',
        'spending_limit_reached': 'Spending limit reached',
    }
    label = reason_map.get(overage_reason, overage_reason)
    lines.append(row(f"   Status:    {YELLOW}{label}{RESET}"))
else:
    lines.append(row(f"   Status:    {DIM}{overage_status}{RESET}"))

if fallback_pct:
    try:
        fb = float(fallback_pct) * 100
        lines.append(row(f"   Fallback:  {DIM}{fb:.0f}% capacity when limited{RESET}"))
    except ValueError:
        pass
lines.append(blank())

# Status footer
worst = max(session_util, weekly_util, sonnet_util)
if worst >= 0.9:
    status_color = RED
    status_label = "CRITICAL"
    exit_code = 2
elif worst >= 0.7:
    status_color = YELLOW
    status_label = "WARNING"
    exit_code = 1
else:
    status_color = GREEN
    status_label = "OK"
    exit_code = 0

remaining = (1 - worst) * 100
lines.append(sep())
if exit_code == 0:
    msg = f"{status_label} - All limits healthy ({remaining:.0f}% headroom)"
else:
    msg = f"{status_label} - Usage at {worst*100:.0f}% ({remaining:.0f}% remaining)"
lines.append(row(f"{status_color}{msg}{RESET}"))
lines.append(f"{WHITE}+{'-' * BOX}+{RESET}")
lines.append("")

for l in lines:
    print(l)

sys.exit(exit_code)
PYEOF

exit $?
