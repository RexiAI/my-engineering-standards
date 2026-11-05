#!/usr/bin/env bats
# ac-038-ci-wiring.bats — acceptance tests for spec 038 Task 2
# (specs/038-trim-agent-prompts/20-acceptance/AC-038-02-ci-wiring.md).

load test_helper
bats_require_minimum_version 1.5.0

WORKFLOW="$REPO_ROOT/.github/workflows/self-ci.yml"
AGENTS_MD="$REPO_ROOT/AGENTS.md"
CHECK_CMD='./scripts/check-agent-line-cap.sh'

@test "AC-038-02-01 — self-ci runs the agent line-cap check" {
  [ -f "$WORKFLOW" ]
  run grep -F "$CHECK_CMD" "$WORKFLOW"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$CHECK_CMD"* ]]
}

@test "AC-038-02-02 — AGENTS.md documents the line-cap check" {
  [ -f "$AGENTS_MD" ]
  run grep -F 'check-agent-line-cap.sh' "$AGENTS_MD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"check-agent-line-cap.sh"* ]]
}

@test "unit — the wiring is a run step, not an allow-failure step" {
  local line
  line="$(grep -nF "$CHECK_CMD" "$WORKFLOW" | head -1 | cut -d: -f1)"
  [ -n "$line" ]
  # the step block is the run: | block the command sits in; a nearby
  # continue-on-error would make the gate advisory.
  run bash -c "sed -n '$((line > 4 ? line - 4 : 1)),${line}p' '$WORKFLOW'"
  [[ "$output" != *"continue-on-error"* ]]
}

@test "unit — AGENTS.md names the check next to the other structural gates" {
  # check-skills.sh and check-orchestration.sh are the structural gate bullets;
  # the line-cap check belongs in the same list, not in an unrelated section.
  run bash -c "grep -F 'check-agent-line-cap.sh' '$AGENTS_MD' | grep -F 'check-skills.sh'"
  [ "$status" -eq 0 ]
}
