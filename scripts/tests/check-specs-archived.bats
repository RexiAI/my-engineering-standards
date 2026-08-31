#!/usr/bin/env bats
# check-specs-archived.bats — characterization tests for scripts/check-specs-archived.sh
# Contract: 0 when every finished spec (one with 30-report.md) has its
# docs/changes/NNN-slug.md archive; 1 naming the unarchived slug.
# Index-aware (git ls-files), so fixtures must be committed.

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  REPO="$TMPDIR_HELPER/r"
  mkdir -p "$REPO/specs/001-x" "$REPO/docs/changes"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@e.st
  git -C "$REPO" config user.name Test
}
teardown() { teardown_tmpdir; }

@test "check-specs-archived: no finished specs exits 0 with the all-archived line" {
  echo x > "$REPO/README.md"; git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All finished specs archived."* ]]
}

@test "check-specs-archived: a finished spec with no archive exits 1 and names the missing file" {
  echo r > "$REPO/specs/001-x/30-report.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"001-x is finished (has 30-report.md) but not archived"* ]]
  [[ "$output" == *"docs/changes/001-x.md"* ]]
  [[ "$output" == *"scripts/archive-spec.sh 001-x"* ]]
}

@test "check-specs-archived: a finished spec with its archive exits 0 and prints [OK]" {
  echo r > "$REPO/specs/001-x/30-report.md"
  echo a > "$REPO/docs/changes/001-x.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] 001-x archived -> docs/changes/001-x.md"* ]]
}
