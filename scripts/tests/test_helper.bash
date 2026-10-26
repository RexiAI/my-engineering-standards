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

# Hermeticity: git exports GIT_DIR (and friends) when running hooks — e.g.
# `make test-scripts` under pre-push inside a submodule checkout. A leaked
# GIT_DIR makes every fixture call like `git -C "$TMPDIR/..." config ...`
# ignore -C and write into the HOST repo's config instead of the temp fixture
# (the exact core.bare/core.worktree corruption check-common.bats
# characterizes — observed live: a pre-push run bricked the host submodule
# config). Unset the hook-exported discovery vars for all tests.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR \
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_QUARANTINE_PATH

# Hermeticity: the judgment layer's tests assert behaviour when its credentials
# and backend selection are ABSENT — AC-028-02 ("JUDGMENT_API_KEY unset exits 10
# without any HTTP request"), AC-028-04 (empty string), AC-028-50 ("passes fully
# offline with no credentials configured") and the JUDGMENT_MODEL usage-error
# unit case. On a developer machine direnv loads config/model.local.env and
# config/agent.local.env into the shell, so those variables ARE set and all four
# tests fail — while CI, which has none of them, stays green. The tests were
# asserting a precondition they never enforced, which made a red local suite
# normal and eroded its signal.
#
# Unset the judgment-layer variables (credentials, backend, cap, preflight,
# and local-backend run-state) so every test starts from the same hermetic
# baseline; tests that need one set it explicitly on the invocation under test.
#   - GITHUB_TOKEN / GH_TOKEN must stay. Unsetting them was observed to break
#     AC-030-01-06 ("required body sections present").
#   - OPENCODE_API_KEY and SPEC_*_MODEL must stay; check-model-env.sh verifies
#     their resolution and AC-030-07-03 asserts it exits 0.
# Tests that need a judgment variable set it explicitly on the invocation under
# test, which is unaffected by this.
unset JUDGMENT_API_KEY JUDGMENT_MODEL JUDGMENT_BACKEND JUDGMENT_API_URL \
      JUDGMENT_CAP_DIR JUDGMENT_DAILY_CAP JUDGMENT_MAX_STATE_BYTES \
      JUDGMENT_MIN_CONFIDENCE JUDGMENT_TIMEOUT_SECONDS JUDGMENT_BACKOFF_SECONDS \
      JUDGMENT_DEBUG JUDGMENT_REQUIRED JUDGMENT_PREFLIGHT_TTL_SECONDS \
      JUDGMENT_LOCAL_RUN_DIR JUDGMENT_LOCAL_PORT JUDGMENT_LOCAL_PROCESSES \
      JUDGMENT_LOCAL_UP_CMD JUDGMENT_LOCAL_HEALTH_PATH JUDGMENT_LOCAL_API_PATH \
      JUDGMENT_LOCAL_HEALTH_HOST JUDGMENT_LOCAL_TIMEOUT_SECONDS JUDGMENT_KEV_DIR

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
