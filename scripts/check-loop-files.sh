#!/bin/bash
# check-loop-files.sh — Verify the loop-engineering foundation bundle is present.
#
# Checks:
#   1. docs/LOOP_ENGINEERING.md exists and is non-empty            (AC-016-01)
#   2. The six durable templates exist and are non-empty           (AC-016-02)
#   3. templates/gate.yaml has the denylist + autoMergeAllowlist
#      keys and all six denylist categories                        (AC-016-02, AC-016-04)
#   4. AGENTS.md references docs/LOOP_ENGINEERING.md and the
#      never-skip-L1 rule                                          (AC-016-03)
#   5. .github/workflows/self-ci.yml runs check-loop-files.sh      (AC-016-05)
#
# Usage:
#   scripts/check-loop-files.sh [ROOT_DIR]
#   ROOT_DIR defaults to the current directory.
#
# Exit codes:
#   0 — every check passes
#   1 — one or more required files/keys/references are missing or empty
#
# Standards reference:
#   docs/LOOP_ENGINEERING.md
#   specs/016-loop-engineering-foundation/20-acceptance/ (AC-016-01 … AC-016-05)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
ROOT_DIR="${1:-.}"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

echo "Checking loop-engineering foundation bundle in: $ROOT_DIR"
echo ""

# ── Check 1: docs/LOOP_ENGINEERING.md exists and is non-empty (AC-016-01) ─────
DOC_FILE="$ROOT_DIR/docs/LOOP_ENGINEERING.md"
if [ -s "$DOC_FILE" ]; then
  pass "AC-016-01: docs/LOOP_ENGINEERING.md present and non-empty"
else
  fail "AC-016-01: docs/LOOP_ENGINEERING.md is missing or empty"
fi

echo ""

# ── Check 2: the six durable templates exist and are non-empty (AC-016-02) ────
TEMPLATES=(LOOP.md STATE.md loop-run-log.md loop-budget.md loop-constraints.md gate.yaml)
for t in "${TEMPLATES[@]}"; do
  f="$ROOT_DIR/templates/$t"
  if [ -s "$f" ]; then
    pass "AC-016-02: templates/$t present and non-empty"
  else
    fail "AC-016-02: templates/$t is missing or empty"
  fi
done

echo ""

# ── Check 3: templates/gate.yaml denylist contract (AC-016-02, AC-016-04) ─────
GATE_FILE="$ROOT_DIR/templates/gate.yaml"
if [ -f "$GATE_FILE" ]; then
  if grep -q 'denylist:' "$GATE_FILE" && grep -q 'autoMergeAllowlist:' "$GATE_FILE" \
     && grep -qF '.env' "$GATE_FILE" && grep -qF 'secrets' "$GATE_FILE" \
     && grep -qF 'auth' "$GATE_FILE" && grep -qF 'payments' "$GATE_FILE" \
     && grep -qF 'k8s/production' "$GATE_FILE" && grep -qF 'migrations' "$GATE_FILE"; then
    pass "AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories"
  else
    grep -q 'denylist:' "$GATE_FILE" || fail "AC-016-04: gate.yaml missing 'denylist:' key"
    grep -q 'autoMergeAllowlist:' "$GATE_FILE" || fail "AC-016-04: gate.yaml missing 'autoMergeAllowlist:' key"
    for c in '.env' 'secrets' 'auth' 'payments' 'k8s/production' 'migrations'; do
      grep -qF "$c" "$GATE_FILE" || fail "AC-016-04: gate.yaml denylist missing category '$c'"
    done
  fi
else
  fail "AC-016-04: templates/gate.yaml missing — cannot verify denylist contract"
fi

echo ""

# ── Check 4: AGENTS.md references (AC-016-03) ──────────────────────────────────
AGENTS_FILE="$ROOT_DIR/AGENTS.md"
if [ -f "$AGENTS_FILE" ]; then
  HAS_DOC_REF=false
  HAS_L1_RULE=false
  grep -q 'docs/LOOP_ENGINEERING.md' "$AGENTS_FILE" && HAS_DOC_REF=true
  grep -q 'Loops never skip L1' "$AGENTS_FILE" && HAS_L1_RULE=true
  if $HAS_DOC_REF && $HAS_L1_RULE; then
    pass "AC-016-03: AGENTS.md references LOOP_ENGINEERING.md and the never-skip-L1 rule"
  else
    $HAS_DOC_REF || fail "AC-016-03: AGENTS.md does not reference docs/LOOP_ENGINEERING.md"
    $HAS_L1_RULE || fail "AC-016-03: AGENTS.md missing the never-skip-L1 rule"
  fi
else
  fail "AC-016-03: AGENTS.md missing — cannot verify references"
fi

echo ""

# ── Check 5: self-ci wiring (AC-016-05) ────────────────────────────────────────
SELF_CI_FILE="$ROOT_DIR/.github/workflows/self-ci.yml"
if [ -f "$SELF_CI_FILE" ] && grep -q 'check-loop-files.sh' "$SELF_CI_FILE"; then
  pass "AC-016-05: .github/workflows/self-ci.yml runs check-loop-files.sh"
else
  fail "AC-016-05: .github/workflows/self-ci.yml does not run check-loop-files.sh"
fi

echo ""

# ── AC-016-04: this script itself is present and executable ──────────────────
if [ -x "$ROOT_DIR/scripts/check-loop-files.sh" ]; then
  pass "AC-016-04: scripts/check-loop-files.sh exists and is executable"
else
  fail "AC-016-04: scripts/check-loop-files.sh is missing or not executable"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Loop files check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/LOOP_ENGINEERING.md"
  exit 1
else
  echo -e "${GREEN}✔ Loop files check: every check passed.${NC}"
fi
