#!/usr/bin/env bats
# autopilot-enforcement.bats — acceptance test for spec 035 Task 12
# (specs/035-autopilot-mode/20-acceptance/AC-035-bats.md).
# AC-035-36 is the repo-level static assertion: the real 9 pipeline agents plus
# the orchestrator carry no unconditional question path, enforced by the same
# gate the pipeline runs.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)" {
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AC-035-32"* ]]
  [[ "$output" == *"AC-035-30"* ]]
  [[ "$output" == *"AC-035-31"* ]]
  [[ "$output" != *$'\033[0;31mFAIL'* ]]
}
