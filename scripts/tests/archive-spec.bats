#!/usr/bin/env bats
# archive-spec.bats — characterization tests for scripts/archive-spec.sh
#
# Only the non-mutating contract is exercised: the script's success path moves a
# spec folder and is therefore covered by the pipeline itself, not here (see
# scripts/tests/README.md). Usage and not-found paths are fully hermetic.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "archive-spec: no slug exits 1 and prints the usage line" {
  run bash "$REPO_ROOT/scripts/archive-spec.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: archive-spec.sh NNN-slug"* ]]
}

@test "archive-spec: two arguments is still a usage error" {
  run bash "$REPO_ROOT/scripts/archive-spec.sh" 001-a 002-b
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: archive-spec.sh NNN-slug"* ]]
}

@test "archive-spec: a nonexistent spec exits 1 and names the missing folder" {
  run bash "$REPO_ROOT/scripts/archive-spec.sh" 999-does-not-exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"specs/999-does-not-exist does not exist"* ]]
}
