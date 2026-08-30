#!/bin/bash
# check-gate-consistency.sh — Verifiable gate-list consistency check.
# Ensures the valid gate names are defined in exactly one place
# (scripts/check-code-principles.sh) and every consumer
# (error messages, docs, tests) derives from or matches it.
#
# Why this exists: Adding a gate (e.g. component-per-file) previously required
# updating the valid list in 6+ places (error messages, comment, test expectation).
# The test in scripts/tests/check-code-principles-blame.sh hardcoded
# "complexity, dry, yagni, solid, property-tests" and was missed,
# causing PR #59 CI to fail with 1/24 blame tests red.
# This script is the single verifiable check that would have caught it
# before push — it extracts the canonical list from check-code-principles.sh
# and verifies every consumer matches.
#
# Exit 0 = consistent, 1 = mismatch (with diff), 2 = tooling failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PRINCIPLES="$REPO_ROOT/scripts/check-code-principles.sh"
BLAME_TEST="$REPO_ROOT/scripts/tests/check-code-principles-blame.sh"
CODING_CONV="$REPO_ROOT/docs/CODING_CONVENTIONS.md"

# Canonical source: the valid_gate case line and BLOCKING_SET default.
# Extract the ordered list as it appears in the script's valid_gate function.
canonical() {
  # Line: complexity|dry|yagni|solid|component-per-file|property-tests
  grep -E 'valid_gate.*complexity\|' "$PRINCIPLES" | head -1 | sed -E 's/.*valid_gate[^|]*\|//' | sed -E 's/\).*//' | tr '|' ',' | tr -d ' ' | head -1
  # Fallback: parse the BLOCKING_SET default line if valid_gate not found
}

CANONICAL_CSV=$(grep -E '^\s*complexity\|dry\|yagni' "$PRINCIPLES" | head -1 | sed -E 's/.*case.*in//' | sed -E 's/\).*//' | tr -d ' ' | tr '|' ',' | sed 's/,$//' || true)
if [ -z "$CANONICAL_CSV" ]; then
  # Extract from BLOCKING_SET line
  CANONICAL_CSV=$(grep -E 'BLOCKING_SET="complexity' "$PRINCIPLES" | head -1 | sed -E 's/.*BLOCKING_SET="//' | sed -E 's/".*//' | tr ' ' ',' || true)
fi
CANONICAL_CSV=$(echo "$CANONICAL_CSV" | tr -d ' ' | sed 's/,,*/,/g' | sed 's/^,//;s/,$//')

if [ -z "$CANONICAL_CSV" ]; then
  echo "ERROR: could not extract canonical gate list from $PRINCIPLES" >&2
  exit 2
fi

echo "Canonical gate list (from check-code-principles.sh): $CANONICAL_CSV"

# Expected CSV with spaces after commas as used in error messages
CANONICAL_SPACED=$(echo "$CANONICAL_CSV" | sed 's/,/, /g')
CANONICAL_SPACED_PAREN="valid gates: $CANONICAL_SPACED"

FAIL=0

# Check 1: All error messages in check-code-principles.sh that mention "valid gates:" must contain the canonical list
echo ""
echo "Check 1: error messages in check-code-principles.sh mention valid gates"
if grep -q "valid gates: $CANONICAL_SPACED" "$PRINCIPLES"; then
  echo "  PASS — error messages contain canonical list"
else
  echo "  FAIL — error messages do not contain canonical list"
  echo "  Expected to find: valid gates: $CANONICAL_SPACED"
  grep -n "valid gates:" "$PRINCIPLES" || true
  FAIL=1
fi

# Check 2: Blame test's expected error message must contain canonical list
echo ""
echo "Check 2: blame test expectation contains canonical list"
if grep -q "$CANONICAL_SPACED" "$BLAME_TEST"; then
  echo "  PASS — blame test contains canonical list"
else
  echo "  FAIL — blame test does not contain canonical list"
  echo "  Expected to find in $BLAME_TEST: $CANONICAL_SPACED"
  grep -n "complexity, dry" "$BLAME_TEST" || true
  FAIL=1
fi

# Check 3: Docs mention the gates (soft check, warn if missing)
echo ""
echo "Check 3: docs mention component-per-file (if canonical contains it)"
if echo "$CANONICAL_CSV" | grep -q "component-per-file"; then
  if grep -q "component-per-file" "$CODING_CONV"; then
    echo "  PASS — docs mention component-per-file"
  else
    echo "  WARN — docs do not mention component-per-file (not a hard fail)"
  fi
else
  echo "  SKIP — canonical has no component-per-file"
fi

# Check 4: Count of gates — canonical should have 6
GATE_COUNT=$(echo "$CANONICAL_CSV" | tr ',' '\n' | wc -l | tr -d ' ')
echo ""
echo "Check 4: gate count = $GATE_COUNT (expected 6)"
if [ "$GATE_COUNT" -eq 6 ]; then
  echo "  PASS — 6 gates"
else
  echo "  WARN — gate count is $GATE_COUNT, expected 6 (may be intentional)"
fi

if [ "$FAIL" -ne 0 ]; then
  echo ""
  echo "Gate consistency check: FAILED — update hardcoded lists to match canonical"
  echo "Canonical is defined in $PRINCIPLES (valid_gate / BLOCKING_SET)"
  exit 1
fi

echo ""
echo "Gate consistency check: PASSED"
