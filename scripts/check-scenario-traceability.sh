#!/bin/bash
# check-scenario-traceability.sh — Verify every acceptance scenario ID is wired to
# a real test, and every test's cited ID actually exists.
#
# Checks:
#   1. Every AC-NNN-NN heading in specs/*/20-acceptance/*.md has a matching test
#      (test name/description containing the same ID, underscores or hyphens).
#   2. Every AC-NNN-NN reference found in test files resolves to a real scenario
#      heading — catches copy-paste typos and stale IDs after a scenario is
#      renumbered or removed.
#
# Usage:
#   .standards/scripts/check-scenario-traceability.sh [SPECS_DIR] [SOURCE_DIR]
#   defaults: SPECS_DIR=specs  SOURCE_DIR=.
#
# Exit codes:
#   0 — every scenario traced, every test ID resolves
#   1 — orphaned scenario or dangling test reference
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Scenario format
#   docs/SPEC_PIPELINE.md §Why no scenario mutation
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
SPECS_DIR="${1:-specs}"
SOURCE_DIR="${2:-.}"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

if [ ! -d "$SPECS_DIR" ]; then
  echo "No $SPECS_DIR/ directory — nothing to check."
  exit 0
fi

GREP_EXCLUDES='--exclude-dir=node_modules --exclude-dir=target --exclude-dir=vendor --exclude-dir=.git --exclude-dir=.standards --exclude-dir=dist --exclude-dir=specs'

# ── Collect scenario IDs from specs/*/20-acceptance/*.md ─────────────────────
# Match "## AC-NNN-NN" headings, e.g. "## AC-002-01 — Apply a percentage discount"
SCENARIO_IDS=$(grep -rhoE '^## (AC-[0-9]{3}-[0-9]{2})' "$SPECS_DIR"/*/20-acceptance/*.md 2>/dev/null \
  | sed -E 's/^## //' | sort -u || true)

if [ -z "$SCENARIO_IDS" ]; then
  echo "No AC-NNN-NN scenario headings found under $SPECS_DIR/*/20-acceptance/ — nothing to check."
  exit 0
fi

echo "Scenario IDs found: $(echo "$SCENARIO_IDS" | wc -l | tr -d ' ')"
echo ""

# ── Collect every AC-NNN-NN reference anywhere in source/test files ──────────
# Test naming turns hyphens into underscores (AC_002_01) per docs/SPEC_PIPELINE.md,
# so match both forms.
REFERENCED_IDS=$(grep -rhoE 'AC[_-][0-9]{3}[_-][0-9]{2}' "$SOURCE_DIR" \
  $GREP_EXCLUDES 2>/dev/null | tr '_' '-' | sort -u || true)

# ── Check 1: every scenario has a matching test reference ───────────────────
for id in $SCENARIO_IDS; do
  if echo "$REFERENCED_IDS" | grep -qx "$id"; then
    pass "$id — traced to a test"
  else
    fail "$id — scenario defined in $SPECS_DIR/*/20-acceptance/ but no test references it. " \
         "Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete " \
         "and remove the scenario instead of leaving it untraced."
  fi
done

echo ""

# ── Check 2: every test reference resolves to a real scenario ───────────────
for id in $REFERENCED_IDS; do
  if echo "$SCENARIO_IDS" | grep -qx "$id"; then
    :
  else
    fail "$id — referenced in a test but no matching scenario heading exists in " \
         "$SPECS_DIR/*/20-acceptance/. Stale ID after a rename, or a typo."
  fi
done

echo ""

if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Scenario traceability check: $VIOLATIONS violation(s).${NC}"
  exit 1
else
  echo -e "${GREEN}✔ Scenario traceability check: every scenario traced, every reference resolves.${NC}"
fi
