#!/usr/bin/env bats
# ac-038-line-cap.bats — acceptance tests for spec 038 Task 1
# (specs/038-trim-agent-prompts/20-acceptance/AC-038-01-line-cap-script.md).

load test_helper
bats_require_minimum_version 1.5.0

CHECK="$REPO_ROOT/scripts/check-agent-line-cap.sh"

setup() {
  setup_tmpdir
  mkdir -p "$TMPDIR_HELPER/agents"
}
teardown() { teardown_tmpdir; }

# fixture_agent <name> <lines> — write an agents/<name> file of exactly <lines>
# non-blank lines into the scratch tree.
fixture_agent() {
  local name="$1" lines="$2"
  seq 1 "$lines" | sed 's/^/agent line /' > "$TMPDIR_HELPER/agents/$name"
}

@test "AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0" {
  run bash "$CHECK" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"line cap"* ]]
  [[ "$output" != *"[OVER]"* ]]
}

@test "AC-038-01-02 — a fixture agent at exactly 120 lines passes" {
  fixture_agent spec-x.md 120
  run bash "$CHECK" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"spec-x.md"* ]]
}

@test "AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count" {
  fixture_agent spec-x.md 121
  run bash "$CHECK" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"spec-x.md"* ]]
  [[ "$output" == *"121"* ]]
}

@test "AC-038-01-04 — a 500-line non-spec agent is ignored" {
  fixture_agent other.md 500
  run bash "$CHECK" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" != *"other.md"* ]]
}

@test "unit — the cap is a single named constant of 120" {
  local assignments
  assignments="$(grep -cE '^MAX_LINES=[0-9]+$' "$CHECK")"
  [ "$assignments" -eq 1 ]
  grep -qE '^MAX_LINES=120$' "$CHECK"
}

@test "unit — the scan is a glob, so an unlisted spec-*.md over the cap is caught" {
  fixture_agent spec-not-in-any-list.md 130
  run bash "$CHECK" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"spec-not-in-any-list.md"* ]]
  [[ "$output" == *"130"* ]]
}

@test "unit — a missing agents/ directory is a tooling failure, not a silent pass" {
  local empty="$TMPDIR_HELPER/no-agents"
  mkdir -p "$empty"
  run bash "$CHECK" "$empty"
  [ "$status" -eq 2 ]
  [[ "$output" == *"agents"* ]]
}

@test "unit — usage rejects more than one argument" {
  run bash "$CHECK" "$TMPDIR_HELPER" extra
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage"* ]]
}
