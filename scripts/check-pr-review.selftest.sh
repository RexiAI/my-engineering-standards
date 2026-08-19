#!/bin/bash
# check-pr-review.selftest.sh — Hermetic regression net for check-pr-review.sh.
# No network, no GitHub, no opencode binary. Fixtures live in mktemp -d with
# trap cleanup.
#
# The interactive secret-prompt scenarios (AC-024-04-04 / AC-024-04-05) are
# the ones the static gate cannot prove: whether OPENCODE_API_KEY is actually
# prompted depends on the flag and on a TTY. The gate checks the structural
# placement of the read; this selftest proves the *behavior* by running
# init-ci.sh under a pseudo-TTY (script(1)) with and without --with-pr-review
# and counting the OPENCODE_API_KEY prompt occurrences.
#
# Scenario traceability: the AC-024 IDs below are the tests for the
# 20-acceptance scenarios.
#
# Usage:
#   bash scripts/check-pr-review.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT_CI="$ROOT/scripts/init-ci.sh"

PASS_COUNT=0
FAIL_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

# require_tool NAME — the pseudo-TTY runner (script) is required for the
# interactive prompt tests.
require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: required tool '$1' not found — cannot run the interactive prompt tests" >&2
    exit 2
  fi
}

require_tool script

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FIX="$TMP/child"
mkdir -p "$FIX"
ln -s "$ROOT" "$FIX/.standards"

# Interactive secrets-run helper: feed the "1) Yes, add secrets placeholders"
# choice plus enough empty answers to satisfy the earlier prompts, then count
# OPENCODE_API_KEY occurrences in the transcript. Flags passed as arguments.
count_prompt() { # count_prompt <flags...>
  local flags=("$@")
  local out
  out="$(printf '1\n\n\n\n\n\n\n\n\n' | script -qec \
    "cd '$FIX' && bash .standards/scripts/init-ci.sh ${flags[*]}" /dev/null 2>&1 || true)"
  printf '%s\n' "$out" | grep -c 'OPENCODE_API_KEY' || true
}

echo "== AC-024-04-04 / AC-024-04-05 secret prompt gating (interactive) =="

# AC-024-04-04 — With --with-pr-review, OPENCODE_API_KEY is prompted.
WITH_COUNT="$(count_prompt --with-pr-review --platform github --backend go)"
if [ "$WITH_COUNT" -gt 0 ]; then
  ok "AC-024-04-04: OPENCODE_API_KEY is prompted when --with-pr-review is set ($WITH_COUNT occurrences)"
else
  bad "AC-024-04-04: OPENCODE_API_KEY must be prompted when --with-pr-review is set (got $WITH_COUNT)"
fi
rm -rf "$FIX/.github"

# AC-024-04-05 — Without --with-pr-review, OPENCODE_API_KEY is never prompted.
rm -rf "$FIX/.github"
WITHOUT_COUNT="$(count_prompt --platform github --backend go)"
if [ "$WITHOUT_COUNT" -eq 0 ]; then
  ok "AC-024-04-05: OPENCODE_API_KEY is never prompted without --with-pr-review"
else
  bad "AC-024-04-05: OPENCODE_API_KEY must never be prompted without --with-pr-review (got $WITHOUT_COUNT)"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-pr-review.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-pr-review.selftest: all cases pass.${NC}"
