#!/bin/bash
# check-loop-files.sh — Verify the loop-engineering foundation bundle is present.
#
# Checks (standards scope, the default):
#   1. docs/LOOP_ENGINEERING.md exists and is non-empty            (AC-016-01)
#   2. The six durable templates exist and are non-empty           (AC-016-02)
#   3. templates/gate.yaml has the denylist + autoMergeAllowlist
#      keys and all six denylist categories                        (AC-016-02, AC-016-04)
#   4. AGENTS.md references docs/LOOP_ENGINEERING.md and the
#      never-skip-L1 rule                                          (AC-016-03)
#   5. .github/workflows/self-ci.yml runs check-loop-files.sh      (AC-016-05)
#
# A child repo owns only the six templates the bootstrap writes, so
# `--scope child` runs checks 2 and 3 and skips 1, 4, and 5 — the artifacts
# that live in the standards repo itself (docs/LOOP_ENGINEERING.md, the
# AGENTS.md loop refs, self-ci wiring, this script). Child scope is still a
# real gate: a repo missing a template or a gate.yaml key fails it.
#
# Usage:
#   scripts/check-loop-files.sh [--scope standards|child] [ROOT_DIR]
#   scripts/check-loop-files.sh --child [ROOT_DIR]     # alias for --scope child
#   ROOT_DIR defaults to the current directory.
#
# Exit codes:
#   0 — every check in the selected scope passes
#   1 — one or more required files/keys/references are missing or empty
#   2 — usage error (unknown scope or flag)
#
# Standards reference:
#   docs/LOOP_ENGINEERING.md
#   specs/016-loop-engineering-foundation/20-acceptance/ (AC-016-01 … AC-016-05)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
ROOT_DIR=""
SCOPE="standards"

usage_error() {
  echo "ERROR: $*" >&2
  echo "Usage: scripts/check-loop-files.sh [--scope standards|child] [ROOT_DIR]" >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)
      [ $# -ge 2 ] || usage_error "--scope needs a value (standards or child)"
      SCOPE="$2"
      shift 2
      ;;
    --scope=*)
      SCOPE="${1#--scope=}"
      shift
      ;;
    --child)
      SCOPE="child"
      shift
      ;;
    --*)
      usage_error "unknown flag '$1'"
      ;;
    *)
      [ -z "$ROOT_DIR" ] || usage_error "unexpected extra argument '$1'"
      ROOT_DIR="$1"
      shift
      ;;
  esac
done
case "$SCOPE" in
  standards|child) ;;
  *) usage_error "unknown scope '$SCOPE' (expected standards or child)" ;;
esac
ROOT_DIR="${ROOT_DIR:-.}"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

if [ "$SCOPE" = "child" ]; then
  echo "Checking loop-engineering foundation bundle (child scope) in: $ROOT_DIR"
else
  echo "Checking loop-engineering foundation bundle in: $ROOT_DIR"
fi
echo ""

# ── Check 1: docs/LOOP_ENGINEERING.md exists and is non-empty (AC-016-01) ─────
if [ "$SCOPE" = "standards" ]; then
  DOC_FILE="$ROOT_DIR/docs/LOOP_ENGINEERING.md"
  if [ -s "$DOC_FILE" ]; then
    pass "AC-016-01: docs/LOOP_ENGINEERING.md present and non-empty"
  else
    fail "AC-016-01: docs/LOOP_ENGINEERING.md is missing or empty"
  fi

  echo ""
fi

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
if [ "$SCOPE" = "standards" ]; then
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
fi

# ── Check 5: self-ci wiring (AC-016-05) ────────────────────────────────────────
if [ "$SCOPE" = "standards" ]; then
  SELF_CI_FILE="$ROOT_DIR/.github/workflows/self-ci.yml"
  if [ -f "$SELF_CI_FILE" ] && grep -q 'check-loop-files.sh' "$SELF_CI_FILE"; then
    pass "AC-016-05: .github/workflows/self-ci.yml runs check-loop-files.sh"
  else
    fail "AC-016-05: .github/workflows/self-ci.yml does not run check-loop-files.sh"
  fi

  echo ""

  # ── AC-016-04: this script itself is present and executable ────────────────
  if [ -x "$ROOT_DIR/scripts/check-loop-files.sh" ]; then
    pass "AC-016-04: scripts/check-loop-files.sh exists and is executable"
  else
    fail "AC-016-04: scripts/check-loop-files.sh is missing or not executable"
  fi

  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Loop files check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  if [ "$SCOPE" = "child" ]; then
    echo "  Reference: .standards/docs/LOOP_ENGINEERING.md"
  else
    echo "  Reference: docs/LOOP_ENGINEERING.md"
  fi
  exit 1
else
  if [ "$SCOPE" = "child" ]; then
    echo -e "${GREEN}✔ Loop files check (child scope): every check passed.${NC}"
  else
    echo -e "${GREEN}✔ Loop files check: every check passed.${NC}"
  fi
fi

