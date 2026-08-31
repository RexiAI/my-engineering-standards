#!/usr/bin/env bats
# check-post-pr-ci-loop.bats — characterization tests for scripts/check-post-pr-ci-loop.sh
# Contract: 0 when every assertion holds; 1 with a `FAIL <scenario-id>` line per
# failed assertion; 2 when the source tree cannot be read at all.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-post-pr-ci-loop: real repo satisfies every assertion and exits 0" {
  run bash "$REPO_ROOT/scripts/check-post-pr-ci-loop.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Post-PR CI loop check: all assertions hold."* ]]
}

@test "check-post-pr-ci-loop: an empty tree cannot be checked and exits 2" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-post-pr-ci-loop.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"docs/SPEC_PIPELINE.md"* ]]
}

@test "check-post-pr-ci-loop: a tree with a gutted SPEC_PIPELINE.md exits non-zero with FAIL lines" {
  mkdir -p "$TMPDIR_HELPER/docs"
  printf '# Spec pipeline\n\nnothing here\n' > "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md"
  run bash "$REPO_ROOT/scripts/check-post-pr-ci-loop.sh" "$TMPDIR_HELPER"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL"* ]]
}
