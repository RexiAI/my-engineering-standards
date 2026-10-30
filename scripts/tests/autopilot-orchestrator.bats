#!/usr/bin/env bats
# autopilot-orchestrator.bats — acceptance tests for spec 035 Task 5
# (specs/035-autopilot-mode/20-acceptance/AC-035-orchestrator.md).
# The orchestrator prompt is the runtime carrier of the autopilot rules, so the
# assertions are static against agents/spec-pipeline.md.

load test_helper
bats_require_minimum_version 1.5.0

AGENT="$REPO_ROOT/agents/spec-pipeline.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-15 — the orchestrator never asks in autopilot and records each resolved ask" {
  [ -f "$AGENT" ]
  grep -qF 'Autopilot mode' "$AGENT"
  grep -qiF 'question tool' "$AGENT"
  grep -qF 'BLOCKED' "$AGENT"
  grep -qiF 'never wait' "$AGENT"
  grep -qiF 'disposition table' "$AGENT"
  grep -qiF 'record the decision' "$AGENT"
  grep -qF 'autopilot-trigger.sh' "$AGENT"
}

@test "AC-035-16 — the 9 never-list actions are hard refusals, never decisions" {
  # Spec 036: the never-list lives once in docs/SPEC_PIPELINE.md §Never-list;
  # the orchestrator references it instead of restating it.
  DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"
  grep -qF 'docs/SPEC_PIPELINE.md §Never-list' "$AGENT"
  run cat "$DOC"
  [[ "$output" == *"no merge"* ]]
  [[ "$output" == *"no git tag"* ]]
  [[ "$output" == *'no push to `main`/`master`'* ]]
  [[ "$output" == *"no force-push"* ]]
  [[ "$output" == *"no branch deletion"* ]]
  [[ "$output" == *"no gate-threshold change"* ]]
  [[ "$output" == *"no secret creation/rotation"* ]]
  [[ "$output" == *"no writes outside the target repo"* ]]
  [[ "$output" == *'no `git init`/submodule scaffolding'* ]]
  grep -qF 'hard stop' "$AGENT"
  grep -qiF 'never a decision' "$AGENT"
}

@test "AC-035-17 — the queue stops at the first hard stop and writes the morning report" {
  run cat "$AGENT"
  [[ "$output" == *"in the order given"* ]]
  [[ "$output" == *"first hard stop"* ]]
  [[ "$output" == *"morning report"* ]]
  [[ "$output" == *"do not skip to the next slug"* ]]
  # the human gate is removed only under autopilot
  grep -qiF 'only under autopilot' "$AGENT"
}
