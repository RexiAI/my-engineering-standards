#!/usr/bin/env bats
# pr-automerge-notify.bats — acceptance tests for spec 045 Task 9
# (specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-09-*.md).
# Contract: the notification body mentions the CODEOWNERS individuals (or the
# repository owner as a fallback), states the outcome, and ends with the
# `<!-- pr-automerge: <outcome>:<head-sha> -->` idempotency marker.

load test_helper
bats_require_minimum_version 1.5.0

NOTIFY="$REPO_ROOT/scripts/pr-automerge-notify.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# owners "* @alice @bob" — write a CODEOWNERS file, sets $CO.
owners() { # <line> ... → $CO
  CO="$TMPDIR_HELPER/CODEOWNERS"
  printf '%s\n' "$@" > "$CO"
}

# ── AC-045-09: human notification ───────────────────────────────────────────

@test "AC-045-09-01 — armed notification mentions owners and states the gates" {
  owners '* @alice @bob'
  run bash "$NOTIFY" --outcome armed --size-tier auto --review-verdict pass \
    --exclusions none --codeowners-file "$CO" --repo-owner carol --head-sha abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"@alice"* ]]
  [[ "$output" == *"@bob"* ]]
  [[ "$output" == *"tier=auto"* ]]
  [[ "$output" == *"verdict=pass"* ]]
  [[ "$output" == *"pr-size"* ]]
  [[ "$output" == *"review-verdict"* ]]
  [[ "$output" == *"CI"* ]]
  [[ "$output" == *"mutation"* ]]
}

@test "AC-045-09-02 — would-merge notification names report-only mode" {
  owners '* @alice'
  run bash "$NOTIFY" --outcome would-merge --size-tier auto --review-verdict pass \
    --codeowners-file "$CO" --repo-owner carol --head-sha abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"would have auto-merged"* ]]
  [[ "$output" == *"report"* ]]
  [[ "$output" == *"tier=auto"* ]]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "AC-045-09-03 — blocked-by-exclusion notification asks for a human" {
  run bash "$NOTIFY" --outcome blocked-exclusion \
    --exclusions gate_surface:.github/workflows/ci.yml
  [ "$status" -eq 0 ]
  [[ "$output" == *"gate_surface"* ]]
  [[ "$output" == *".github/workflows/ci.yml"* ]]
  [[ "$output" == *"human"* ]]
  [[ "$output" == *"review"* ]]
  [[ "$output" == *"merge"* ]]
}

@test "AC-045-09-04 — no CODEOWNERS file falls back to the repository owner" {
  run bash "$NOTIFY" --outcome armed --codeowners-file none --repo-owner carol \
    --head-sha abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"@carol"* ]]
  [ "$(grep -o '@[A-Za-z0-9_-]*' <<< "$output" | sort -u | wc -l)" -eq 1 ]
}

@test "AC-045-09-05 — every body carries the idempotency marker" {
  local outcome
  for outcome in armed would-merge blocked-exclusion; do
    run bash "$NOTIFY" --outcome "$outcome" --head-sha abc123
    [ "$status" -eq 0 ]
    [ "$(tail -n1 <<< "$output")" = "<!-- pr-automerge: $outcome:abc123 -->" ]
  done
}

@test "AC-045-09-06 — the workflow suppresses duplicate notifications" {
  local wf="$REPO_ROOT/.github/workflows/ci-pr-auto-merge.yml"
  run grep -F 'pr-automerge: ' "$wf"
  [ "$status" -eq 0 ]
  run grep -F 'gh pr view' "$wf"
  [ "$status" -eq 0 ]
  run grep -F -- '--json comments' "$wf"
  [ "$status" -eq 0 ]
}

# ── Unit: usage and owner handling ──────────────────────────────────────────

@test "notification: a missing --outcome is a usage error" {
  run bash "$NOTIFY" --head-sha abc123
  [ "$status" -eq 2 ]
}

@test "notification: an unknown outcome is a usage error" {
  run bash "$NOTIFY" --outcome merged --head-sha abc123
  [ "$status" -eq 2 ]
}

@test "notification: team handles are neither invented nor expanded" {
  owners '* @acme/leads'
  run bash "$NOTIFY" --outcome armed --codeowners-file "$CO" --repo-owner carol \
    --head-sha abc123
  [ "$status" -eq 0 ]
  [[ "$output" != *"@acme"* ]]
  [[ "$output" == *"@carol"* ]]
}

@test "notification: every distinct individual handle is mentioned once" {
  owners '* @alice @bob' 'docs/ @alice @dana'
  run bash "$NOTIFY" --outcome armed --codeowners-file "$CO" --repo-owner carol \
    --head-sha abc123
  [ "$status" -eq 0 ]
  [ "$(grep -o '@alice' <<< "$output" | wc -l)" -eq 1 ]
  [[ "$output" == *"@dana"* ]]
}

@test "notification: an absent CODEOWNERS path falls back to the owner" {
  run bash "$NOTIFY" --outcome armed --codeowners-file "$TMPDIR_HELPER/none" \
    --repo-owner carol --head-sha abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"@carol"* ]]
}

@test "notification: the body carries no secret-shaped value" {
  run bash "$NOTIFY" --outcome armed --repo-owner carol --head-sha abc123
  [ "$status" -eq 0 ]
  [[ "$output" != *"API_KEY"* ]]
  [[ "$output" != *"SECRET"* ]]
}
