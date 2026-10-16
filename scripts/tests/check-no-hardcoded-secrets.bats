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

# The two tests below pin the gitignore-awareness added for the defect where
# config/agent.local.env — gitignored, and meant to hold real credentials per
# AGENTS.md §Per-machine agent environment — was flagged on every correctly
# configured developer machine, making AC-001-05 and agent-env.selftest
# permanently red locally while CI stayed green.
#
# The second test is the important one: skipping ignored paths must NOT become a
# way to smuggle a secret in. `git check-ignore` consults the index, so a
# force-added (tracked) path is never reported ignored and is still scanned.

@test "check-no-hardcoded-secrets: a gitignored, untracked credentials file is not a violation" {
  mkdir -p "$TMPDIR_HELPER/config"
  git -C "$TMPDIR_HELPER" init -q .
  printf 'config/agent.local.env\n' > "$TMPDIR_HELPER/.gitignore"
  printf 'API_TOKEN=%s\n' 'realliteralvalue123' > "$TMPDIR_HELPER/config/agent.local.env"
  # Precondition: git really does ignore it, otherwise this test proves nothing.
  run git -C "$TMPDIR_HELPER" check-ignore -q config/agent.local.env
  [ "$status" -eq 0 ]
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
}

@test "check-no-hardcoded-secrets: a gitignored file that is force-added IS still caught (no bypass)" {
  mkdir -p "$TMPDIR_HELPER/config"
  git -C "$TMPDIR_HELPER" init -q .
  printf 'config/agent.local.env\n' > "$TMPDIR_HELPER/.gitignore"
  printf 'API_TOKEN=%s\n' 'realliteralvalue123' > "$TMPDIR_HELPER/config/agent.local.env"
  git -C "$TMPDIR_HELPER" add -f config/agent.local.env
  # Precondition: the path is ignored by pattern yet tracked in the index.
  run git -C "$TMPDIR_HELPER" ls-files --error-unmatch config/agent.local.env
  [ "$status" -eq 0 ]
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"config/agent.local.env:1"* ]]
  [[ "$output" == *"secret-style assignment"* ]]
}

@test "check-no-hardcoded-secrets: a non-git scratch root still scans every file" {
  # Guards the graceful-degradation path: the bats scratch roots and --self-test
  # are not git work trees, so nothing may be filtered there.
  mkdir -p "$TMPDIR_HELPER/scripts"
  printf 'API_TOKEN=%s\n' 'realliteralvalue123' > "$TMPDIR_HELPER/scripts/leak.sh"
  run git -C "$TMPDIR_HELPER" rev-parse --is-inside-work-tree
  [ "$status" -ne 0 ]
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/leak.sh:1"* ]]
}

# Issue #72 finding 2: the scanner echoed the matched credential value verbatim,
# leaking it into terminal scrollback, agent transcripts, CI logs and PR
# annotations at the moment of detection. A finding must stay actionable — file,
# line, variable name, value length — without publishing the secret.
@test "check-no-hardcoded-secrets: the matched secret VALUE is never printed" {
  mkdir -p "$TMPDIR_HELPER/config"
  printf 'API_TOKEN=%s\n' 'SuperSecretValueThatMustNeverAppear' \
    > "$TMPDIR_HELPER/config/leak.env"
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  # Still locatable and triageable...
  [[ "$output" == *"config/leak.env:1"* ]]
  [[ "$output" == *"secret-style assignment"* ]]
  [[ "$output" == *"API_TOKEN="* ]]
  [[ "$output" == *"redacted"* ]]
  # ...but the value itself must not appear anywhere in the output.
  [[ "$output" != *"SuperSecretValueThatMustNeverAppear"* ]]
}

@test "check-no-hardcoded-secrets: a literal token prefix is reported without echoing the line" {
  # Class 1 never printed the matched text, but pin it so a future refactor
  # cannot reintroduce the leak through this path either.
  mkdir -p "$TMPDIR_HELPER/scripts"
  printf 'X="%s%s"\n' 'ghp' '_SuperSecretTokenBodyThatMustNeverAppear' \
    > "$TMPDIR_HELPER/scripts/prefix.sh"
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"scripts/prefix.sh:1"* ]]
  [[ "$output" == *"literal token prefix"* ]]
  [[ "$output" != *"SuperSecretTokenBodyThatMustNeverAppear"* ]]
}
