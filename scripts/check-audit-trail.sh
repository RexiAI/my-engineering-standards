#!/bin/bash
# check-audit-trail.sh — Verify a spec folder carries the audit-trail evidence the
# pipeline contract requires, and that 25-verification.md records real evidence for
# every one of the five contract checks (docs/SPEC_PIPELINE.md §Audit contract).
#
# The script doubles as its own test carrier (spec 015's acceptance tests): the
# --selftest mode builds temp spec-folder fixtures and asserts the exit code of
# every negative case, so the scenarios below are genuinely exercised, not dead
# code (10-tasks.md Task 3).
#
# Checks (scenario IDs from specs/015-auditable-agent-steps/20-acceptance/):
#   AC-015-01 — the audit contract section maps every stage to an evidence artifact
#   AC-015-02 — the contract specifies the evidence each stage must record
#   AC-015-03 — the contract mandates raw, timestamped machine-readable evidence
#   AC-015-04 — a verifier report records real evidence per contract check
#   AC-015-05 — the report carries mutation score, final status, and PR evidence
#   AC-015-06 — the pipeline agents record the evidence their artifacts require
#   AC-015-07 — a complete spec folder exits 0
#   AC-015-08 — no spec folder prints "nothing to check" and exits 0
#   AC-015-09 — missing or empty 10-tasks.md exits non-zero
#   AC-015-10 — missing 20-acceptance/, or all AC-*.md empty or without a
#               `## AC-NNN-NN` heading, exits non-zero
#   AC-015-11 — missing or empty 25-verification.md exits non-zero
#   AC-015-12 — missing or empty 30-report.md exits non-zero
#   AC-015-13 — a present-but-empty 15-design.md exits non-zero
#   AC-015-14 — a verifier report without per-check evidence exits non-zero
#   AC-015-15 — the PR Opener runs the gate before opening the PR
#   AC-015-16 — Self-CI runs the gate when a spec folder is present
#
# Evidence-block contract (AC-015-04): for each of the five runnable Verifier
# checks — scenario traceability, full test suite, complexity gate,
# design-principles gate, scenario-to-behavior spot check — 25-verification.md
# must carry a block headed `## Evidence: <check name>` containing a `command:`
# line, an `exit:` code, an `at:` timestamp in YYYY-MM-DDTHH:MM:SSZ, and
# non-empty raw output. The "no unaccounted behavior" skim is recorded as a
# finding line, not a command, and is not one of the five.
#
# Usage:
#   scripts/check-audit-trail.sh <slug> [SPECS_DIR]
#   scripts/check-audit-trail.sh --selftest
#
# Exit codes:
#   0 — spec folder complete AND verifier evidence complete (or folder absent)
#   1 — missing/empty artifact or incomplete evidence
#   2 — missing <slug> argument (usage error)
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Audit contract
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
SELFTEST_FAILURES=0

pass() { echo -e "${GREEN}PASS${NC} $*"; }
fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }

usage() {
  cat <<'EOF'
Usage:
  scripts/check-audit-trail.sh <slug> [SPECS_DIR]
  scripts/check-audit-trail.sh --selftest

Verify a spec folder carries the audit-trail evidence required by
docs/SPEC_PIPELINE.md §Audit contract: 10-tasks.md, 20-acceptance/ with a
scenario heading, 25-verification.md, 30-report.md (and non-empty 15-design.md
when present), plus per-check evidence blocks in 25-verification.md. --selftest
exercises every negative case against temp fixtures.
EOF
}

# The five runnable Verifier checks the report must carry evidence for (AC-015-04).
FIVE_CHECKS=(
  "scenario traceability"
  "full test suite"
  "complexity gate"
  "design-principles gate"
  "scenario-to-behavior spot check"
)

check_nonempty_file() { # check_nonempty_file <specs_dir> <slug> <relpath> <label>
  local specs_dir="$1" slug="$2" relpath="$3" label="$4"
  local f="$specs_dir/$slug/$relpath"
  if [ ! -f "$f" ]; then
    fail "$slug: missing $relpath ($label)"
  elif [ ! -s "$f" ]; then
    fail "$slug: empty $relpath ($label)"
  else
    pass "$slug: $relpath present and non-empty"
  fi
}

check_acceptance_dir() { # check_acceptance_dir <specs_dir> <slug>
  local specs_dir="$1" slug="$2" dir="$specs_dir/$slug/20-acceptance"
  if [ ! -d "$dir" ]; then
    fail "$slug: missing 20-acceptance/ directory (AC-015-10)"
    return
  fi
  if grep -rlE '^## AC-[0-9]{3}-[0-9]{2}' "$dir"/AC-*.md >/dev/null 2>&1; then
    pass "$slug: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)"
  else
    fail "$slug: 20-acceptance/ has no AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)"
  fi
}

check_design_if_present() { # check_design_if_present <specs_dir> <slug>
  local specs_dir="$1" slug="$2" f="$specs_dir/$slug/15-design.md"
  if [ -f "$f" ]; then
    if [ -s "$f" ]; then
      pass "$slug: 15-design.md present and non-empty (AC-015-13)"
    else
      fail "$slug: 15-design.md is present but empty (AC-015-13)"
    fi
  fi
}

# evidence_block <file> <checkname> — prints the first evidence block whose
# `## Evidence:` heading names <checkname> (case-insensitive), or nothing.
evidence_block() {
  awk -v want="$2" '
    /^## Evidence:/ {
      if (inblock) { print block; exit }
      name = $0
      sub(/^## Evidence:[[:space:]]*/, "", name)
      gsub(/[[:space:]]+$/, "", name)
      if (tolower(name) == tolower(want)) { inblock = 1; block = $0 "\n" }
      next
    }
    inblock { block = block $0 "\n" }
    END { if (inblock) print block }
  ' "$1"
}

# marker <text> <pattern> — prints the first match of <pattern> in <text>, or
# nothing. `|| true` guards the no-match case under set -e.
marker() {
  printf '%s\n' "$1" | grep -m1 -oP "$2" || true
}

# parse_evidence_block <file> <check> — extracts the four markers of the named
# evidence block into EVIDENCE_CMD / EVIDENCE_XC / EVIDENCE_AT / EVIDENCE_BODY.
# Returns 1 (markers left empty) when the block is absent; marker emptiness is
# the caller's signal for which parts are missing.
parse_evidence_block() {
  local f="$1" check="$2" block
  EVIDENCE_CMD=""
  EVIDENCE_XC=""
  EVIDENCE_AT=""
  EVIDENCE_BODY=""
  block="$(evidence_block "$f" "$check" || true)"
  [ -n "$block" ] || return 1
  EVIDENCE_CMD="$(marker "$block" '^command:[[:space:]]*\K.*')"
  EVIDENCE_XC="$(marker "$block" '^exit:[[:space:]]*\K[0-9]+')"
  EVIDENCE_AT="$(marker "$block" '^at:[[:space:]]*\K[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z')"
  EVIDENCE_BODY="$(printf '%s\n' "$block" | grep -vE '^(## Evidence:|command:|exit:|at:)' \
    | sed '/^[[:space:]]*$/d' || true)"
}

check_verifier_evidence() { # check_verifier_evidence <specs_dir> <slug>
  local specs_dir="$1" slug="$2"
  local f="$specs_dir/$slug/25-verification.md"
  local check part missing
  for check in "${FIVE_CHECKS[@]}"; do
    if ! parse_evidence_block "$f" "$check"; then
      fail "$slug: 25-verification.md has no evidence block for '$check' (AC-015-04/AC-015-14)"
      continue
    fi
    missing=""
    for part in "command:$EVIDENCE_CMD" "exit:$EVIDENCE_XC" "at-timestamp:$EVIDENCE_AT" "raw-output:$EVIDENCE_BODY"; do
      [ -n "${part#*:}" ] || missing="$missing ${part%%:*}"
    done
    if [ -n "$missing" ]; then
      fail "$slug: evidence block '$check' is missing:${missing} (AC-015-04)"
      continue
    fi
    pass "$slug: evidence block '$check' — command: $EVIDENCE_CMD, exit: $EVIDENCE_XC, at: $EVIDENCE_AT"
  done
}

check_folder() { # check_folder <slug> <specs_dir> — returns 0/1
  local slug="$1" specs_dir="$2"
  local folder="$specs_dir/$slug"
  VIOLATIONS=0
  if [ ! -d "$folder" ]; then
    echo "Nothing to check — $folder does not exist."
    return 0
  fi
  check_nonempty_file "$specs_dir" "$slug" "10-tasks.md" "AC-015-09"
  check_acceptance_dir "$specs_dir" "$slug"
  check_nonempty_file "$specs_dir" "$slug" "25-verification.md" "AC-015-11"
  check_nonempty_file "$specs_dir" "$slug" "30-report.md" "AC-015-12"
  check_design_if_present "$specs_dir" "$slug"
  if [ -s "$folder/25-verification.md" ]; then
    check_verifier_evidence "$specs_dir" "$slug"
  fi
  if [ "$VIOLATIONS" -gt 0 ]; then
    echo -e "${RED}✘ Audit-trail check: $VIOLATIONS violation(s).${NC}"
    return 1
  fi
  echo -e "${GREEN}✔ Audit-trail check: $folder complete, verifier evidence recorded.${NC}"
  return 0
}

# ── Selftest: exercise every acceptance scenario against temp fixtures ────────
make_complete_fixture() { # make_complete_fixture <base> <slug>
  local base="$1" slug="$2"
  local d="$base/$slug" scid acfile
  scid="$(printf 'AC-%03d-%02d' 1 1)"
  acfile="$(printf 'AC-%03d-%02d-example.md' 1 1)"
  mkdir -p "$d/20-acceptance"
  cat > "$d/10-tasks.md" <<'EOF'
# Fixture spec

## Task 1 — a task

Acceptance criteria for a fixture task.
EOF
  cat > "$d/20-acceptance/$acfile" <<EOF
## $scid — an example scenario

Given a fixture
When checked
Then it passes
EOF
  cat > "$d/25-verification.md" <<'EOF'
# Verification

Overall verdict: PASS

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-08-15T10:00:00Z

Scenario IDs found: 16
Scenario traceability check: every scenario traced, every reference resolves.

## Evidence: full test suite

command: make validate-all
exit: 0
at: 2026-08-15T10:00:01Z

All validations passed.

## Evidence: complexity gate

command: scripts/check-code-principles.sh
exit: 0
at: 2026-08-15T10:00:02Z

No complexity violations.

## Evidence: design-principles gate

command: scripts/check-code-principles.sh
exit: 1
at: 2026-08-15T10:00:03Z

FAIL: complexity exceeds 6
WARN: duplication detected

## Evidence: scenario-to-behavior spot check

command: manual spot check of two acceptance scenarios against their tests
exit: 0
at: 2026-08-15T10:00:04Z

Spot check passed: test assertions match the Given/When/Then.

No unaccounted behavior found in the diff.
EOF
  cat > "$d/30-report.md" <<'EOF'
# Report

Mutation score: skipped — mvp tier
Final test status: green
Verifier verdict: PASS
PR: https://github.com/example/example/pull/1
EOF
}

# expect_run <expected> <label> <base> <slug> — runs check_folder against the
# fixture and reports pass/fail. A mismatch is recorded in SELFTEST_FAILURES, not
# the return code, so call sites stay branch-free statements (set -e safe).
expect_run() {
  local expected="$1" label="$2" base="$3" slug="$4" actual
  if check_folder "$slug" "$base" >/dev/null 2>&1; then
    actual=0
  else
    actual=$?
  fi
  if [ "$actual" -eq "$expected" ]; then
    pass "$label (exit $actual)"
    return 0
  fi
  echo -e "${RED}FAIL${NC} $label — expected exit $expected, got $actual"
  SELFTEST_FAILURES=$((SELFTEST_FAILURES + 1))
  return 0
}

selftest() {
  local base
  SELFTEST_FAILURES=0
  SELFTEST_TMP="$(mktemp -d)"
  trap 'rm -rf "$SELFTEST_TMP"' EXIT
  base="$SELFTEST_TMP/specs"
  mkdir -p "$base"

  make_complete_fixture "$base" "complete"
  expect_run 0 "AC-015-07 — complete folder exits 0" "$base" "complete"
  expect_run 0 "AC-015-08 — no spec folder exits 0" "$base" "absent"

  cp -r "$base/complete" "$base/missing-tasks"
  rm "$base/missing-tasks/10-tasks.md"
  expect_run 1 "AC-015-09 — missing 10-tasks.md exits non-zero" "$base" "missing-tasks"
  cp -r "$base/complete" "$base/empty-tasks"
  : > "$base/empty-tasks/10-tasks.md"
  expect_run 1 "AC-015-09 — empty 10-tasks.md exits non-zero" "$base" "empty-tasks"

  cp -r "$base/complete" "$base/no-acceptance"
  rm -rf "$base/no-acceptance/20-acceptance"
  expect_run 1 "AC-015-10 — missing 20-acceptance/ exits non-zero" "$base" "no-acceptance"
  cp -r "$base/complete" "$base/bad-acceptance"
  rm "$base/bad-acceptance"/20-acceptance/AC-*.md
  : > "$base/bad-acceptance/20-acceptance/AC-blank.md"
  expect_run 1 "AC-015-10 — heading-less 20-acceptance/ exits non-zero" "$base" "bad-acceptance"

  cp -r "$base/complete" "$base/no-verification"
  rm "$base/no-verification/25-verification.md"
  expect_run 1 "AC-015-11 — missing 25-verification.md exits non-zero" "$base" "no-verification"
  cp -r "$base/complete" "$base/empty-verification"
  : > "$base/empty-verification/25-verification.md"
  expect_run 1 "AC-015-11 — empty 25-verification.md exits non-zero" "$base" "empty-verification"

  cp -r "$base/complete" "$base/no-report"
  rm "$base/no-report/30-report.md"
  expect_run 1 "AC-015-12 — missing 30-report.md exits non-zero" "$base" "no-report"

  cp -r "$base/complete" "$base/empty-design"
  : > "$base/empty-design/15-design.md"
  expect_run 1 "AC-015-13 — present-but-empty 15-design.md exits non-zero" "$base" "empty-design"

  cp -r "$base/complete" "$base/no-timestamp"
  sed -i '/^at: 2026-08-15T10:00:00Z$/d' "$base/no-timestamp/25-verification.md"
  expect_run 1 "AC-015-14 — evidence block missing at: timestamp exits non-zero" \
    "$base" "no-timestamp"

  cp -r "$base/complete" "$base/no-output"
  sed -i -e '/^Scenario IDs found: 16$/d' \
    -e '/^Scenario traceability check: every scenario traced, every reference resolves\.$/d' \
    "$base/no-output/25-verification.md"
  expect_run 1 "AC-015-14 — evidence block lacking raw output exits non-zero" \
    "$base" "no-output"

  cp -r "$base/complete" "$base/missing-block"
  awk '
    /^## Evidence: full test suite/ { inblock = 1; next }
    inblock && /^## Evidence:/ { inblock = 0 }
    !inblock { print }
  ' "$base/complete/25-verification.md" > "$base/missing-block/25-verification.md"
  expect_run 1 "AC-015-14 — a contract check with no evidence block exits non-zero" \
    "$base" "missing-block"

  echo ""
  if [ "$SELFTEST_FAILURES" -eq 0 ]; then
    echo -e "${GREEN}✔ Selftest: every audit-trail scenario exercised and passing.${NC}"
    return 0
  fi
  echo -e "${RED}✘ Selftest: $SELFTEST_FAILURES scenario(s) failed.${NC}"
  return 1
}

main() {
  if [ $# -lt 1 ] || [ -z "$1" ]; then
    usage
    exit 2
  fi
  if [ "$1" = "--selftest" ]; then
    if selftest; then exit 0; else exit 1; fi
  fi
  case "$1" in
    */*) echo "Invalid slug (must not contain /): $1" >&2; usage; exit 2 ;;
  esac
  if check_folder "$1" "${2:-specs}"; then
    exit 0
  fi
  exit 1
}

main "$@"
