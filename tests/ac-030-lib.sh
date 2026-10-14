#!/usr/bin/env bash
# ac-030-lib.sh — shared assertion helpers for the spec 030 acceptance tests
# (tests/AC-030-NN.sh). Not a test itself; sourced by every task test file.
#
# Test approach per specs/030-e2e-skill-agent/10-tasks.md header: plain shell
# assertion tests, runnable via `bash tests/AC-030-NN.sh`, exit 0 on pass.
#
# Scenario-ID dispatch: each scenario AC-030-NN-MM lives in one shell function
# named s_030_NN_MM (function name + PASS/FAIL lines carry the ID greppably).
#   bash tests/AC-030-01.sh               # run every scenario + unit of T1
#   bash tests/AC-030-01.sh AC-030-01-05  # run one scenario
# Unit checks (logic the scenarios don't reach) are functions named u_030_*.

PASSES=0
FAILS=0

AC030_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AC030_ROOT="$(dirname "$AC030_TESTS_DIR")"
export AC030_TESTS_DIR AC030_ROOT

pass() { PASSES=$((PASSES + 1)); echo "PASS $1"; }
fail() { FAILS=$((FAILS + 1)); echo "FAIL $1"; }

# exists <id> <path> — file exists
exists() {
  if [ -f "$2" ]; then pass "$1: $2 exists"; else fail "$1: $2 does not exist"; fi
}

# require <id> <file> — the suite's single missing-file guard: prints a FAIL
# and returns 1. Scenario functions use `require <id> <file> || return 0`;
# the assertion helpers use it directly.
require() {
  if [ -f "$2" ]; then return 0; fi
  fail "$1: $2 missing"
  return 1
}

# contains <id> <file> <ERE> <label> — file exists and matches ERE somewhere.
# `-e` before the pattern: patterns may begin with a dash (flags like
# --strict-cache); without it getopt swallows them.
contains() {
  local id="$1" file="$2" pat="$3" label="${4:-pattern}"
  require "$id" "$file" || return 0
  if grep -qE -e "$pat" -- "$file"; then pass "$id: $file contains $label"; else fail "$id: $file missing $label (/$pat/)"; fi
}

# contains_i <id> <file> <ERE> <label> — case-insensitive contains
contains_i() {
  local id="$1" file="$2" pat="$3" label="${4:-pattern}"
  require "$id" "$file" || return 0
  if grep -qiE -e "$pat" -- "$file"; then pass "$id: $file contains $label"; else fail "$id: $file missing $label (/$pat/i)"; fi
}

# not_contains <id> <file> <ERE> <label> — forbidden content absent
not_contains() {
  local id="$1" file="$2" pat="$3" label="${4:-pattern}"
  require "$id" "$file" || return 0
  if grep -qE -e "$pat" -- "$file"; then fail "$id: $file must NOT contain $label (/$pat/)"; else pass "$id: $file clean of $label"; fi
}

# not_contains_i <id> <file> <ERE> <label> — case-insensitive not_contains
not_contains_i() {
  local id="$1" file="$2" pat="$3" label="${4:-pattern}"
  require "$id" "$file" || return 0
  if grep -qiE -e "$pat" -- "$file"; then fail "$id: $file must NOT contain $label (/$pat/i)"; else pass "$id: $file clean of $label"; fi
}

# fm_of <file> — frontmatter lines (between first and second '---') to stdout
fm_of() {
  awk 'NR == 1 { if ($0 ~ /^---[[:space:]]*$/) { f = 1; next } exit }
       f && $0 ~ /^---[[:space:]]*$/ { exit }
       f' "$1"
}

# body_of <file> — content after the frontmatter's closing '---'
body_of() {
  awk 'BEGIN { n = 0 } /^---[[:space:]]*$/ { n++; next } n >= 2' "$1"
}

# fm_field <file> <key> — frontmatter value for key, quotes stripped
fm_field() {
  fm_of "$1" | grep -m1 -E "^$2:" | sed -E "s/^$2:[[:space:]]*//; s/^[\"']//; s/[\"']$//"
}

# Model/provider id pattern, assembled at runtime by concatenation so the
# pattern literals in this test suite never self-match a grep for the pattern
# (same construction precedent as scripts/check-no-hardcoded-secrets.sh).
IDP_A="gp""t-"
IDP_B="clau""de-"
IDP_C="gem""ini-"
IDP_D="open""ai/"
IDP_E="anth""ropic/"
IDP_F="goo""gle/"
IDP_G="mist""ral/"
ID_PATTERNS="$IDP_A|$IDP_B|$IDP_C|$IDP_D|$IDP_E|$IDP_F|$IDP_G"

# forbidden_phrase() — the remediation-budget phrase (docs/SPEC_PIPELINE.md
# §Remediation budget), assembled so this file does not contain it verbatim.
forbidden_phrase() { printf '%s' 're-'"run until green"; }

# no_forbidden_phrase <id> <file> [label] — assert the remediation-budget
# phrase is absent from <file>; the label differs per scenario, default here
# matches the most common one.
no_forbidden_phrase() {
  not_contains_i "$1" "$2" "$(forbidden_phrase)" "${3:-the forbidden re-run phrasing}"
}

# run_matching <regex> — invoke every defined function whose name matches
run_matching() {
  local pat="$1" fn
  while IFS= read -r fn; do
    [ -n "$fn" ] && "$fn"
  done < <(declare -F | awk -v p="$pat" '$3 ~ p { print $3 }' | sort)
}

# finish <label> — print summary; exit 1 if any check failed
finish() {
  echo "RESULT $1: passed=$PASSES failed=$FAILS"
  [ "$FAILS" -eq 0 ] || exit 1
  exit 0
}

# main_dispatch <task-prefix> "$@" — `bash tests/AC-030-NN.sh [AC-030-NN-MM]`
main_dispatch() {
  local prefix="$1" target="${2:-all}" fn
  if [ "$target" = "all" ]; then
    run_matching "^s_${prefix}_"; run_matching "^u_${prefix}_"
  else
    fn="s_$(printf '%s' "${target#AC-}" | tr '-' '_')"
    if ! declare -F "$fn" >/dev/null 2>&1; then
      echo "unknown scenario id: $target" >&2
      exit 2
    fi
    "$fn"
  fi
}
