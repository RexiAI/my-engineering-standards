#!/usr/bin/env bats
# Unit tests for the pr-review provider-failure classifier. A review is
# advisory; a provider-side failure must skip with a warning, never red a
# required check (AC-024-02).

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/scripts/pr-review-skip-reason.sh"
}

@test "classifies an invalid credential as auth" {
  run bash "$SCRIPT" <<< 'error.error="AI_APICallError: Upstream request failed: Invalid credential"'
  [ "$status" -eq 0 ]
  [ "$output" = "auth" ]
}

@test "classifies rejection of the configured model as auth" {
  run bash "$SCRIPT" <<< 'Error: Forbidden: Access to model denied. Please make sure you are eligible for using the model.'
  [ "$status" -eq 0 ]
  [ "$output" = "auth" ]
}

@test "classifies 401 and 403 statuses as auth" {
  run bash "$SCRIPT" <<< 'provider returned 401 Unauthorized'
  [ "$output" = "auth" ]
  run bash "$SCRIPT" <<< 'provider returned 403'
  [ "$output" = "auth" ]
}

@test "classifies quota, billing and rate limits as billing" {
  run bash "$SCRIPT" <<< 'AI_APICallError: spending limit reached'
  [ "$output" = "billing" ]
  run bash "$SCRIPT" <<< '429 Too Many Requests'
  [ "$output" = "billing" ]
  run bash "$SCRIPT" <<< 'Insufficient Balance'
  [ "$output" = "billing" ]
}

@test "classifies an unknown model id as auth" {
  run bash "$SCRIPT" <<< 'stream error: model not found: big-pickle'
  [ "$output" = "auth" ]
}

@test "a genuine agent failure is not skipped" {
  run bash "$SCRIPT" <<< 'Error: gh pr review failed: not a git repository'
  [ "$status" -eq 0 ]
  [ "$output" = "none" ]
}

@test "ANSI colour codes do not defeat the match" {
  printf '\033[91mError:\033[0m Invalid credential\n' | bash "$SCRIPT" | grep -qx auth
}

@test "the workflow delegates to this classifier instead of inlining a regex" {
  run grep -F 'scripts/pr-review-skip-reason.sh' "$REPO_ROOT/.github/workflows/ci-pr-review.yml"
  [ "$status" -eq 0 ]
  run grep -c 'invalid credential' "$REPO_ROOT/.github/workflows/ci-pr-review.yml"
  [ "$output" = "0" ]
}
