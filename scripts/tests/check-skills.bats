#!/usr/bin/env bats
# check-skills.bats — characterization tests for scripts/check-skills.sh
# Contract: 0 when every SKILL.md is valid, 1 on a hard validation error.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-skills: name/directory mismatch exits 1 and names both" {
  mkdir -p "$TMPDIR_HELPER/skills/foo"
  printf -- '---\nname: wrong-name\ndescription: x\n---\nbody\n' > "$TMPDIR_HELPER/skills/foo/SKILL.md"
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not match directory name 'foo'"* ]]
  [[ "$output" == *"error(s) found in SKILL.md files"* ]]
}

@test "check-skills: matching name/directory exits 0 with the all-valid line" {
  mkdir -p "$TMPDIR_HELPER/skills/foo"
  printf -- '---\nname: foo\ndescription: A valid description of the foo skill.\n---\n\n# Foo\n\nbody\n' > "$TMPDIR_HELPER/skills/foo/SKILL.md"
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All SKILL.md files valid"* ]]
}

@test "check-skills: the real repo passes its own skill validation" {
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All SKILL.md files valid"* ]]
}
