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
#   .standards/scripts/check-scenario-traceability.sh [SPECS_DIR] [SOURCE_DIR] [-ReportPath <file>]
#   defaults: SPECS_DIR=specs  SOURCE_DIR=.
#
# -ReportPath <file> additionally writes the machine-readable JSON report
# (passes, fails) atomically to <file> — stdout is unchanged.
#
# Exit codes:
#   0 — every scenario traced, every test ID resolves
#   1 — orphaned scenario or dangling test reference
#   2 — unknown option, or -ReportPath with a missing/empty value
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Scenario format
#   docs/SPEC_PIPELINE.md §Why no scenario mutation
set -euo pipefail

# Shared -ReportPath machinery (strip_dashes/json_escape/json_array/
# emit_json_report) — see scripts/gate-report-lib.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-report-lib.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
REPORT_PATH=""
VIOLATIONS_LIST=()
PASSED_IDS=()

fail() { local msg="$*"; echo -e "${RED}FAIL${NC} $msg"; VIOLATIONS=$((VIOLATIONS + 1)); VIOLATIONS_LIST+=("$msg"); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

SPECS_DIR=""
SOURCE_DIR=""
while [ $# -gt 0 ]; do
  if [ "${1#-}" != "$1" ]; then
    name="$(strip_dashes "$1")"
    case "$name" in
      ReportPath)
        REPORT_PATH="${2:-}"
        [ -n "$REPORT_PATH" ] || { echo "Error: -ReportPath requires a non-empty file path" >&2; exit 2; }
        shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
  else
    if [ -z "$SPECS_DIR" ]; then SPECS_DIR="$1"; else SOURCE_DIR="$1"; fi
    shift
  fi
done
SPECS_DIR="${SPECS_DIR:-specs}"
SOURCE_DIR="${SOURCE_DIR:-.}"

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
    PASSED_IDS+=("$id")
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

# ── JSON report (-ReportPath, telemetry) ─────────────────────────────────────
# json_escape / json_array / emit_json_report come from gate-report-lib.sh.
emit_report() {
  [ -n "$REPORT_PATH" ] || return 0
  local json passes_json fails_json
  passes_json=""
  fails_json=""
  [ "${#PASSED_IDS[@]}" -gt 0 ] && passes_json="$(json_array "${PASSED_IDS[@]}")"
  [ "${#VIOLATIONS_LIST[@]}" -gt 0 ] && fails_json="$(json_array "${VIOLATIONS_LIST[@]}")"
  json="{\"passes\":[${passes_json}],\"fails\":[${fails_json}]}"
  emit_json_report "$REPORT_PATH" "$json"
}

emit_report

if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Scenario traceability check: $VIOLATIONS violation(s).${NC}"
  exit 1
else
  echo -e "${GREEN}✔ Scenario traceability check: every scenario traced, every reference resolves.${NC}"
fi
