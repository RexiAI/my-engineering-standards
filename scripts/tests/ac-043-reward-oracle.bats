#!/usr/bin/env bats
# ac-043-reward-oracle.bats — acceptance tests for spec 043 Tasks 4 and 7
# (specs/043-agent-eval-harness/20-acceptance/AC-043-reward-contract.md,
# AC-043-oracle-sanity.md).
#
# The suites exercise evals/lib/reward.sh and evals/runner/oracle.sh through
# their public entry points. Every fixture is a mktemp tree.

load test_helper
bats_require_minimum_version 1.5.0

REWARD_LIB="$REPO_ROOT/evals/lib/reward.sh"
ORACLE="$REPO_ROOT/evals/runner/oracle.sh"
GATE="$REPO_ROOT/scripts/check-agent-evals.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# make_task <root> <name> <verifier-body> [timeout] [solution-body]
make_task() {
  local root="$1" name="$2" body="$3" timeout="${4:-30}" sol="${5:-done}"
  local t="$root/evals/tasks/$name"
  mkdir -p "$t/environment" "$t/tests" "$t/solution"
  printf 'Do the thing.\n' > "$t/instruction.md"
  printf 'seed\n' > "$t/environment/seed.txt"
  printf '%s\n' "$sol" > "$t/solution/seed.txt"
  cat > "$t/tests/run.sh" <<VERIFIER
#!/bin/bash
set -uo pipefail
source "\$EVAL_LIB_DIR/reward.sh"
VERIFIER
  printf '%s\n' "$body" >> "$t/tests/run.sh"
  cat > "$t/task.toml" <<TOML
id = "$name"
slug = "$name"
agent = "spec-coder"
timeoutSec = $timeout

[verifier]
command = "bash tests/run.sh"
rewardFile = "reward.txt"

[oracle]
solution = "solution"
environment = "environment"
TOML
  echo "$t"
}

# grade <task> <workspace> — run the harness in a subshell and capture its
# stdout/status without letting set -e leak into the test body.
grade() {
  run bash -c 'source "$1"; run_verifier "$2" "$3"' _ "$REWARD_LIB" "$1" "$2"
}

# workspace_for <task> — a fresh workspace holding the environment direction.
workspace_for() {
  local task="$1" ws
  ws="$(mktemp -d)"
  cp -a "$task/environment/." "$ws/"
  echo "$ws"
}

# ── Task 4: single-reward contract ──────────────────────────────────────────

@test "AC-043-17: a passing verifier produces exactly one reward" {
  local root="$TMPDIR_HELPER/r17" task ws
  task=$(make_task "$root" 001-pass 'write_reward 1')
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 0 ]
  [[ "$output" == *'REWARD=1'* ]]
  [[ "$output" != *'REASON='* ]]
  [ "$(wc -l < "$ws/reward.txt" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$ws/reward.txt")" = "1" ]
}

@test "AC-043-18: a non-zero verifier exit forces a zero reward" {
  local root="$TMPDIR_HELPER/r18" task ws
  task=$(make_task "$root" 001-exit1 'write_reward 1
exit 1')
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 1 ]
  [[ "$output" == *'REWARD=0'* ]]
  [[ "$output" == *'REASON=verifier-exit-1'* ]]
  [ "$(cat "$ws/reward.txt")" = "0" ]
  [ "$(wc -l < "$ws/reward.txt" | tr -d ' ')" -eq 1 ]
}

@test "AC-043-19: a crashed verifier scores zero" {
  local root="$TMPDIR_HELPER/r19" task ws
  task=$(make_task "$root" 001-crash 'exit 1')
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 1 ]
  [[ "$output" == *'REWARD=0'* ]]
  [[ "$output" == *'REASON=verifier-exit-1'* ]]
  [ "$(cat "$ws/reward.txt")" = "0" ]
}

@test "AC-043-20: a silent verifier scores zero and warns" {
  local root="$TMPDIR_HELPER/r20" task ws
  task=$(make_task "$root" 001-silent 'exit 0')
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 1 ]
  [[ "$output" == *'REWARD=0'* ]]
  [[ "$output" == *'REASON=no-reward-value'* ]]
  [[ "$output" == *'WARN'* ]]
  [ "$(cat "$ws/reward.txt")" = "0" ]
}

@test "AC-043-21: two reward values are rejected" {
  local root="$TMPDIR_HELPER/r21" task ws
  task=$(make_task "$root" 001-two 'printf "1\n0\n" > "$EVAL_REWARD_FILE"')
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 1 ]
  [[ "$output" == *'REWARD=0'* ]]
  [[ "$output" == *'REASON=multiple-reward-values'* ]]
  [ "$(wc -l < "$ws/reward.txt" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$ws/reward.txt")" = "0" ]
}

@test "AC-043-22: an invalid reward value is rejected" {
  local root="$TMPDIR_HELPER/r22" task ws
  for pair in '001-two-val|printf "2\n" > "$EVAL_REWARD_FILE"' '001-pass-val|printf "pass\n" > "$EVAL_REWARD_FILE"' '001-empty-val|: > "$EVAL_REWARD_FILE"'; do
    local name="${pair%%|*}" body="${pair#*|}"
    task=$(make_task "$root" "$name" "$body")
    ws=$(workspace_for "$task")
    grade "$task" "$ws"
    [ "$status" -eq 1 ]
    [[ "$output" == *'REWARD=0'* ]]
    [[ "$output" == *'REASON=invalid-reward-value'* ]]
    [ "$(cat "$ws/reward.txt")" = "0" ]
  done
}

@test "AC-043-23: repeated grading overwrites atomically, never appends" {
  local root="$TMPDIR_HELPER/r23" task ws
  task=$(make_task "$root" 001-repeat 'write_reward 1')
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 0 ]
  [ "$(cat "$ws/reward.txt")" = "1" ]
  # Second grade flips the verifier outcome.
  sed -i 's/write_reward 1/write_reward 0/' "$task/tests/run.sh"
  grade "$task" "$ws"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$ws/reward.txt" | tr -d ' ')" -eq 1 ]
  [ "$(cat "$ws/reward.txt")" = "0" ]
  [ -z "$(find "$ws" -maxdepth 1 -name '*.tmp' -print -quit)" ]
}

@test "AC-043-24: a verifier timeout scores zero" {
  local root="$TMPDIR_HELPER/r24" task ws
  task=$(make_task "$root" 001-slow 'sleep 30' 1)
  ws=$(workspace_for "$task")
  grade "$task" "$ws"
  [ "$status" -eq 1 ]
  [[ "$output" == *'REWARD=0'* ]]
  [[ "$output" == *'REASON=verifier-timeout'* ]]
  [ "$(cat "$ws/reward.txt")" = "0" ]
  [ -z "$(find "$ws" -maxdepth 1 -name '*.tmp' -print -quit)" ]
}

# ── Task 7: oracle sanity ──────────────────────────────────────────────────

@test "AC-043-38: the solution direction scores one for every task" {
  local t
  for t in "$REPO_ROOT"/evals/tasks/*/; do
    [ -d "$t" ] || continue
    run bash "$ORACLE" "$t"
    [[ "$output" == *"solution=1"* ]]
  done
}

@test "AC-043-39: the untouched environment scores zero for every task" {
  local t
  for t in "$REPO_ROOT"/evals/tasks/*/; do
    [ -d "$t" ] || continue
    run bash "$ORACLE" "$t"
    [[ "$output" == *"environment=0"* ]]
  done
}

@test "AC-043-40: a task that cannot fail is rejected" {
  local root="$TMPDIR_HELPER/r40"
  mkdir -p "$root/agents" "$root/evals/tasks"
  printf '# coder\n' > "$root/agents/spec-coder.md"
  make_task "$root" 001-always 'write_reward 1' >/dev/null
  run bash "$GATE" --only 5 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'task cannot fail'* ]]
  [[ "$output" == *'001-always'* ]]
}

@test "AC-043-41: a missing or empty solution is rejected" {
  local root="$TMPDIR_HELPER/r41"
  mkdir -p "$root/agents" "$root/evals/tasks"
  printf '# coder\n' > "$root/agents/spec-coder.md"
  make_task "$root" 001-no-solution 'write_reward 0' >/dev/null
  rm -rf "$root/evals/tasks/001-no-solution/solution"
  make_task "$root" 002-empty-solution 'write_reward 0' >/dev/null
  rm -rf "$root/evals/tasks/002-empty-solution/solution"
  mkdir -p "$root/evals/tasks/002-empty-solution/solution"
  run bash "$GATE" --only 5 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'001-no-solution'* ]]
  [[ "$output" == *'002-empty-solution'* ]]
  [[ "$output" == *'solution'* ]]
}

@test "AC-043-42: the oracle needs no model and no network" {
  local t
  for t in "$REPO_ROOT"/evals/tasks/*/; do
    [ -d "$t" ] || continue
    run env -u SPEC_CODER_MODEL -u SPEC_SPECIFIER_MODEL -u SPEC_PIPELINE_MODEL \
      OPENCODE_BIN=/nonexistent/opencode bash "$ORACLE" "$t"
    [ "$status" -eq 0 ]
    [[ "$output" == *'environment=0'* ]]
    [[ "$output" == *'solution=1'* ]]
  done
}

@test "AC-043-43: the oracle never touches the source tree" {
  local before_status before_runs after_status after_runs
  before_status=$(cd "$REPO_ROOT" && git status --porcelain)
  before_runs=$(sha256sum "$REPO_ROOT/runs.jsonl" | awk '{print $1}')
  local t
  for t in "$REPO_ROOT"/evals/tasks/*/; do
    [ -d "$t" ] || continue
    bash "$ORACLE" "$t" >/dev/null
  done
  after_status=$(cd "$REPO_ROOT" && git status --porcelain)
  after_runs=$(sha256sum "$REPO_ROOT/runs.jsonl" | awk '{print $1}')
  [ "$before_status" = "$after_status" ]
  [ "$before_runs" = "$after_runs" ]
}

@test "AC-043-44: the gate reports both directions for every task" {
  run bash "$GATE" --only 5
  [ "$status" -eq 0 ]
  local t n=0
  for t in "$REPO_ROOT"/evals/tasks/*/; do
    [ -d "$t" ] || continue
    n=$((n + 1))
    [[ "$output" == *"$(basename "$t")"*'environment='*'solution='* ]]
  done
  [ "$n" -ge 3 ]
  local root="$TMPDIR_HELPER/r44"
  mkdir -p "$root/agents" "$root/evals/tasks"
  printf '# coder\n' > "$root/agents/spec-coder.md"
  run bash "$GATE" --only 5 "$root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'FAIL AC-043-44'* ]]
}
