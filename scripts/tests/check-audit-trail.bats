#!/usr/bin/env bats
# check-audit-trail.bats — characterization tests for scripts/check-audit-trail.sh
# Contract: 0 when the spec folder + verifier evidence are complete (or absent);
# 1 on a missing/empty artifact or incomplete evidence; 2 on a usage error.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-audit-trail: no slug exits 2 and prints the usage block" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-audit-trail.sh"
  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"Usage:"* ]]
  [[ "$output$stderr" == *"check-audit-trail.sh <slug>"* ]]
}

@test "check-audit-trail: an absent spec folder is 'nothing to check' and exits 0" {
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 999-absent "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to check"* ]]
}

@test "check-audit-trail: a spec folder missing 25-verification.md exits 1" {
  mkdir -p "$TMPDIR_HELPER/001-x"
  printf '# tasks\n' > "$TMPDIR_HELPER/001-x/10-tasks.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"25-verification.md"* ]]
}

@test "check-audit-trail: --selftest exercises every negative case and exits 0" {
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" --selftest
  [ "$status" -eq 0 ]
  [[ "$output" == *"Selftest: every audit-trail scenario exercised and passing"* ]]
}
