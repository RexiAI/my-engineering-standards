#!/bin/bash
# check-scenario-traceability.sh — Verify every acceptance scenario ID is wired to
# a real test, and every test's cited ID actually exists.
#
# Checks:
#   1. Every AC-NNN-NN heading in specs/*/20-acceptance/*.md has a matching test
#      (test name/description containing the same ID, underscores or hyphens).
#   2. Every AC-NNN-NN reference found in test files resolves to a real scenario
#      heading — catches copy-paste typos and stale IDs after a scenario is
#      renumbered or removed. Resolution spans BOTH live specs
#      (specs/*/20-acceptance/*.md) and archived ones (docs/changes/*.md),
#      because docs/SPEC_PIPELINE.md §Archive in the PR deletes specs/NNN-slug/
#      on merge while the tests keep citing its AC-NNN-NN IDs. archive-spec.sh
#      copies the '## AC-NNN-NN' headings verbatim into the one-pager, so the
#      archive is an authoritative ID source. Without this, every merged spec
#      permanently dangles its own IDs and check 2 can never pass again in a
#      repo that has archived even one spec.
#
# The Verifier re-runs a single failing check on a BLOCK/FAIL fix
# (AC-007-02, AC-007-04): --checks narrows the run to check 1 and/or check 2,
# and --json emits a machine-readable transcript the Verifier transcribes into
# specs/NNN-slug/25-verification.md (AC-007-04-04, AC-007-04-05). A tooling
# failure — a required tool missing or the source directory unreadable — exits 2,
# so a run that could not perform its check is never reported as clean
# (AC-007-04-06): BLOCK, not PASS.
#
# Usage:
#   .standards/scripts/check-scenario-traceability.sh [--checks 1|2|1,2] [--json] [-ReportPath <file>] [SPECS_DIR] [SOURCE_DIR] [ARCHIVE_DIR]
#   defaults: SPECS_DIR=specs  SOURCE_DIR=.  ARCHIVE_DIR=docs/changes
#   --checks selects which checks run (default: both); --json prints a single
#   JSON object { "checks": [...], "passes": [...], "fails": [...] } instead of
#   the human output, with the same exit code.
#
# -ReportPath <file> additionally writes the machine-readable JSON report
# (passes, fails) atomically to <file> — stdout is unchanged.
#
# Exit codes:
#   0 — every scenario traced, every test ID resolves (or nothing to check)
#   1 — orphaned scenario or dangling test reference
#   2 — could not perform the check for a non-finding reason (missing tool such
#       as grep/sed, unreadable source directory, or usage error — unknown
#       option, bad/empty --checks value, or -ReportPath with a missing/empty
#       value)
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Scenario format
#   docs/SPEC_PIPELINE.md §Why no scenario mutation
#   agents/spec-verifier.md (script-is-authority / BLOCK discipline)
set -euo pipefail

# Shared -ReportPath machinery (strip_dashes/json_escape/json_array/
# emit_json_report) — see scripts/gate-report-lib.sh. json_escape comes from
# this lib; check-common.sh's copy is guarded so it does not redefine it.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-report-lib.sh"
# Shared 007 helpers (require_tools / finish_clean / guarded json_escape).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
REPORT_PATH=""
VIOLATIONS_LIST=()
PASSED_IDS=()
CHECKS="1,2"
JSON=false
POSITIONAL=()

# One parser for both flag styles (see gate-report-lib.sh): 007's double-dash
# flags (--checks, --json) and 012's single-dash -ReportPath. strip_dashes
# makes the styles coexist without two parsers.
while [ $# -gt 0 ]; do
  if [ "${1#-}" != "$1" ]; then
    name="$(strip_dashes "$1")"
    case "$name" in
      checks) CHECKS="${2:-}"; shift $(( $# > 1 ? 2 : 1 )) ;;
      json) JSON=true; shift ;;
      ReportPath)
        REPORT_PATH="${2:-}"
        [ -n "$REPORT_PATH" ] || { echo "Error: -ReportPath requires a non-empty file path" >&2; exit 2; }
        shift $(( $# > 1 ? 2 : 1 )) ;;
      *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
  else
    POSITIONAL+=("$1"); shift
  fi
done

SPECS_DIR="${POSITIONAL[0]:-specs}"
SOURCE_DIR="${POSITIONAL[1]:-.}"
ARCHIVE_DIR="${POSITIONAL[2]:-docs/changes}"

# ── Tooling preflight (AC-007-04-06): a missing tool is exit 2, never a clean ──
require_tools traceability grep sed sort wc tr

# ── --checks validation (AC-007-04-07): unknown number or empty list = exit 2 ──
if [ -z "$CHECKS" ]; then
  echo "ERROR: --checks requires a comma-separated list of check numbers (1, 2)" >&2
  exit 2
fi
SELECTED=""
IFS=',' read -r -a check_list <<< "$CHECKS"
for c in "${check_list[@]}"; do
  case "$c" in
    1|2) SELECTED="$SELECTED,$c" ;;
    *) echo "ERROR: unknown check number '$c' (valid: 1, 2)" >&2; exit 2 ;;
  esac
done
SELECTED="${SELECTED#,}"

contains() { # contains 1|2
  case ",$SELECTED," in *",$1,"*) return 0 ;; esac
  return 1
}

# fail/pass feed all three outputs: human stdout (unless --json), the --json
# transcript (PASSES_JSON/FAILS_JSON), and the -ReportPath file report
# (PASSED_IDS / VIOLATIONS_LIST).
fail() { # human fail line, recorded for --json and -ReportPath
  VIOLATIONS=$((VIOLATIONS + 1))
  if [ "$JSON" = true ]; then FAILS_JSON+=("$*"); else echo -e "${RED}FAIL${NC} $*"; fi
  VIOLATIONS_LIST+=("$*")
}
pass() { # human pass line, recorded for --json
  if [ "$JSON" = true ]; then PASSES_JSON+=("$*"); else echo -e "${GREEN}PASS${NC} $*"; fi
}
say() { [ "$JSON" = false ] && echo "$@"; return 0; }

emit_json() {
  local i checks_json="" passes_json="" fails_json=""
  for i in "${check_list[@]}"; do checks_json+="$(json_escape "$i"), "; done
  checks_json="${checks_json%, }"
  for i in "${PASSES_JSON[@]}"; do passes_json+="\"$(json_escape "$i")\", "; done
  passes_json="${passes_json%, }"
  for i in "${FAILS_JSON[@]}"; do fails_json+="\"$(json_escape "$i")\", "; done
  fails_json="${fails_json%, }"
  printf '{\n  "checks": [%s],\n  "passes": [%s],\n  "fails": [%s]\n}\n' "$checks_json" "$passes_json" "$fails_json"
}

PASSES_JSON=()
FAILS_JSON=()

if [ ! -d "$SOURCE_DIR" ] || [ ! -r "$SOURCE_DIR" ]; then
  echo "ERROR: source directory '$SOURCE_DIR' is missing or unreadable — cannot perform the traceability check" >&2
  exit 2
fi

# specs/ is excluded because scenario markdown cites its own IDs in prose; the
# archive dir is excluded for exactly the same reason — docs/changes/*.md is the
# merged form of specs/ and quotes IDs (including illustrative ones) in prose.
# Both are ID *sources* for resolution, never *reference* sites for check 2.
GREP_EXCLUDES="--exclude-dir=node_modules --exclude-dir=target --exclude-dir=vendor --exclude-dir=.git --exclude-dir=.standards --exclude-dir=dist --exclude-dir=specs --exclude-dir=$(basename "$ARCHIVE_DIR")"

# ── Collect scenario IDs from specs/*/20-acceptance/*.md ─────────────────────
# Match "## AC-NNN-NN" headings, e.g. "## AC-002-01 — Apply a percentage discount"
SCENARIO_IDS=""
if [ -d "$SPECS_DIR" ]; then
  SCENARIO_IDS=$(grep -rhoE '^## (AC-[0-9]{3}-[0-9]{2})' "$SPECS_DIR"/*/20-acceptance/*.md 2>/dev/null \
    | sed -E 's/^## //' | sort -u || true)
fi

# ── Collect scenario IDs from archived one-pagers (docs/changes/*.md) ────────
# archive-spec.sh copies the '## AC-NNN-NN' headings verbatim into the archive,
# so a merged spec's IDs stay resolvable after specs/NNN-slug/ is deleted
# (docs/SPEC_PIPELINE.md §Archive in the PR). Check 2 only — an archived spec
# must not re-demand a test via check 1.
ARCHIVED_IDS=""
if [ -d "$ARCHIVE_DIR" ]; then
  ARCHIVED_IDS=$(grep -rhoE '^## (AC-[0-9]{3}-[0-9]{2})' "$ARCHIVE_DIR"/*.md 2>/dev/null \
    | sed -E 's/^## //' | sort -u || true)
fi

# Nothing to resolve against at all — no live specs and no archive. On a repo
# whose specs are all merged and archived, ARCHIVED_IDS still lets check 2 catch
# a typo'd ID, so this only fires when neither source exists.
if [ -z "$SCENARIO_IDS" ] && [ -z "$ARCHIVED_IDS" ]; then
  finish_clean "No AC-NNN-NN scenario headings found under $SPECS_DIR/*/20-acceptance/ or $ARCHIVE_DIR/*.md — nothing to check."
fi

say "Scenario IDs found: $(echo "$SCENARIO_IDS" | grep -c . || true) live, $(echo "$ARCHIVED_IDS" | grep -c . || true) archived"
say ""

# ── Collect every AC-NNN-NN reference anywhere in source/test files ──────────
# Test naming turns hyphens into underscores (AC_002_01) per docs/SPEC_PIPELINE.md,
# so match both forms.
REFERENCED_IDS=$(grep -rhoE 'AC[_-][0-9]{3}[_-][0-9]{2}' "$SOURCE_DIR" \
  $GREP_EXCLUDES 2>/dev/null | tr '_' '-' | sort -u || true)


# ── Check 1: every scenario has a matching test reference (AC-007-04-01) ─────
if contains 1; then
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
  say ""
fi

# ── Check 2: every test reference resolves to a real scenario (AC-007-04-02) ─
# Resolves against live specs AND archived one-pagers: a merged spec's tests keep
# citing IDs whose specs/NNN-slug/ folder archive-spec.sh has already deleted.
if contains 2; then
  KNOWN_IDS=$(printf '%s\n%s\n' "$SCENARIO_IDS" "$ARCHIVED_IDS" | grep -v '^$' | sort -u)
  for id in $REFERENCED_IDS; do
    if ! echo "$KNOWN_IDS" | grep -qx "$id"; then
      fail "$id — referenced in a test but no matching scenario heading exists in " \
           "$SPECS_DIR/*/20-acceptance/ or $ARCHIVE_DIR/*.md. Stale ID after a rename, or a typo."
    fi
  done
  say ""
fi

if [ "$VIOLATIONS" -gt 0 ]; then
  say -e "${RED}✘ Scenario traceability check: $VIOLATIONS violation(s).${NC}"
else
  say -e "${GREEN}✔ Scenario traceability check: every scenario traced, every reference resolves.${NC}"
fi

if [ "$JSON" = true ]; then
  emit_json
fi

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
  exit 1
else
  exit 0
fi
