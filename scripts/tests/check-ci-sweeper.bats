#!/usr/bin/env bats
# check-ci-sweeper.bats — characterization tests for scripts/check-ci-sweeper.sh
#
# Both tests are discriminating: replacing the script with `exit 0` fails the
# empty-tree test; deleting its clean line fails the happy-path test.
# No AC prefix — these cover script behavior beyond the archived AC-001..007
# scenario list (see scripts/tests/README.md).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-ci-sweeper: clean repo exits 0 and prints its documented clean line" {
  run bash "$REPO_ROOT/scripts/check-ci-sweeper.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CI sweeper check: every check passed"* ]]
}

@test "check-ci-sweeper: empty tree exits 1 and names the missing artifact" {
  run bash "$REPO_ROOT/scripts/check-ci-sweeper.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"AC-017-01-01"* ]]
}
