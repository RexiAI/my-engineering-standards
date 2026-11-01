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

# ── Unit coverage for the spec-042 line-cap rules ────────────────────────────
# Boundaries the acceptance scenarios (20-acceptance/AC-042-10-*.md) do not
# reach: the line under the cap, the scope of the grandfather map, which files
# the cap applies to, and the skills/ warning boundary. `make_skill`
# (test_helper) builds the exact-line-count fixture.

@test "check-skills: a language-specific guide one line under the 200 cap passes" {
  make_skill "$TMPDIR_HELPER/language-specific/foo/SKILL.md" foo 199
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[FAIL]"* ]]
}

@test "check-skills: the grandfather map is exact-path, not a wildcard" {
  make_skill "$TMPDIR_HELPER/language-specific/kotlin/SKILL.md" kotlin 201
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  local fail_line
  fail_line="$(printf '%s\n' "$output" | grep -F '[FAIL] language-specific/kotlin/SKILL.md')"
  [ -n "$fail_line" ]
  [[ "$fail_line" == *"200-line limit"* ]]
  [[ "$fail_line" != *"grandfathered"* ]]
}

@test "check-skills: a grandfathered guide one line under its ceiling passes" {
  make_skill "$TMPDIR_HELPER/language-specific/java/SKILL.md" java 281
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[FAIL]"* ]]
}

@test "check-skills: sibling files in a language-specific guide are not line-capped" {
  make_skill "$TMPDIR_HELPER/language-specific/foo/SKILL.md" foo 40
  {
    for ((i = 1; i <= 400; i++)); do printf 'detail line %d\n' "$i"; done
  } > "$TMPDIR_HELPER/language-specific/foo/PATTERNS.md"
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"PATTERNS.md"* ]]
}

@test "check-skills: a skills/ guide at exactly 500 lines is not warned" {
  make_skill "$TMPDIR_HELPER/skills/foo/SKILL.md" foo 500
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[WARN] skills/foo/SKILL.md"* ]]
  [[ "$output" == *"All SKILL.md files valid"* ]]
}
