#!/usr/bin/env bats
# ac-043-isolation.bats — unit tests for the runner's isolation contract.
#
# These cover the phase-1 BLOCK remediation: the workspace is a detached
# worktree of a scratch repository under the eval temp root (never of the
# source), the agent environment is scrubbed, any source mutation is an
# environment block, cleanup removes `remote.eval`, and the hermetic isolation
# negative control fails closed. Every fixture lives under mktemp -d; the real
# repository is only read.

load test_helper
bats_require_minimum_version 1.5.0

RUN="$REPO_ROOT/evals/runner/run-task.sh"
CONTROL="$REPO_ROOT/evals/probes/isolation/control.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

scratch_repo() {
  local repo="$TMPDIR_HELPER/source"
  mkdir -p "$repo/scripts"
  cp -a "$REPO_ROOT/agents" "$repo/agents"
  cp "$REPO_ROOT/scripts/record-gate-run.sh" "$repo/scripts/record-gate-run.sh"
  git -C "$repo" init -q
  git -C "$repo" config user.email "eval@example.com"
  git -C "$repo" config user.name "Eval"
  mkdir -p "$repo/.git/eval-no-hooks"
  git -C "$repo" config core.hooksPath "$repo/.git/eval-no-hooks"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m baseline
  echo "$repo"
}

# make_task <root> <name> — a minimal task whose verifier copies the stub's
# transcript out and writes a passing reward.
make_task() {
  local root="$1" name="$2"
  local t="$root/tasks/$name"
  mkdir -p "$t/environment" "$t/tests" "$t/solution"
  printf 'Do the thing.\n' > "$t/instruction.md"
  printf 'seed\n' > "$t/environment/seed.txt"
  printf 'done\n' > "$t/solution/seed.txt"
  cat > "$t/tests/run.sh" <<'VERIFIER'
#!/bin/bash
set -uo pipefail
source "$EVAL_LIB_DIR/reward.sh"
cp "$EVAL_WORKSPACE/agent-output.txt" "${EVAL_TEST_CAPTURE:-/dev/null}" 2>/dev/null || true
write_reward 1
VERIFIER
  cat > "$t/task.toml" <<TOML
id = "$name"
slug = "$name"
agent = "spec-coder"
timeoutSec = 30

[verifier]
command = "bash tests/run.sh"
rewardFile = "reward.txt"

[oracle]
solution = "solution"
environment = "environment"
TOML
  echo "$t"
}

# stub <bin> <body> — a stand-in opencode binary; the body runs in the
# workspace and may append to agent-output.txt.
stub() {
  local bin="$1" body="$2"
  cat > "$bin" <<STUB
#!/bin/bash
if [ "\${1:-}" = "--version" ]; then echo "stub 0"; exit 0; fi
$body
exit 0
STUB
  chmod +x "$bin"
}

@test "unit: the probe workspace is a detached scratch worktree with no origin" {
  local repo task bin runs capture
  repo=$(scratch_repo)
  task=$(make_task "$TMPDIR_HELPER/t1" 901-standalone)
  bin="$TMPDIR_HELPER/bin/opencode-1"; mkdir -p "$TMPDIR_HELPER/bin"
  stub "$bin" '{
    echo "common-dir=$(git rev-parse --git-common-dir 2>/dev/null || echo none)"
    echo "origin-url=$(git remote get-url origin 2>/dev/null || echo none)"
    echo "top=$(git rev-parse --show-toplevel 2>/dev/null || echo none)"
    echo "inside=$(git rev-parse --is-inside-work-tree 2>/dev/null || echo no)"
    echo "agents-link=$(readlink .opencode/agents 2>/dev/null || echo none)"
  } > agent-output.txt'
  runs="$TMPDIR_HELPER/runs.jsonl"; : > "$runs"
  capture="$TMPDIR_HELPER/capture.txt"
  run env EVAL_SANDBOX=none EVAL_TEST_CAPTURE="$capture" OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  [ "$status" -eq 0 ]
  # `git worktree add --detach` from the scratch parent: the common dir is the
  # scratch repo inside the eval temp root, never the source repository.
  grep -qE '^common-dir=.*/scratch/\.git$' "$capture"
  grep -q '^origin-url=none$' "$capture"
  grep -q '^inside=true$' "$capture"
  grep -qE '^top=.*/wt$' "$capture"
  grep -q '^agents-link=../agents$' "$capture"
  # The workspace path is under the eval temp root, never inside the source.
  ! grep -qF "$repo" "$capture"
  # The source repository is untouched and carries no eval remote.
  [ -z "$(git -C "$repo" remote get-url eval 2>/dev/null || true)" ]
}

# source_snapshot <repo> — the same byte-comparable view the runner uses.
source_snapshot() {
  local repo="$1"
  git -C "$repo" rev-parse --all 2>/dev/null | sort
  printf '%s\n' '--- reflog ---'
  git -C "$repo" reflog --all 2>/dev/null || true
  printf '%s\n' '--- status ---'
  git -C "$repo" status --porcelain 2>/dev/null || true
  printf '%s\n' '--- config ---'
  git -C "$repo" config --local --list 2>/dev/null | sort
}

@test "unit: origin and the discoverable repo path cannot reach the real source" {
  local repo task bin runs capture before after
  repo=$(scratch_repo)
  task=$(make_task "$TMPDIR_HELPER/t4" 904-derived-path)
  bin="$TMPDIR_HELPER/bin/opencode-4"; mkdir -p "$TMPDIR_HELPER/bin"
  # A hostile agent with no baked-in path uses only what the workspace tells
  # it: `origin` and the parent of its common dir (the scratch repo).
  cat > "$bin" <<STUB
#!/bin/bash
if [ "\${1:-}" = "--version" ]; then echo "stub 0"; exit 0; fi
{
  src="\$(cd "\$(git rev-parse --git-common-dir)/.." 2>/dev/null && pwd)"
  echo "source-path=\$src"
  if git push origin HEAD:refs/heads/hostile-origin >/dev/null 2>&1; then
    echo 'push-origin=SUCCEEDED'
  else
    echo 'push-origin=failed'
  fi
  if git push "\$src" HEAD:refs/heads/hostile-derived >/dev/null 2>&1; then
    echo 'push-source=SUCCEEDED'
  else
    echo 'push-source=failed'
  fi
} > agent-output.txt
exit 0
STUB
  chmod +x "$bin"
  runs="$TMPDIR_HELPER/runs.jsonl"; : > "$runs"
  capture="$TMPDIR_HELPER/capture.txt"
  before="$(source_snapshot "$repo")"
  run env EVAL_SANDBOX=none EVAL_TEST_CAPTURE="$capture" OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  after="$(source_snapshot "$repo")"
  [ "$status" -eq 0 ]
  grep -q '^push-origin=failed$' "$capture"
  # The explicit path the workspace discloses is the scratch parent, and the
  # transport deny-list rejects the push even there.
  grep -q '^push-source=failed$' "$capture"
  grep -qE '^source-path=.*/scratch$' "$capture"
  ! grep -qF "$repo" "$capture"
  [ "$before" = "$after" ]
}

@test "unit: an explicit source-path push is blocked and the source is unchanged" {
  local repo task bin runs capture before after
  repo=$(scratch_repo)
  task=$(make_task "$TMPDIR_HELPER/t5" 905-explicit-source)
  bin="$TMPDIR_HELPER/bin/opencode-5"; mkdir -p "$TMPDIR_HELPER/bin"
  # Worst case: the stub knows the real source path and tries both routes.
  cat > "$bin" <<STUB
#!/bin/bash
if [ "\${1:-}" = "--version" ]; then echo "stub 0"; exit 0; fi
{
  if git push origin HEAD:refs/heads/hostile-origin >/dev/null 2>&1; then
    echo 'push-origin=SUCCEEDED'
  else
    echo 'push-origin=failed'
  fi
  if git push "$repo" HEAD:refs/heads/hostile-explicit >/dev/null 2>&1; then
    echo 'push-explicit=SUCCEEDED'
  else
    echo 'push-explicit=failed'
  fi
} > agent-output.txt
exit 0
STUB
  chmod +x "$bin"
  runs="$TMPDIR_HELPER/runs.jsonl"; : > "$runs"
  capture="$TMPDIR_HELPER/capture.txt"
  before="$(source_snapshot "$repo")"
  run env EVAL_SANDBOX=none EVAL_TEST_CAPTURE="$capture" OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  after="$(source_snapshot "$repo")"
  [ "$status" -eq 0 ]
  grep -q '^push-origin=failed$' "$capture"
  grep -q '^push-explicit=failed$' "$capture"
  [ "$before" = "$after" ]
  [ -z "$(git -C "$repo" branch --list 'hostile-explicit')" ]
}

@test "unit: the agent environment is scrubbed" {
  local repo task bin runs capture
  repo=$(scratch_repo)
  task=$(make_task "$TMPDIR_HELPER/t2" 902-env)
  bin="$TMPDIR_HELPER/bin/opencode-2"; mkdir -p "$TMPDIR_HELPER/bin"
  stub "$bin" 'env | sort > agent-output.txt'
  runs="$TMPDIR_HELPER/runs.jsonl"; : > "$runs"
  capture="$TMPDIR_HELPER/capture.txt"
  run env EVAL_SANDBOX=none EVAL_TEST_CAPTURE="$capture" OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  [ "$status" -eq 0 ]
  for forbidden in EVAL_ GIT_DIR GIT_WORK_TREE GIT_CONFIG_ GIT_INDEX_FILE XDG_CONFIG_HOME; do
    ! grep -q "^${forbidden}" "$capture"
  done
  # HOME/TMPDIR are redirected inside the eval temp root, never the host's.
  ! grep -qxF "HOME=$HOME" "$capture"
  grep -q '^PATH=' "$capture"
  grep -q '^GIT_CEILING_DIRECTORIES=' "$capture"
  ! grep -qF "$repo" "$capture"
}

@test "unit: a source mutation is an environment block, never a pass" {
  local repo task bin runs capture
  repo=$(scratch_repo)
  task=$(make_task "$TMPDIR_HELPER/t3" 903-hostile)
  bin="$TMPDIR_HELPER/bin/opencode-3"; mkdir -p "$TMPDIR_HELPER/bin"
  stub "$bin" "{
    git push origin HEAD:refs/heads/hostile-origin >/dev/null 2>&1 \
      && echo 'push-origin=SUCCEEDED' || echo 'push-origin=failed'
    git push '$repo' HEAD:refs/heads/hostile-explicit >/dev/null 2>&1 \
      && echo 'push-explicit=SUCCEEDED' || echo 'push-explicit=failed'
    printf 'touched\n' > '$repo/EVAL_AGENT_TOUCHED_SOURCE' \
      && echo 'write-outside=SUCCEEDED' || echo 'write-outside=failed'
  } > agent-output.txt"
  runs="$TMPDIR_HELPER/runs.jsonl"; : > "$runs"
  capture="$TMPDIR_HELPER/capture.txt"
  run env EVAL_SANDBOX=none EVAL_TEST_CAPTURE="$capture" OPENCODE_BIN="$bin" EVAL_REPO_ROOT="$repo" \
    bash "$RUN" --runs-file "$runs" "$task"
  [ "$status" -ne 0 ]
  grep -q 'isolation-breach' <<< "$output"
  grep -q '^push-origin=failed$' "$capture"
  grep -q '^push-explicit=failed$' "$capture"
  grep -q '^write-outside=SUCCEEDED$' "$capture"
  run python3 - "$runs" <<'PY'
import json, sys
lines = [l for l in open(sys.argv[1]).read().splitlines() if l.strip()]
r = json.loads(lines[-1])
assert r['outcome'] == 'block', r
assert 'isolation-breach' in r['gatesFailed'], r
PY
  [ "$status" -eq 0 ]
}

@test "unit: the source snapshot covers ignored files, hooks, info/exclude, packed and remote refs" {
  local repo before after
  repo=$(scratch_repo)
  source "$REPO_ROOT/evals/lib/workspace.sh"
  snap() { snapshot_repo_state "$repo"; }
  before="$(snap)"

  mkdir -p "$repo/ignored-dir"
  printf 'payload\n' > "$repo/ignored-dir/payload"
  printf 'ignored-dir/\n' >> "$repo/.git/info/exclude"
  after="$(snap)"
  [ "$before" != "$after" ]
  grep -q 'ignored-dir' <<< "$after"
  rm -rf "$repo/ignored-dir"

  printf '#!/bin/bash\n' > "$repo/.git/hooks/post-checkout"
  chmod +x "$repo/.git/hooks/post-checkout"
  after="$(snap)"
  [ "$before" != "$after" ]
  grep -q 'post-checkout' <<< "$after"
  rm -f "$repo/.git/hooks/post-checkout"

  git -C "$repo" update-ref refs/remotes/origin/snapshot HEAD
  after="$(snap)"
  [ "$before" != "$after" ]
  grep -q 'refs/remotes/origin/snapshot' <<< "$after"

  git -C "$repo" pack-refs --all
  after="$(snap)"
  [ "$before" != "$after" ]
  grep -A2 -- '--- packed-refs ---' <<< "$after" | grep -q 'refs/'
}

@test "unit: the host-mode isolation control fails closed and names sandbox=none" {
  run env EVAL_SANDBOX=none bash "$CONTROL"
  [ "$status" -eq 0 ]
  [[ "$output" == *'sandbox=none'* ]]
  [[ "$output" == *'not-isolated'* ]]
  [[ "$output" == *'outcome=block'* ]]
  [[ "$output" == *'fails=isolation-breach'* ]]
  [[ "$output" == *'origin-push=blocked'* ]]
}

@test "unit: the isolation control refuses when the sandbox is unavailable" {
  run env EVAL_SANDBOX=docker EVAL_SANDBOX_DOCKER=/nonexistent/docker bash "$CONTROL"
  [ "$status" -eq 2 ]
  [[ "$output" == *'environment-block'* ]]
  [[ "$output" == *'sandbox-unavailable'* ]]
}
