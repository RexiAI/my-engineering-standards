#!/bin/bash
# check-bats-assertions.sh — Refuse vacuous assertions in scripts/tests/*.bats.
#
# A bats test that would still pass with its script under test replaced by
# `exit 0` is theatre, not coverage. This gate rejects the three shapes that
# produce it mechanically:
#
#   1. a bare `true` on its own line used where an assertion belongs
#   2. `true || [ ... ]` — the left operand short-circuits, the check never runs
#   3. `run ... || true` with no `$status` / `$output` / `$stderr` assertion
#      before the end of the test body — the exit code is swallowed
#
# Detection is line-based on purpose: no bash parser, no dependency beyond
# grep/sed, and the shapes above are unambiguous at the line level.
#
# Usage:
#   scripts/check-bats-assertions.sh [TESTS_DIR]
# TESTS_DIR defaults to scripts/tests relative to the repo root.
#
# Exit codes:
#   0 — no vacuous assertion found (brief PASS line)
#   1 — at least one violation (each printed as file:line: reason)
#   2 — TESTS_DIR missing or unreadable (tooling failure, never a silent PASS)
#
# Standards reference:
#   docs/TESTING.md, scripts/tests/README.md
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${1:-$(dirname "$SCRIPT_DIR")/scripts/tests}"

if [ ! -d "$TESTS_DIR" ]; then
  echo "ERROR: tests directory not found: $TESTS_DIR" >&2
  exit 2
fi

VIOLATIONS=0

report() {
  echo "  $1:$2: $3"
  VIOLATIONS=$((VIOLATIONS + 1))
}

# scan_file FILE — emit one report line per vacuous shape found in FILE.
scan_file() {
  local file="$1" n=0 line stripped pending_run=0 pending_line=0
  while IFS= read -r line; do
    n=$((n + 1))
    stripped="${line#"${line%%[![:space:]]*}"}"
    stripped="${stripped%%#*}"
    stripped="${stripped%"${stripped##*[![:space:]]}"}"

    case "$stripped" in
      'true || '*) report "$file" "$n" "vacuous: 'true || ...' short-circuits, the check never runs" ;;
      'true') report "$file" "$n" "vacuous: bare 'true' used as an assertion" ;;
    esac

    case "$stripped" in
      'run '*'|| true' | 'run '*'|| :')
        pending_run=1; pending_line=$n ;;
      *'$status'* | *'$output'* | *'$stderr'* | *'${lines['*)
        pending_run=0 ;;
      '}')
        if [ "$pending_run" -eq 1 ]; then
          report "$file" "$pending_line" "vacuous: 'run ... || true' with no \$status/\$output assertion"
          pending_run=0
        fi ;;
    esac
  done < "$file"
}

shopt -s nullglob
FILES=("$TESTS_DIR"/*.bats)
shopt -u nullglob

for f in "${FILES[@]}"; do
  scan_file "$f"
done

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ check-bats-assertions: $VIOLATIONS vacuous assertion(s) in ${TESTS_DIR}.${NC}"
  echo "  Every test must assert an exit code and a contract output fragment."
  echo "  Reference: scripts/tests/README.md"
  exit 1
fi
echo -e "${GREEN}PASS${NC} check-bats-assertions: ${#FILES[@]} bats file(s), no vacuous assertions."
