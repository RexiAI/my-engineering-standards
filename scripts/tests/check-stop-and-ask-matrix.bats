#!/usr/bin/env bats
# check-stop-and-ask-matrix.bats — characterization tests for
# scripts/check-stop-and-ask-matrix.sh
#
# Deliberately fixture-driven, not run against the repo root: the script's
# AC-009-03-03 assertion fails on any *uncommitted* working-tree change to
# scripts/check-code-principles.sh, so a repo-root run is not deterministic
# mid-branch. Both fixtures below are hermetic.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-stop-and-ask-matrix: an empty tree cannot be checked and exits 2" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"docs/SPEC_PIPELINE.md"* ]]
}

@test "check-stop-and-ask-matrix: a matrix missing the design-gate row exits 1 with FAIL AC-009" {
  mkdir -p "$TMPDIR_HELPER/docs" "$TMPDIR_HELPER/agents" "$TMPDIR_HELPER/scripts"
  cat > "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md" <<'MD'
## Stop-and-Ask decision matrix

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report |
MD
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"AC-009-01-01 — '## Stop-and-Ask decision matrix' heading present"* ]]
  [[ "$output" == *"AC-009-01-02 — section must state the matrix is authoritative"* ]]
  [[ "$output" == *"matrix row missing or altered"* ]]
  [[ "$output" == *"Fix the code, never the threshold"* ]]
}

@test "check-stop-and-ask-matrix: the design-gate row wording is asserted verbatim" {
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$REPO_ROOT"
  [[ "$output" == *"Fix the code, never the threshold"* ]]
  [[ "$output" == *"AC-009-03-04"* ]]
}
