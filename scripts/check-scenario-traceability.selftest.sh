#!/bin/bash
# check-scenario-traceability.selftest.sh — Hermetic regression net for
# scripts/check-scenario-traceability.sh: proves both checks work in both
# directions (a traced scenario passes, an orphaned scenario is caught, a
# dangling test reference is caught). Fixtures live in `mktemp -d` scratch
# (never inside the repo), cleaned up by a trap.
#
# Covers (scenario traceability: the AC-012-02-NN IDs below are the tests for
# the 20-acceptance scenarios in specs/012-gate-selftests-telemetry/):
#   AC-012-02-01  a traced scenario passes
#   AC-012-02-02  an orphaned scenario is caught
#   AC-012-02-03  a dangling test reference is caught (and the traced one still passes)
#   AC-012-02-04  selftest passes only when all three cases assert correctly
#
# Invokes the checker as `bash "$CHECKER" "$SPECS_DIR" "$SOURCE_DIR"` (positional
# form — it has no flags today; 007's --checks scoped flag is not required here).
# Exits 0 only if all three cases produce their expected exit code and message;
# otherwise names the failing case and exits 1.
#
# Usage:
#   bash scripts/check-scenario-traceability.selftest.sh
# Exit codes:
#   0 — pass/orphan/dangle all assert correctly
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-scenario-traceability.sh"

PASS_COUNT=0
FAIL_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# run_case NAME — runs the checker against $TMP/$NAME (with specs/ and src/ as
# sibling directories so the source scan never includes the specs dir), checks
# the expected exit code and that the output contains every required message.
# The archive dir ($TMP/$NAME/changes) is passed as the third positional so each
# fixture controls its own archived-ID source in isolation.
run_case() {
  local name="$1" expected_rc="$2"
  shift 2
  local out="$TMP/$name.out" missing=0 msg
  set +e
  bash "$CHECKER" "$TMP/$name/specs" "$TMP/$name/src" "$TMP/$name/changes" >"$out" 2>&1
  local rc=$?
  set -e
  if [ "$rc" -ne "$expected_rc" ]; then
    bad "AC-012-02-04 $name: expected exit $expected_rc, got $rc"
    show_out "$out"
    return 1
  fi
  for msg in "$@"; do
    if ! grep -q "$msg" "$out"; then
      bad "AC-012-02-04 $name: output missing '$msg'"
      show_out "$out"
      return 1
    fi
  done
  ok "AC-012-02-04 $name: exit $expected_rc, all expected messages present"
  return 0
}

show_out() {
  echo "  actual output:"
  sed 's/^/    /' "$1" 2>/dev/null | head -20 || true
}

# ── pass: heading + test referencing it (AC-012-02-01) ───────────────────────
# Self-trip constraint (same pattern as model-env.selftest.sh): the fixture
# scenario IDs are constructed at runtime, never inlined as literals — the
# traceability checker scans this file's source, and a literal fixture ID would
# read as a dangling reference with no matching heading.
trace_id() { printf 'AC-%03d-%02d' "$1" "$2"; }
PASS_ID="$(trace_id 999 01)"
ORPHAN_ID="$(trace_id 999 02)"
DANGLE_ID="$(trace_id 999 03)"
# BOGUS_ID must share DANGLE_ID's spec number (999) — spec 027's scoping fix
# (check-scenario-traceability.sh §Check 2) only flags a dangling reference
# for a spec number that currently has an in-flight specs/NNN-*/ folder.
# Using an out-of-flight number here (e.g. 888) would make this case no
# longer exercise check 2 at all after that fix; it must stay in scope.
BOGUS_ID="$(trace_id 999 04)"

mkdir -p "$TMP/pass/specs/999-slug/20-acceptance" "$TMP/pass/src"
printf '## %s — widget renders\nGiven a widget\nWhen it renders\nThen it shows\n' "$PASS_ID" \
  > "$TMP/pass/specs/999-slug/20-acceptance/${PASS_ID}-traced.md"
printf 'func TestWidget_%s(t *testing.T) {}\n' "$(printf '%s' "$PASS_ID" | tr '-' '_')" \
  > "$TMP/pass/src/widget_test.go"

# ── orphan: heading with no reference anywhere in src (AC-012-02-02) ─────────
mkdir -p "$TMP/orphan/specs/999-slug/20-acceptance" "$TMP/orphan/src"
printf '## %s — orphaned scenario\nGiven a scenario\nWhen nothing references it\nThen it is caught\n' "$ORPHAN_ID" \
  > "$TMP/orphan/specs/999-slug/20-acceptance/${ORPHAN_ID}-missing.md"
cat > "$TMP/orphan/src/widget.go" <<'EOF'
package widget
func Render() string { return "hi" }
EOF

# ── dangle: traced heading plus a test citing a bogus ID (AC-012-02-03) ──────
mkdir -p "$TMP/dangle/specs/999-slug/20-acceptance" "$TMP/dangle/src"
printf '## %s — traced scenario\nGiven a widget\nWhen it renders\nThen it shows\n' "$DANGLE_ID" \
  > "$TMP/dangle/specs/999-slug/20-acceptance/${DANGLE_ID}-dangle.md"
printf 'func TestWidget_%s(t *testing.T) {}\nfunc TestBogus_%s(t *testing.T) {}\n' \
  "$(printf '%s' "$DANGLE_ID" | tr '-' '_')" "$(printf '%s' "$BOGUS_ID" | tr '-' '_')" \
  > "$TMP/dangle/src/widget_test.go"

# ── archived: spec merged + archived, its test ID must still resolve ─────────
# Regression guard for the §Archive in the PR defect: archive-spec.sh deletes
# specs/NNN-slug/ on merge while the tests keep citing its IDs. Before the fix,
# check 2 resolved only against specs/*/20-acceptance/, so every merged spec
# permanently dangled its own IDs (81 in llm-app) and the gate could never pass
# again. The archive one-pager carries the '## AC-NNN-NN' headings verbatim, so
# it is an authoritative ID source.
ARCHIVED_ID="$(trace_id 997 01)"
mkdir -p "$TMP/archived/specs" "$TMP/archived/src" "$TMP/archived/changes"
printf '# 997-merged-slug\n\n## Acceptance scenarios\n\n## %s — archived scenario\n' "$ARCHIVED_ID" \
  > "$TMP/archived/changes/997-merged-slug.md"
printf 'func TestArchived_%s(t *testing.T) {}\n' "$(printf '%s' "$ARCHIVED_ID" | tr '-' '_')" \
  > "$TMP/archived/src/archived_test.go"
# ── out_of_flight: a reference to a spec number with NO specs/NNN-*/ folder
# at all must NOT be flagged (spec 027, AC-027-01) — this is exactly the
# permanent, by-design state of every archived spec's own deliverables-gate
# script (e.g. check-pr-review.sh's AC-024-* self-citations, once
# specs/024-pr-review-agent/ is archived and deleted). Only in-flight specs/
# folders are in scope for the dangling-reference check.
OUT_OF_FLIGHT_TRACED_ID="$(trace_id 999 05)"
OUT_OF_FLIGHT_ARCHIVED_ID="$(trace_id 700 01)"
mkdir -p "$TMP/out_of_flight/specs/999-slug/20-acceptance" "$TMP/out_of_flight/src"
printf '## %s — traced scenario\nGiven a widget\nWhen it renders\nThen it shows\n' "$OUT_OF_FLIGHT_TRACED_ID" \
  > "$TMP/out_of_flight/specs/999-slug/20-acceptance/${OUT_OF_FLIGHT_TRACED_ID}-traced.md"
printf 'func TestWidget_%s(t *testing.T) {}\nfunc TestArchived_%s(t *testing.T) {}\n' \
  "$(printf '%s' "$OUT_OF_FLIGHT_TRACED_ID" | tr '-' '_')" "$(printf '%s' "$OUT_OF_FLIGHT_ARCHIVED_ID" | tr '-' '_')" \
  > "$TMP/out_of_flight/src/widget_test.go"
# Note: no specs/700-*/ folder exists anywhere under $TMP/out_of_flight —
# spec 700 is "archived" (or simply doesn't exist) from this fixture's point
# of view, exactly like every real archived spec on this repo's own main.

# ── stale_archived: an archived spec IS an authority, so a typo'd ID for that
# spec number must still be caught. This is what the hybrid buys over scoping
# to in-flight specs alone, where this reference would be silently skipped.
STALE_ARCHIVED_REAL="$(trace_id 996 01)"
STALE_ARCHIVED_TYPO="$(trace_id 996 47)"
mkdir -p "$TMP/stale_archived/specs" "$TMP/stale_archived/src" "$TMP/stale_archived/changes"
printf '# 996-merged-slug\n\n## Acceptance scenarios\n\n## %s — archived scenario\n' "$STALE_ARCHIVED_REAL" \
  > "$TMP/stale_archived/changes/996-merged-slug.md"
printf 'func TestStale_%s(t *testing.T) {}\n' "$(printf '%s' "$STALE_ARCHIVED_TYPO" | tr '-' '_')" \
  > "$TMP/stale_archived/src/stale_test.go"

# ── Run ──────────────────────────────────────────────────────────────────────
echo "== AC-012-02 traceability selftest =="
run_case pass 0 "$PASS_ID — traced to a test"
run_case orphan 1 "no test references it"
run_case dangle 1 "no matching scenario heading exists" "$DANGLE_ID — traced to a test"
run_case archived 0 "every scenario traced, every reference resolves"
run_case out_of_flight 0 "$OUT_OF_FLIGHT_TRACED_ID — traced to a test"
run_case stale_archived 1 "no matching scenario heading exists"

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-scenario-traceability selftest: $FAIL_COUNT case(s) failed, $PASS_COUNT passed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-scenario-traceability selftest: $PASS_COUNT cases passed.${NC}"
