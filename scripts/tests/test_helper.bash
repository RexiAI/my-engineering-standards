#!/usr/bin/env bash
# test_helper.bash — shared helper for Track B bats tests (spec 001)
# Loaded by bats via `load test_helper` in each .bats file.
#
# Why bats-core ≥1.10: shellspec was evaluated and rejected — bats is the
# de-facto standard for shell testing, TAP-native, zero Ruby dependency,
# and ships in every CI image. shellspec's Ruby + custom DSL adds friction
# without coverage gain. bats ≥1.10 required for `run --separate-stderr` and
# stable `--tap` formatting.
#
# Safety: guarded against double-sourcing. Sources gate-report-lib.sh and
# check-common.sh once, without redefining json_escape (check-common.sh guards
# it; gate-report-lib.sh defines it first).
#
# Usage in bats:
#   load test_helper
#   setup() { setup_tmpdir; }
#   teardown() { teardown_tmpdir; }

if [[ -n "${TEST_HELPER_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
TEST_HELPER_LOADED=1

# Resolve repo root from helper location (scripts/tests/test_helper.bash → repo root)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export REPO_ROOT

# Source shared libs safely — order matters: gate-report-lib defines json_escape,
# check-common guards against redefinition.
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/gate-report-lib.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/scripts/check-common.sh"

# Temp dir helpers for hermetic tests (AC-002-08, AC-003-08)
setup_tmpdir() {
  TMPDIR_HELPER="$(mktemp -d)"
  export TMPDIR_HELPER
}

teardown_tmpdir() {
  if [[ -n "${TMPDIR_HELPER:-}" && -d "$TMPDIR_HELPER" ]]; then
    rm -rf "$TMPDIR_HELPER"
  fi
}

# Assert helpers
assert_exit_code() {
  local expected="$1" actual="$2"
  if [[ "$actual" -ne "$expected" ]]; then
    echo "expected exit $expected, got $actual" >&2
    return 1
  fi
}

# Create a minimal git repo in a temp dir for tests needing git
setup_git_repo() {
  local dir="${1:-$TMPDIR_HELPER}"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "$dir"
}
