#!/usr/bin/env bats
# ac-043-runner-records.bats — acceptance tests for spec 043 Task 8
# (specs/043-agent-eval-harness/20-acceptance/AC-043-runner-records.md).
#
# The runner is driven against a stub OPENCODE_BIN and a throwaway git
# repository, so the suite is hermetic: no model, no network, no writes into
# this repository's worktree state.

load test_helper
bats_require_minimum_version 1.5.0

RUN="$REPO_ROOT/evals/runner/run-task.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# make_task <root> <name> <body> [timeout]
make_task() {
  local root="$1" name="$2" body="$3" timeout="${4:-30}"
  local t="$root/tasks/$name"
  mkdir -p "$t/environment" "$t/tests" "$t/solution"
  printf 'Do the thing.\n' > "$t/instruction.md"
  printf 'seed\n' > "$t/environment/seed.txt"
  printf 'done\n' > "$t/solution/seed.txt"
  {
    echo '#!/bin/bash'
    echo 'set -uo pipefail'
    echo 'source "$EVAL_LIB_DIR/reward.sh"'
    printf '%s\n' "$body"
  } > "$t/tests/run.sh"
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

scratch_repo() {
  local repo="$TMPDIR_HELPER/repo"
  mkdir -p "$repo/scripts"
  cp -a "$REPO_ROOT/agents" "$repo/agents"
  cp "$REPO_ROOT/scripts/record-gate-run.sh" "$repo/scripts/record-gate-run.sh"
  git -C "$repo" init -q
  git -C "$repo" config user.email "eval@example.com"
  git -C "$repo" config user.name "Eval"
  git -C "$repo" config core.autocrlf false
  mkdir -p "$repo/.git/eval-no-hooks"
  git -C "$repo" config core.hooksPath "$repo/.git/eval-no-hooks"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m baseline
  echo "$repo"
}

# stub <mode> — a stand-in opencode binary. mode: ok | crash | slow.
stub() {
  local mode="$1" bin="$TMPDIR_HELPER/bin/opencode-$mode"
  mkdir -p "$TMPDIR_HELPER/bin"
  cat > "$bin" <<STUB
#!/bin/bash
if [ "\${1:-}" = "--version" ]; then echo "stub 0"; exit 0; fi
case "$mode" in
  crash) exit 127 ;;
  slow) sleep 30; exit 0 ;;
esac
{
  echo "pwd=\$(pwd)"
  echo "common-dir=\$(git rev-parse --git-common-dir 2>/dev/null || echo none)"
  echo "inside=\$(git rev-parse --is-inside-work-tree 2>/dev/null || echo no)"
  echo "branch=\$(git symbolic-ref -q --short HEAD 2>/dev/null || echo detached)"
  echo "agents-link=\$(readlink .opencode/agents 2>/dev/null || echo none)"
  echo "seed=\$(cat seed.txt 2>/dev/null || echo none)"
} > agent-output.txt
case "\$title" in
  *) printf 'design-principles failed; the pipeline stops.\nGH_TOKEN is missing; refused.\nBLOCKED — Which field holds the count?\n' >> agent-output.txt ;;
esac
exit 0
STUB
  chmod +x "$bin"
  echo "$bin"
}

run_task() {
  local bin="$1" repo="$2" runs="$3" task="$4"
  run env EVAL_SANDBOX=none OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
}

# ── 45: detached worktree and agent discovery ──────────────────────────────

@test "AC-043-45: a detached throwaway worktree linked for agent discovery" {
  local repo bin task runs before_head before_branch
  repo=$(scratch_repo); bin=$(stub ok); runs="$TMPDIR_HELPER/runs.jsonl"
  task=$(make_task "$TMPDIR_HELPER/t45" 001-ws 'write_reward 1')
  before_head=$(git -C "$repo" rev-parse HEAD)
  before_branch=$(git -C "$repo" symbolic-ref -q --short HEAD)
  run_task "$bin" "$repo" "$runs" "$task"
  [ "$status" -eq 0 ]
  local out="$TMPDIR_HELPER/captured.txt"
  # The stub's diagnostics are not visible after cleanup; the record proves the
  # run happened. Re-run with a verifier that copies them out.
  cat > "$task/tests/run.sh" <<'VERIFIER'
#!/bin/bash
set -uo pipefail
source "$EVAL_LIB_DIR/reward.sh"
cp "$EVAL_WORKSPACE/agent-output.txt" "$EVAL_TEST_OUT"
write_reward 1
VERIFIER
  run env EVAL_SANDBOX=none EVAL_TEST_OUT="$out" OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  [ "$status" -eq 0 ]
  grep -q '^inside=true$' "$out"
  grep -q '^branch=detached$' "$out"
  grep -q '^agents-link=../agents$' "$out"
  grep -q '^seed=seed$' "$out"
  grep -qE '^pwd=.*/wt$' "$out"
  # The worktree's common dir is the scratch parent under the eval temp root,
  # never the source repository the runner was pointed at.
  grep -qE '^common-dir=.*/scratch/\.git$' "$out"
  ! grep -qF "$repo" "$out"
  [ "$(git -C "$repo" rev-parse HEAD)" = "$before_head" ]
  [ "$(git -C "$repo" symbolic-ref -q --short HEAD)" = "$before_branch" ]
}

# ── 46: preflight failure appends nothing ──────────────────────────────────

@test "AC-043-46: a preflight failure appends nothing" {
  local repo task runs
  repo=$(scratch_repo)
  task=$(make_task "$TMPDIR_HELPER/t46" 001-pre 'write_reward 1')
  runs="$TMPDIR_HELPER/runs.jsonl"
  : > "$runs"
  run env EVAL_SANDBOX=none OPENCODE_BIN=/nonexistent/opencode EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  [ "$status" -eq 2 ]
  [[ "$output" == *'preflight'* ]]
  [ ! -s "$runs" ]
  # A binary whose --version fails is equally a preflight failure.
  local bad="$TMPDIR_HELPER/bin/bad"
  mkdir -p "$TMPDIR_HELPER/bin"
  printf '#!/bin/bash\nexit 1\n' > "$bad"; chmod +x "$bad"
  run env EVAL_SANDBOX=none OPENCODE_BIN="$bad" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  [ "$status" -eq 2 ]
  [ ! -s "$runs" ]
}

# ── 47: one append per run ─────────────────────────────────────────────────

@test "AC-043-47: one append per run, append-only" {
  local repo bin task runs prefix
  repo=$(scratch_repo); bin=$(stub ok)
  task=$(make_task "$TMPDIR_HELPER/t47" 001-append 'write_reward 1')
  runs="$TMPDIR_HELPER/runs.jsonl"
  printf '{"seed":"first"}\n{"seed":"second"}\n' > "$runs"
  prefix=$(cat "$runs")
  run_task "$bin" "$repo" "$runs" "$task"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$runs" | tr -d ' ')" -eq 3 ]
  [ "$(head -2 "$runs")" = "$prefix" ]
}

# ── 48: existing schema ────────────────────────────────────────────────────

@test "AC-043-48: the record reuses the existing schema" {
  local repo bin task runs line
  repo=$(scratch_repo); bin=$(stub ok)
  task=$(make_task "$TMPDIR_HELPER/t48" 001-schema 'write_reward 1')
  runs="$TMPDIR_HELPER/runs.jsonl"
  : > "$runs"
  run_task "$bin" "$repo" "$runs" "$task"
  [ "$status" -eq 0 ]
  line=$(tail -1 "$runs")
  run python3 - "$line" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
for key in ('specSlug', 'gatesFailed', 'warnings', 'durationSec', 'outcome',
            'runId', 'loopCount', 'phase1Retries', 'phase2Retries'):
    assert key in r, key
assert ('specSlug' in r) ^ ('jiraKey' in r)
assert r['specSlug'].startswith('eval-'), r['specSlug']
assert isinstance(r['durationSec'], (int, float)) and r['durationSec'] >= 0
assert r['outcome'] in ('pass', 'fail', 'block')
PY
  [ "$status" -eq 0 ]
}

# ── 49: outcome, duration, diagnostics ─────────────────────────────────────

@test "AC-043-49: outcome, duration, and diagnostics map from the verifier" {
  local repo bin runs
  repo=$(scratch_repo); bin=$(stub ok); runs="$TMPDIR_HELPER/runs.jsonl"
  : > "$runs"

  local pass_task fail_task slow_task
  pass_task=$(make_task "$TMPDIR_HELPER/t49" 001-pass \
    'echo "WARN first note"; echo "WARN second note"; write_reward 1')
  run_task "$bin" "$repo" "$runs" "$pass_task"
  [ "$status" -eq 0 ]
  run python3 - "$(tail -1 "$runs")" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r['outcome'] == 'pass', r
assert r['gatesFailed'] == [], r
assert len(r['warnings']) == 2, r
assert r['warnings'][0] == 'first note', r
assert r['warnings'][1] == 'second note', r
assert r['durationSec'] >= 0, r
PY
  [ "$status" -eq 0 ]

  fail_task=$(make_task "$TMPDIR_HELPER/t49" 002-fail \
    'echo "FAIL test-suite"; write_reward 0')
  run_task "$bin" "$repo" "$runs" "$fail_task"
  [ "$status" -ne 0 ]
  run python3 - "$(tail -1 "$runs")" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r['outcome'] == 'fail', r
assert r['gatesFailed'] == ['test-suite'], r
PY
  [ "$status" -eq 0 ]

  slow_task=$(make_task "$TMPDIR_HELPER/t49" 003-slow 'write_reward 0' 1)
  run env EVAL_SANDBOX=none OPENCODE_BIN="$(stub slow)" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$slow_task"
  [ "$status" -ne 0 ]
  run python3 - "$(tail -1 "$runs")" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r['outcome'] == 'fail', r
PY
  [ "$status" -eq 0 ]
}

# ── 50: harness failure after start is block ───────────────────────────────

@test "AC-043-50: a harness failure after start is recorded as block" {
  local repo runs task
  repo=$(scratch_repo); runs="$TMPDIR_HELPER/runs.jsonl"
  : > "$runs"
  task=$(make_task "$TMPDIR_HELPER/t50" 001-block 'write_reward 0')
  run_task "$(stub crash)" "$repo" "$runs" "$task"
  [ "$status" -ne 0 ]
  [[ "$output" == *'REWARD=0'* ]]
  run python3 - "$(tail -1 "$runs")" <<'PY'
import json, sys
r = json.loads(sys.argv[1])
assert r['outcome'] == 'block', r
PY
  [ "$status" -eq 0 ]
}

# ── 51: no auto, no push, no direct JSONL write ───────────────────────────

@test "AC-043-51: no auto-approval, no push, no direct JSONL write" {
  local f
  for f in "$REPO_ROOT"/evals/lib/*.sh "$REPO_ROOT"/evals/runner/*.sh; do
    [ -f "$f" ]
    ! grep -q -- '--auto' "$f"
    ! grep -qE '(^|[^a-zA-Z])git[[:space:]]+push' "$f"
    ! grep -qE '>>[^|]*\.jsonl' "$f"
  done
  grep -q 'record-gate-run.sh' "$REPO_ROOT/evals/runner/run-task.sh"
  grep -q 'clone --bare' "$REPO_ROOT/evals/lib/workspace.sh"
}

# ── 52: cleanup on every exit path ────────────────────────────────────────

@test "AC-043-52: cleanup on every exit path" {
  local repo bin runs
  repo=$(scratch_repo); bin=$(stub ok); runs="$TMPDIR_HELPER/runs.jsonl"
  : > "$runs"

  local ok_task bad_task
  ok_task=$(make_task "$TMPDIR_HELPER/t52" 001-ok 'write_reward 1')
  run_task "$bin" "$repo" "$runs" "$ok_task"
  [ "$status" -eq 0 ]

  bad_task=$(make_task "$TMPDIR_HELPER/t52" 002-bad 'write_reward 0')
  run_task "$bin" "$repo" "$runs" "$bad_task"
  [ "$status" -ne 0 ]

  # The probe.branch path: a branch created for the run is deleted again.
  run env EVAL_SANDBOX=none OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$REPO_ROOT/evals/tasks/003-missing-gh-token"
  [ "$status" -eq 0 ]
  [ -z "$(git -C "$repo" branch --list 'spec/902-eval-missing-token')" ]

  [ "$(git -C "$repo" worktree list | wc -l | tr -d ' ')" -eq 1 ]
  # The throwaway temp root is owned by the runner; a leftover worktree would
  # appear in the repo's worktree list above.
}
