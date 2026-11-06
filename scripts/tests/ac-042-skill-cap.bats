#!/usr/bin/env bats
# Spec 042 — the 200-line cap for language-specific/*/SKILL.md (AC-042-10).
#
# The cap is asserted through scripts/check-skills.sh against temporary fixture
# roots, so the test proves the gate's behaviour rather than re-implementing it.

load test_helper

bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-042-10-01: this repo still passes the gate" {
  run bash "$REPO_ROOT/scripts/check-skills.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[FAIL]"* ]]
  [[ "$output" == *"All SKILL.md files valid"* ]]
}

@test "AC-042-10-02: a new guide at exactly 200 lines passes" {
  make_skill "$TMPDIR_HELPER/language-specific/foo/SKILL.md" foo 200
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[FAIL] language-specific/foo/SKILL.md"* ]]
  [[ "$output" == *"All SKILL.md files valid"* ]]
}

@test "AC-042-10-03: a new guide at 201 lines fails with an actionable message" {
  make_skill "$TMPDIR_HELPER/language-specific/foo/SKILL.md" foo 201
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  local fail_line
  fail_line="$(printf '%s\n' "$output" | grep -F '[FAIL] language-specific/foo/SKILL.md')"
  [ -n "$fail_line" ]
  [[ "$fail_line" == *200* ]]
  [[ "$fail_line" == *201* ]]
  [[ "$fail_line" == *PATTERNS.md* || "$fail_line" == *TESTING.md* ]]
  [[ "$output" == *"error(s) found in SKILL.md files"* ]]
}

@test "AC-042-10-04: a grandfathered guide at its ceiling passes" {
  make_skill "$TMPDIR_HELPER/language-specific/java/SKILL.md" java 282
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"[FAIL] language-specific/java/SKILL.md"* ]]
}

@test "AC-042-10-05: a grandfathered guide that grows fails" {
  local guide ceiling over
  for guide in java:282 python:271 rust:241 go:223; do
    ceiling="${guide##*:}"
    over=$((ceiling + 1))
    rm -rf "${TMPDIR_HELPER:?}/language-specific"
    make_skill "$TMPDIR_HELPER/language-specific/${guide%%:*}/SKILL.md" "${guide%%:*}" "$over"
    run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
    [ "$status" -eq 1 ]
    [[ "$output" == *"[FAIL] language-specific/${guide%%:*}/SKILL.md"* ]]
    [[ "$output" == *"$over"* ]]
  done
}

@test "AC-042-10-06: skills/ keeps the 500-line warning" {
  make_skill "$TMPDIR_HELPER/skills/foo/SKILL.md" foo 501
  run bash "$REPO_ROOT/scripts/check-skills.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  local warn_line
  warn_line="$(printf '%s\n' "$output" | grep -F '[WARN] skills/foo/SKILL.md')"
  [ -n "$warn_line" ]
  [[ "$warn_line" == *500* ]]
  [[ "$output" == *"All SKILL.md files valid"* ]]
}

@test "AC-042-10-07: the documented checklist matches the script" {
  local doc="${REPO_ROOT}/docs/AGENTS_AND_SKILLS.md" checklist enforcement
  checklist="$(md_section "$doc" '### Skills Checklist (`skills/*/SKILL.md` & `language-specific/*/SKILL.md`)' 3 3)"
  [ -n "$checklist" ]
  [[ "$checklist" == *'200'* ]]
  [[ "$checklist" == *'language-specific/*/SKILL.md'* ]]
  [[ "$checklist" == *'java'* ]]
  [[ "$checklist" == *'python'* ]]
  [[ "$checklist" == *'rust'* ]]
  [[ "$checklist" == *'go'* ]]
  [[ "$checklist" == *'500'* ]]
  [[ "$checklist" == *'skills/*/SKILL.md'* ]]

  enforcement="$(md_section "$doc" '## Mechanical Enforcement' 2 2)"
  [ -n "$enforcement" ]
  [[ "$enforcement" != *'line-count warnings for all skills'* ]]
  [[ "$enforcement" == *'200-line cap for `language-specific/*/SKILL.md`'* ]]

  # The split of the grandfathered guides is named as a separate spec.
  local split
  split="$(grep -n 'grandfathered' "$doc" | grep -i 'separate\|follow-up\|split')"
  [ -n "$split" ]
}
