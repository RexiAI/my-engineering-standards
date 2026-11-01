#!/usr/bin/env bats
# ac-037-read-cost.bats — acceptance tests for spec 037 Task 5
# (specs/037-split-spec-pipeline-doc/20-acceptance/AC-037-05-read-cost.md).
# scripts/measure-stage-read-cost.sh proves each stage reads at most half of the
# unsplit document (baseline 50836 bytes at the 036-merged base commit).

load test_helper
bats_require_minimum_version 1.5.0

MEASURE="$REPO_ROOT/scripts/measure-stage-read-cost.sh"
BASELINE=50836
HALF=$((BASELINE / 2))   # 25418

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# fixture_tree <index-bytes> <refactorer-bytes> — a tree the measure script can
# price: every stage file exists, only refactorer.md carries real weight.
fixture_tree() {
  local index_bytes="$1" refactorer_bytes="$2" stage
  mkdir -p "$TMPDIR_HELPER/docs/spec-pipeline"
  head -c "$index_bytes" /dev/zero | tr '\0' 'x' > "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md"
  for stage in specifier ux coder refactorer verifier mutation-runner pr-opener deployer; do
    printf 'x\n' > "$TMPDIR_HELPER/docs/spec-pipeline/$stage.md"
  done
  head -c "$refactorer_bytes" /dev/zero | tr '\0' 'x' \
    > "$TMPDIR_HELPER/docs/spec-pipeline/refactorer.md"
  echo "$TMPDIR_HELPER"
}

@test "AC-037-05-01: every stage reads at most 50% and the script exits 0" {
  run bash "$MEASURE" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Every stage reads at most 50% of the unsplit document."* ]]
  # one ratio line per stage agent, each <= 0.500
  local stage found=0
  for stage in specifier ux coder refactorer verifier mutation-runner pr-opener deployer; do
    grep -qE "^$stage +[0-9]+ +0\.[0-4][0-9]{2}  ok$" <<< "$output" \
      || grep -qE "^$stage +[0-9]+ +0\.500  ok$" <<< "$output" \
      || { echo "stage $stage missing or over budget: $(grep -E "^$stage " <<< "$output")" >&2; return 1; }
    found=$((found + 1))
  done
  [ "$found" -eq 8 ]
}

@test "AC-037-05-02: a stage over the budget exits 1 and is named" {
  local tree; tree="$(fixture_tree 20000 $((HALF - 20000 + 1)))"
  run bash "$MEASURE" "$tree"
  [ "$status" -eq 1 ]
  [[ "$output" == *"OVER refactorer"* ]]
}

@test "AC-037-05-03: a stage at exactly 50% of the baseline passes" {
  local tree; tree="$(fixture_tree 20000 $((HALF - 20000)))"
  run bash "$MEASURE" "$tree"
  [ "$status" -eq 0 ]
  [[ "$output" == *"refactorer"*"0.500  ok"* ]]
}

@test "unit: a shared file named in a Must read block is counted" {
  local tree; tree="$(fixture_tree 20000 0)"
  # give refactorer.md a Must-read block pointing at a 6000-byte shared file:
  # 20007 (others) is under budget, but the shared file pushes it over.
  printf 'Must read: `docs/spec-pipeline/shared.md`\n\n' \
    > "$tree/docs/spec-pipeline/refactorer.md"
  head -c 6000 /dev/zero | tr '\0' 'y' > "$tree/docs/spec-pipeline/shared.md"
  run bash "$MEASURE" "$tree"
  [ "$status" -eq 1 ]
  [[ "$output" == *"OVER refactorer"* ]]
}

@test "unit: a missing index is a tooling failure, not a silent pass" {
  mkdir -p "$TMPDIR_HELPER/docs/spec-pipeline"
  run bash "$MEASURE" "$TMPDIR_HELPER"
  [ "$status" -eq 2 ]
  [[ "$output" == *"missing"* ]]
}
