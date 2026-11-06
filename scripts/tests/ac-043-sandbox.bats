#!/usr/bin/env bats
# ac-043-sandbox.bats — unit tests for the container boundary introduced by the
# phase-1 isolation remediation (spec 043).
#
# The real container proof lives in `evals/probes/isolation/control.sh` and runs
# only on a Docker host. These tests are hermetic: they inspect the Dockerfile
# and the command sandbox.sh would build, and they drive the fail-closed paths
# with a fake Docker binary, so `make test` needs no daemon.

load test_helper
bats_require_minimum_version 1.5.0

DOCKERFILE="$REPO_ROOT/evals/sandbox/Dockerfile"
SANDBOX_LIB="$REPO_ROOT/evals/lib/sandbox.sh"
RUN="$REPO_ROOT/evals/runner/run-task.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

fake_docker() {
  local bin="$1"
  mkdir -p "$(dirname "$bin")"
  cat > "$bin" <<'FAKE'
#!/bin/bash
case "${1:-}" in
  info) exit "${FAKE_INFO_STATUS:-0}" ;;
  image) exit "${FAKE_IMAGE_STATUS:-0}" ;;
esac
printf '%s\n' "$@"
exit 0
FAKE
  chmod +x "$bin"
  echo "$bin"
}

# ── The image is pinned, minimal, and carries no host mount ─────────────────

@test "unit: the sandbox image is pinned by digest and installs only git and CA roots" {
  [ -f "$DOCKERFILE" ]
  grep -qE '^FROM debian:bookworm-slim@sha256:[0-9a-f]{64}$' "$DOCKERFILE"
  grep -q 'apt-get install -y --no-install-recommends git ca-certificates' "$DOCKERFILE"
  ! grep -qiE '^(RUN|COPY|ADD).*(docker|openssh|sudo)' "$DOCKERFILE"
  grep -q 'spec-eval-sandbox:734a72b3d614' "$REPO_ROOT/Makefile"
}

@test "unit: the sandbox never uses privileged mode, the docker socket, \$HOME, or the source" {
  ! grep -q -- '--privileged' "$SANDBOX_LIB"
  ! grep -qF 'docker.sock' "$SANDBOX_LIB"
  ! grep -qE -- '-v[[:space:]]+"?\$HOME' "$SANDBOX_LIB"
  ! grep -qE -- '-v[[:space:]]+"?\$REPO_ROOT' "$SANDBOX_LIB"
  # The only volume flags are the temp root and the read-only agent binary.
  [ "$(grep -cE '^[[:space:]]+-v ' "$SANDBOX_LIB")" -eq 2 ]
}

# ── sandbox_run builds the required boundary ────────────────────────────────

@test "unit: sandbox_run drops capabilities, limits resources, and mounts only the temp root" {
  local fake="$TMPDIR_HELPER/bin/docker" out="$TMPDIR_HELPER/argv.txt"
  fake=$(fake_docker "$fake")
  run env EVAL_SANDBOX_DOCKER="$fake" EVAL_SANDBOX_NETWORK=none \
    bash -c '
      source "$1"
      SANDBOX_ENV=("HOME=/tmp/root/home" "PATH=/usr/bin")
      sandbox_run /tmp/root /tmp/root/wt /host/opencode echo hello
    ' _ "$SANDBOX_LIB"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" > "$out"
  grep -qE '^run$' "$out"
  grep -qx -- '--rm' "$out"
  grep -qx -- '--init' "$out"
  grep -qx -- '--cap-drop=ALL' "$out"
  grep -qx -- '--security-opt' "$out"
  grep -qx -- 'no-new-privileges' "$out"
  grep -qx -- '--pids-limit' "$out"
  grep -qx -- '256' "$out"
  grep -qx -- '--memory' "$out"
  grep -qx -- '1g' "$out"
  grep -qx -- "--user" "$out"
  grep -qx "$(id -u):$(id -g)" "$out"
  grep -qx -- '--network' "$out"
  grep -qx -- 'none' "$out"
  grep -qx -- '-w' "$out"
  grep -qx '/tmp/root/wt' "$out"
  grep -qx '/tmp/root:/tmp/root' "$out"
  grep -qx '/host/opencode:/usr/local/bin/opencode:ro' "$out"
  grep -qx 'HOME=/tmp/root/home' "$out"
  grep -qx -- 'echo' "$out"
  grep -qx -- 'hello' "$out"
  grep -qx 'spec-eval-sandbox:734a72b3d614' "$out"
  # No other mount source can sneak in.
  [ "$(grep -c -- ':/' "$out" | tr -d ' ')" -eq 2 ]
}

# ── Fail closed ────────────────────────────────────────────────────────────

@test "unit: sandbox_preflight refuses a missing docker, a dead daemon, and an unbuilt image" {
  run env EVAL_SANDBOX=docker EVAL_SANDBOX_DOCKER=/nonexistent/docker \
    bash -c 'source "$1"; sandbox_preflight' _ "$SANDBOX_LIB"
  [ "$status" -ne 0 ]
  [[ "$output" == *'docker not found'* ]]

  local fake
  fake=$(fake_docker "$TMPDIR_HELPER/bin/docker-dead")
  run env EVAL_SANDBOX=docker EVAL_SANDBOX_DOCKER="$fake" FAKE_INFO_STATUS=1 \
    bash -c 'source "$1"; sandbox_preflight' _ "$SANDBOX_LIB"
  [ "$status" -ne 0 ]
  [[ "$output" == *'daemon is unreachable'* ]]

  fake=$(fake_docker "$TMPDIR_HELPER/bin/docker-noimage")
  run env EVAL_SANDBOX=docker EVAL_SANDBOX_DOCKER="$fake" FAKE_IMAGE_STATUS=1 \
    bash -c 'source "$1"; sandbox_preflight' _ "$SANDBOX_LIB"
  [ "$status" -ne 0 ]
  [[ "$output" == *'not built'* ]]
}

@test "unit: an unknown sandbox mode is rejected and default is docker" {
  run env EVAL_SANDBOX=bogus bash -c 'source "$1"; sandbox_preflight' _ "$SANDBOX_LIB"
  [ "$status" -ne 0 ]
  [[ "$output" == *'unknown EVAL_SANDBOX'* ]]

  run env -u EVAL_SANDBOX bash -c 'source "$1"; sandbox_mode' _ "$SANDBOX_LIB"
  [ "$status" -eq 0 ]
  [ "$output" = "docker" ]

  run env EVAL_SANDBOX=none bash -c 'source "$1"; sandbox_preflight; echo "mode=$(sandbox_mode)"' \
    _ "$SANDBOX_LIB"
  [ "$status" -eq 0 ]
  [[ "$output" == *'mode=none'* ]]
}

@test "unit: run-task exits 2 with no record when the sandbox is unavailable" {
  local runs="$TMPDIR_HELPER/runs.jsonl"
  run env EVAL_SANDBOX=docker EVAL_SANDBOX_DOCKER=/nonexistent/docker \
    OPENCODE_BIN=/bin/true \
    bash "$RUN" --runs-file "$runs" "$REPO_ROOT/evals/tasks/001-ambiguous-specifier"
  [ "$status" -eq 2 ]
  [[ "$output" == *'sandbox unavailable'* ]]
  [ ! -e "$runs" ]
}

@test "unit: run-task rejects an unknown sandbox mode before recording" {
  local runs="$TMPDIR_HELPER/runs.jsonl"
  run env EVAL_SANDBOX=bogus OPENCODE_BIN=/bin/true \
    bash "$RUN" --runs-file "$runs" "$REPO_ROOT/evals/tasks/001-ambiguous-specifier"
  [ "$status" -eq 2 ]
  [[ "$output" == *'unknown EVAL_SANDBOX'* ]]
  [ ! -e "$runs" ]
}

@test "unit: run-probes --record refuses before recording when the sandbox is unavailable" {
  local runs="$TMPDIR_HELPER/runs.jsonl"
  run env EVAL_ALLOW_AGENT=1 EVAL_SANDBOX=docker EVAL_SANDBOX_DOCKER=/nonexistent/docker \
    bash "$REPO_ROOT/evals/runner/run-probes.sh" --record --runs-file "$runs"
  [ "$status" -eq 2 ]
  [[ "$output" == *'sandbox unavailable'* ]]
  [ ! -e "$runs" ]
}

@test "unit: run-task wires the sandbox, not a host exec, for the default mode" {
  grep -q 'sandbox_preflight' "$RUN"
  grep -q 'sandbox_mode' "$RUN"
  grep -q 'sandbox_run' "$RUN"
  # The detached worktree is still created host-side by git; the sandbox only
  # changes where the agent process runs.
  grep -q 'add_detached_worktree' "$RUN"
  grep -q 'git -C "$scratch" worktree add --detach' "$REPO_ROOT/evals/lib/workspace.sh"
}
