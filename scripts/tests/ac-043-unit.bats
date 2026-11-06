#!/usr/bin/env bats
# ac-043-unit.bats — unit tests for spec 043's internal library behavior.
#
# These cover boundary and error paths the Given/When/Then scenarios do not
# spell out as full scenarios (a rejected direct write_reward value, a missing
# manifest key, a task with no probe table, the record builder's empty lists).

load test_helper
bats_require_minimum_version 1.5.0

REWARD_LIB="$REPO_ROOT/evals/lib/reward.sh"
TASK_LIB="$REPO_ROOT/evals/lib/task.sh"
RECORD_LIB="$REPO_ROOT/evals/lib/record.sh"
WORKSPACE_LIB="$REPO_ROOT/evals/lib/workspace.sh"
RUN="$REPO_ROOT/evals/runner/run-task.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "unit: write_reward rejects a value other than 0 or 1" {
  local out="$TMPDIR_HELPER/reward.txt"
  run bash -c 'source "$1"; EVAL_REWARD_FILE="$2"; write_reward 2; echo "status=$?"' \
    _ "$REWARD_LIB" "$out"
  [ "$status" -eq 0 ]
  [[ "$output" == *'status=1'* ]]
  [[ "$output" == *'reward must be 0 or 1'* ]]
  [ ! -e "$out" ]
}

@test "unit: write_reward requires EVAL_REWARD_FILE" {
  run env -u EVAL_REWARD_FILE bash -c 'source "$1"; write_reward 1; echo "status=$?"' \
    _ "$REWARD_LIB"
  [ "$status" -eq 0 ]
  [[ "$output" == *'status=1'* ]]
  [[ "$output" == *'EVAL_REWARD_FILE is not set'* ]]
}

@test "unit: eval_task_field returns empty for a missing key" {
  mkdir -p "$TMPDIR_HELPER/task"
  cat > "$TMPDIR_HELPER/task/task.toml" <<'TOML'
id = "001-unit"
slug = "001-unit"
agent = "spec-coder"
timeoutSec = 30
[verifier]
command = "bash tests/run.sh"
rewardFile = "reward.txt"
[oracle]
solution = "solution"
environment = "environment"
TOML
  run bash -c 'source "$1"; eval_task_field "$2" verifier.nope; echo "status=$?"' \
    _ "$TASK_LIB" "$TMPDIR_HELPER/task"
  [ "$status" -eq 0 ]
  [[ "$output" == *'status=0'* ]]
  [[ "$output" != *'spec-coder'* ]]
  run bash -c 'source "$1"; eval_task_field "$2" verifier.rewardFile' \
    _ "$TASK_LIB" "$TMPDIR_HELPER/task"
  [ "$status" -eq 0 ]
  [ "$output" = "reward.txt" ]
}

@test "unit: run_task rejects an unknown option with exit 2" {
  run bash "$RUN" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *'unknown option'* ]]
}

@test "unit: run_verifier reports an invalid manifest instead of crashing" {
  mkdir -p "$TMPDIR_HELPER/bad/environment" "$TMPDIR_HELPER/bad/tests" "$TMPDIR_HELPER/bad/solution"
  printf 'Do.\n' > "$TMPDIR_HELPER/bad/instruction.md"
  printf 'x\n' > "$TMPDIR_HELPER/bad/environment/x"
  printf 'x\n' > "$TMPDIR_HELPER/bad/solution/x"
  printf '#!/bin/bash\n' > "$TMPDIR_HELPER/bad/tests/run.sh"
  cat > "$TMPDIR_HELPER/bad/task.toml" <<'TOML'
id = "001-bad"
slug = "001-bad"
agent = "spec-coder"
timeoutSec = 30
[verifier]
rewardFile = "reward.txt"
[oracle]
solution = "solution"
environment = "environment"
TOML
  run bash -c 'source "$1"; mkdir -p "$3/ws"; run_verifier "$2" "$3/ws"' \
    _ "$REWARD_LIB" "$TMPDIR_HELPER/bad" "$TMPDIR_HELPER/bad-run"
  [ "$status" -eq 1 ]
  [[ "$output" == *'REWARD=0'* ]]
  [[ "$output" == *'REASON=invalid-manifest'* ]]
  [ ! -e "$TMPDIR_HELPER/bad-run/ws/reward.txt" ]
}

@test "unit: build_eval_record emits empty lists and a numeric duration" {
  run env EVAL_RECORD_SLUG=eval-001-unit EVAL_RECORD_GATES= \
    EVAL_RECORD_WARNINGS= EVAL_RECORD_DURATION=2 EVAL_RECORD_OUTCOME=pass \
    bash -c 'source "$1"; build_eval_record' _ "$RECORD_LIB"
  [ "$status" -eq 0 ]
  run python3 - "$output" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r['gatesFailed'] == [], r
assert r['warnings'] == [], r
assert r['durationSec'] == 2.0, r
assert r['outcome'] == 'pass', r
PY
  [ "$status" -eq 0 ]
}
