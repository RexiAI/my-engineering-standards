#!/bin/bash
# check-zen-connectivity.sh — Verify the OpenCode Zen endpoint and API key work.
#
# Skips (exit 0) when OPENCODE_API_KEY is not set, so machines and CI runs
# without a key are never blocked. With a key, calls the OpenAI-compatible
# /models endpoint and fails (exit 1) if the endpoint is unreachable or the
# key is rejected.
#
# Usage:
#   OPENCODE_API_KEY=... scripts/check-zen-connectivity.sh
#
# Exit codes:
#   0 — skipped (no key) or endpoint reachable with >=1 model
#   1 — key set but endpoint unreachable / auth failed / empty model list
set -euo pipefail

ZEN_URL="${ZEN_URL:-https://opencode.ai/zen/v1}"

if [ -z "${OPENCODE_API_KEY:-}" ]; then
  echo "SKIP: OPENCODE_API_KEY not set — Zen connectivity check skipped"
  exit 0
fi

response="$(curl -sf --max-time 15 \
  -H "Authorization: Bearer $OPENCODE_API_KEY" \
  "$ZEN_URL/models")" || {
  echo "FAIL: Zen endpoint unreachable or key rejected at $ZEN_URL/models"
  exit 1
}

count="$(printf '%s' "$response" | jq -e '.data | length' 2>/dev/null)" || {
  echo "FAIL: unexpected response from $ZEN_URL/models (not OpenAI-compatible /models JSON)"
  exit 1
}

if [ "$count" -gt 0 ]; then
  echo "OK: Zen reachable at $ZEN_URL, $count model(s) available"
  exit 0
fi

echo "FAIL: Zen reachable but returned 0 models"
exit 1