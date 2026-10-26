#!/usr/bin/env bats
# check-loop-files.bats — characterization tests for scripts/check-loop-files.sh
#
# These tests are discriminating: replacing the script with `exit 0` fails the
# missing-artifact tests; deleting its clean lines fails the happy-path tests;
# and the scope tests pin both directions — child scope passes a child-shaped
# tree, while the default (standards) scope still rejects that same tree.
# No AC prefix — these cover script behavior beyond the archived AC-001..007
# scenario list (see scripts/tests/README.md).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

seed_loop_templates() { # seed_loop_templates DIR — the six files bootstrap --with-loop writes
  local dir="$1" f
  mkdir -p "$dir/templates"
  for f in LOOP.md STATE.md loop-run-log.md loop-budget.md loop-constraints.md gate.yaml; do
    cp "$REPO_ROOT/templates/$f" "$dir/templates/$f"
  done
}

@test "check-loop-files: clean repo exits 0 and prints its documented clean line" {
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Loop files check: every check passed"* ]]
}

@test "check-loop-files: empty tree exits 1 and names the missing artifact" {
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/LOOP_ENGINEERING.md is missing or empty"* ]]
}

@test "check-loop-files: child scope passes a child that has only the six loop templates" {
  seed_loop_templates "$TMPDIR_HELPER"
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" --scope child "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Loop files check (child scope): every check passed"* ]]
  [[ "$output" != *"AC-016-01"* ]]
  [[ "$output" != *"AC-016-03"* ]]
  [[ "$output" != *"AC-016-05"* ]]
}

@test "check-loop-files: child scope still fails when a loop template is missing" {
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" --scope child "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"templates/LOOP.md is missing or empty"* ]]
}

@test "check-loop-files: default standards scope still rejects a child-shaped tree" {
  seed_loop_templates "$TMPDIR_HELPER"
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/LOOP_ENGINEERING.md is missing or empty"* ]]
}

@test "check-loop-files: an unknown scope is a usage error, not a pass" {
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" --scope everything "$TMPDIR_HELPER"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown scope 'everything'"* ]]
}
