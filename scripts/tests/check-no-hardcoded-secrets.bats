#!/usr/bin/env bats
# check-no-hardcoded-secrets.bats — characterization tests for
# scripts/check-no-hardcoded-secrets.sh
#
# Token literals are assembled at runtime by concatenation so this file itself
# stays clean under the very check it exercises (same trick the script uses).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-no-hardcoded-secrets: clean scratch root exits 0 with PASS line" {
  mkdir -p "$TMPDIR_HELPER/scripts"
  printf 'echo hello\n' > "$TMPDIR_HELPER/scripts/ok.sh"
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"no hardcoded credential values"* ]]
}

@test "check-no-hardcoded-secrets: literal GitHub token prefix exits 1 and prints file:line" {
  mkdir -p "$TMPDIR_HELPER/scripts"
  printf 'X="%s%s"\n' 'ghp' '_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' > "$TMPDIR_HELPER/scripts/leak.sh"
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/leak.sh:1"* ]]
  [[ "$output" == *"literal token prefix"* ]]
}

@test "check-no-hardcoded-secrets: secret-style assignment with a literal value exits 1" {
  mkdir -p "$TMPDIR_HELPER/docs"
  printf 'API_TOKEN=abc123literal\n' > "$TMPDIR_HELPER/docs/notes.md"
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"secret-style assignment"* ]]
}

@test "check-no-hardcoded-secrets: placeholder and \${VAR} values are not violations" {
  mkdir -p "$TMPDIR_HELPER/scripts"
  {
    printf 'API_TOKEN=<your-token-here>\n'
    printf 'OTHER_SECRET=${FROM_ENV}\n'
    printf 'THIRD_KEY=PLACEHOLDER\n'
  } > "$TMPDIR_HELPER/scripts/tpl.sh"
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}
