#!/usr/bin/env bats
# check-bats-assertions.bats — characterization tests for
# scripts/check-bats-assertions.sh (the vacuous-assertion guard).
#
# Fixture bodies are written with printf so this file itself never contains a
# literal vacuous shape — it is scanned by the very gate it exercises.

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  T="$TMPDIR_HELPER/tests"
  mkdir -p "$T"
  TRUE_KW=true
}
teardown() { teardown_tmpdir; }

@test "check-bats-assertions: a directory of real assertions exits 0 with a PASS line" {
  printf '@test "real" {\n  run bash -c "exit 3"\n  [ "$status" -eq 3 ]\n}\n' > "$T/ok.bats"
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$T"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"1 bats file(s), no vacuous assertions"* ]]
}

@test "check-bats-assertions: a bare 'true' used as an assertion exits 1 and names file:line" {
  printf '@test "fake" {\n  run bash -c "exit 1"\n  %s\n}\n' "$TRUE_KW" > "$T/bare.bats"
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"bare.bats:3"* ]]
  [[ "$output" == *"bare 'true' used as an assertion"* ]]
}

@test "check-bats-assertions: 'true || [ ... ]' short-circuit exits 1 and is named as such" {
  printf '@test "fake" {\n  run bash -c "exit 1"\n  %s || [ "$status" -eq 128 ]\n}\n' "$TRUE_KW" > "$T/short.bats"
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"short.bats:3"* ]]
  [[ "$output" == *"short-circuits, the check never runs"* ]]
}

@test "check-bats-assertions: 'run ... || true' with no status assertion exits 1" {
  printf '@test "swallowed" {\n  run bash x.sh || %s\n}\n' "$TRUE_KW" > "$T/swallow.bats"
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$T"
  [ "$status" -eq 1 ]
  [[ "$output" == *"swallow.bats:2"* ]]
  [[ "$output" == *"no \$status/\$output assertion"* ]]
}

@test "check-bats-assertions: 'run ... || true' followed by a status assertion is allowed" {
  printf '@test "checked" {\n  run bash x.sh || %s\n  [ "$status" -eq 1 ]\n}\n' "$TRUE_KW" > "$T/checked.bats"
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$T"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "check-bats-assertions: the word 'true' inside a comment is not a violation" {
  printf '@test "commented" {\n  # this is %s only in prose\n  run bash -c "exit 0"\n  [ "$status" -eq 0 ]\n}\n' "$TRUE_KW" > "$T/comment.bats"
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$T"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "check-bats-assertions: a missing tests directory is a tooling failure (exit 2)" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-bats-assertions.sh" "$TMPDIR_HELPER/no-such-dir"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"tests directory not found"* ]]
}

@test "check-bats-assertions: the repo's own bats suite is free of vacuous assertions" {
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no vacuous assertions"* ]]
}
