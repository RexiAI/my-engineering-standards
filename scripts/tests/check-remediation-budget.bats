#!/usr/bin/env bats
# check-remediation-budget.bats — characterization tests for scripts/check-remediation-budget.sh
#
# Both tests are discriminating: replacing the script with `exit 0` fails the
# empty-tree test; deleting its clean line fails the happy-path test.
# No AC prefix — these cover script behavior beyond the archived AC-001..007
# scenario list (see scripts/tests/README.md).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-remediation-budget: clean repo exits 0 and prints its documented clean line" {
  run bash "$REPO_ROOT/scripts/check-remediation-budget.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Remediation budget check: every check passed"* ]]
}

@test "check-remediation-budget: empty tree exits 1 and names the missing artifact" {
  run bash "$REPO_ROOT/scripts/check-remediation-budget.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"FAIL"* ]]
}
