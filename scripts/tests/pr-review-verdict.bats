#!/usr/bin/env bats
# pr-review-verdict.bats — acceptance tests for spec 045 Task 5
# (specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-05-*.md).
# Contract: the parser reads `gh pr view --json comments`, selects the latest
# comment carrying the exact head marker, and fails closed on anything except a
# single case-sensitive `pass` / `findings` line.

load test_helper
bats_require_minimum_version 1.5.0

PARSER="$REPO_ROOT/scripts/pr-review-verdict.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# comments_json <body1> <body2> ... — a `gh pr view --json comments` document
# whose comment bodies are JSON-escaped (newlines become \n).
comments_json() { # <body> ... → JSON on stdout
  local body first=1
  printf '{"comments":['
  for body in "$@"; do
    [ "$first" -eq 1 ] || printf ','
    first=0
    printf '{"body":"%s","id":"x"}' "${body//$'\n'/\\n}"
  done
  printf ']}\n'
}

# verdicts <body> ... — write the comments file and run the parser for abc123.
verdicts() { # <body> ... → runs the parser
  local f="$TMPDIR_HELPER/comments.json"
  comments_json "$@" > "$f"
  run bash "$PARSER" --head-sha abc123 --comments-file "$f"
}

# ── AC-045-05: verdict parser and fail-closed behaviour ─────────────────────

@test "AC-045-05-01 — a pass for the head is accepted" {
  verdicts "$(printf 'Looks fine.\nReviewed-SHA: abc123\nReview-Verdict: pass')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "AC-045-05-02 — findings fail the check" {
  verdicts "$(printf 'Two findings.\nReviewed-SHA: abc123\nReview-Verdict: findings')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=findings"* ]]
}

@test "AC-045-05-03 — no comment for the head is missing" {
  verdicts "$(printf 'Reviewed-SHA: def456\nReview-Verdict: pass')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=missing"* ]]
}

@test "AC-045-05-04 — a missing verdict line is malformed" {
  verdicts "$(printf 'Reviewed-SHA: abc123')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=malformed"* ]]
}

@test "AC-045-05-05 — verdict values are case-sensitive" {
  verdicts "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: PASS')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=malformed"* ]]
}

@test "AC-045-05-06 — multiple verdict lines are malformed" {
  verdicts "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: pass\nReview-Verdict: findings')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=malformed"* ]]
}

@test "AC-045-05-07 — the latest comment wins" {
  verdicts \
    "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: findings')" \
    "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: pass')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "AC-045-05-08 — a newer findings comment supersedes an older pass" {
  verdicts \
    "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: pass')" \
    "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: findings')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=findings"* ]]
}

# ── Unit: usage errors, empty input, stdin, whitespace ─────────────────────

@test "verdict parser: an empty comments document is missing, never a pass" {
  local f="$TMPDIR_HELPER/empty.json"
  : > "$f"
  run bash "$PARSER" --head-sha abc123 --comments-file "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=missing"* ]]
}

@test "verdict parser: a missing --head-sha is a usage error" {
  local f="$TMPDIR_HELPER/c.json"
  comments_json "Reviewed-SHA: abc123" > "$f"
  run bash "$PARSER" --comments-file "$f"
  [ "$status" -eq 2 ]
  [[ "$output" != *"verdict="* ]]
}

@test "verdict parser: an unknown flag is a usage error" {
  local f="$TMPDIR_HELPER/c.json"
  comments_json "Reviewed-SHA: abc123" > "$f"
  run bash "$PARSER" --head-sha abc123 --comments-file "$f" --nope
  [ "$status" -eq 2 ]
  [[ "$output" != *"verdict="* ]]
}

@test "verdict parser: comments-file - reads stdin" {
  local f="$TMPDIR_HELPER/c.json"
  comments_json "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: pass')" > "$f"
  run bash -c "cat '$f' | bash '$PARSER' --head-sha abc123 --comments-file -"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "verdict parser: trailing whitespace after the value is trimmed" {
  verdicts "$(printf 'Reviewed-SHA: abc123\nReview-Verdict: pass   ')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"verdict=pass"* ]]
}

@test "verdict parser: a marker for another head never authorizes this head" {
  verdicts "$(printf 'Reviewed-SHA: abc1234\nReview-Verdict: pass')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=missing"* ]]
}

@test "verdict parser: a comment without the marker is ignored" {
  verdicts "$(printf 'No marker here.\nReview-Verdict: pass')"
  [ "$status" -eq 1 ]
  [[ "$output" == *"verdict=missing"* ]]
}
