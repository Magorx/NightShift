#!/bin/bash
# Test: launch a real CLI session so the statusLine hook fires,
# then read the quota file it writes.
#
# The statusLine hook (track-quota.sh) receives BOTH rate limit buckets
# but only fires during CLI sessions. This script launches a minimal
# `claude -p` call which triggers the hook, waits for it to write
# session-usage.txt, then displays the result.

set -euo pipefail

USAGE_FILE="$HOME/.claude/session-usage.txt"

echo "=== Before ==="
cat "$USAGE_FILE" 2>/dev/null || echo "(no existing data)"
echo ""

# Record timestamp so we can detect a fresh write
BEFORE_TS=$(stat -f %m "$USAGE_FILE" 2>/dev/null || echo 0)

echo "Sending 'hi' via claude CLI (triggers statusLine hook)..."
echo "hi" | claude -p 2>/dev/null

# Give the statusLine hook a moment to finish writing
sleep 1

AFTER_TS=$(stat -f %m "$USAGE_FILE" 2>/dev/null || echo 0)

echo ""
if [ "$AFTER_TS" -gt "$BEFORE_TS" ]; then
  echo "=== After (statusLine hook fired!) ==="
  cat "$USAGE_FILE"
else
  echo "=== statusLine hook did NOT fire ==="
  echo "File timestamp unchanged: $BEFORE_TS -> $AFTER_TS"
  echo ""
  echo "Falling back to stream-json rate_limit_event..."
  echo "hi" | claude -p --output-format stream-json --verbose 2>/dev/null \
    | grep 'rate_limit_event' \
    | jq '.rate_limit_info'
fi
