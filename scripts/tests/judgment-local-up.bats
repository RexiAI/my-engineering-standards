#!/usr/bin/env bats
# judgment-local-up.bats — acceptance tests for scripts/judgment-local-up.sh
# (spec 029 Task 3, AC-029-30 … AC-029-38). All tests run offline and hermetic:
# the "server" is a trivial python3 stdlib HTTP listener started as the
# overridable recipe command (JUDGMENT_LOCAL_UP_CMD), and all recipe values
# (port, run dir, command, clone dir) are injected via the top-of-script env
# overrides so no GPU, model download, or real network endpoint is involved.

load test_helper
bats_require_minimum_version 1.5.0

SCRIPT="$REPO_ROOT/scripts/judgment-local-up.sh"

setup() {
  setup_tmpdir
  BIN="$TMPDIR_HELPER/bin"
  mkdir -p "$BIN"

  # A free localhost port for the mock listener.
  PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')

  # Mock "server": answers 200 JSON on any path (stands in for both the health
  # endpoint and the API path). Killed by the script's `down` via PID file.
  cat > "$TMPDIR_HELPER/mock_server.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
PORT = int(sys.argv[1]); TAG = sys.argv[2] if len(sys.argv) > 2 else "mock"
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/v1/models") or self.path.startswith("/health"):
            body = json.dumps({"ok": True, "tag": TAG}).encode()
            self.send_response(200); self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(body))); self.end_headers()
            self.wfile.write(body)
        else:
            self.send_response(404); self.end_headers()
    def do_POST(self):
        self.do_GET()
    def log_message(self, *a): pass
ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY

  # Pretend the recipe clone dir already exists with a venv so the bootstrap
  # guard never hits the network in tests.
  export JUDGMENT_KEV_DIR="$TMPDIR_HELPER/kev"
  mkdir -p "$JUDGMENT_KEV_DIR/.venv/bin"
  export JUDGMENT_LOCAL_PORT="$PORT"
  export JUDGMENT_LOCAL_RUN_DIR="$TMPDIR_HELPER/run"
  export JUDGMENT_LOCAL_UP_CMD="python3 $TMPDIR_HELPER/mock_server.py $PORT"
  export JUDGMENT_LOCAL_TIMEOUT_SECONDS=5
  unset JUDGMENT_DEBUG
  # Hermeticity (spec 029 amendment): the CUDA-allocator default test needs a
  # known-unset baseline regardless of the developer shell's env.
  unset PYTORCH_CUDA_ALLOC_CONF
}

teardown() {
  # safety: never leak a mock server beyond the test
  if [ -d "${JUDGMENT_LOCAL_RUN_DIR:-}" ]; then
    for f in "$JUDGMENT_LOCAL_RUN_DIR"/*.pid; do
      [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true
    done
  fi
  teardown_tmpdir
}

count_pids() { ls "$JUDGMENT_LOCAL_RUN_DIR"/*.pid 2>/dev/null | wc -l; }

@test "AC-029-30: up starts the server, waits for health, prints env lines, exits 0" {
  run bash "$SCRIPT" up
  assert_exit_code 0 "$status"
  [[ "$output" == *"JUDGMENT_BACKEND=local"* ]]
  [[ "$output" == *"JUDGMENT_API_URL=http://localhost:$PORT/v1/systemone"* ]]
  # health-waited: the listener must already answer once up returns
  curl -fsS "http://127.0.0.1:$PORT/v1/models" >/dev/null
  # exactly one recipe process is tracked
  [ "$(count_pids)" -eq 1 ]
  # teardown
  run bash "$SCRIPT" down
  assert_exit_code 0 "$status"
}

@test "AC-029-31: up is idempotent when the server already runs (no duplicate process)" {
  run bash "$SCRIPT" up
  assert_exit_code 0 "$status"
  local pid1; pid1="$(cat "$JUDGMENT_LOCAL_RUN_DIR"/*.pid | head -1)"
  run bash "$SCRIPT" up
  assert_exit_code 0 "$status"
  [[ "$output" == *"JUDGMENT_BACKEND=local"* ]]
  [ "$(count_pids)" -eq 1 ]
  local pid2; pid2="$(cat "$JUDGMENT_LOCAL_RUN_DIR"/*.pid | head -1)"
  [ "$pid1" = "$pid2" ]
  # and only one OS process: no second python listener
  [ "$(pgrep -f "mock_server.py $PORT" | wc -l)" -eq 1 ]
  bash "$SCRIPT" down >/dev/null
}

@test "AC-029-32: down stops the server and removes the PID file" {
  bash "$SCRIPT" up >/dev/null
  run bash "$SCRIPT" down
  assert_exit_code 0 "$status"
  [ "$(count_pids)" -eq 0 ]
  run pgrep -f "mock_server.py $PORT"
  [ "$status" -ne 0 ]
}

@test "AC-029-33: down when nothing runs is idempotent and reports not running" {
  run --separate-stderr bash "$SCRIPT" down
  assert_exit_code 0 "$status"
  [[ "$output$stderr" == *"not running"* ]]
}

@test "AC-029-34: status prints running with PID and port, or stopped, both exit 0" {
  bash "$SCRIPT" up >/dev/null
  run bash "$SCRIPT" status
  assert_exit_code 0 "$status"
  [[ "$output" == *"running"* ]]
  [[ "$output" == *"$PORT"* ]]
  grep -qE 'running \(pid [0-9]+' <<< "$output"
  bash "$SCRIPT" down >/dev/null
  run bash "$SCRIPT" status
  assert_exit_code 0 "$status"
  [[ "$output" == *"stopped"* ]]
}

@test "AC-029-35: health times out when nothing listens; exit non-zero, stderr reports timeout" {
  export JUDGMENT_LOCAL_TIMEOUT_SECONDS=2
  # stop any listener: none was started in this test; use a port nobody holds
  run --separate-stderr bash "$SCRIPT" health
  assert_exit_code 1 "$status"
  [[ "$stderr" == *"timeout"* ]]
}

@test "AC-029-35b: health exits 0 when the endpoint answers" {
  bash "$SCRIPT" up >/dev/null
  run bash "$SCRIPT" health
  assert_exit_code 0 "$status"
  bash "$SCRIPT" down >/dev/null
}

@test "AC-029-36: refuses to run as root (UID 0) with a diagnostic" {
  # fake id(1) on PATH returning 0 — exercises the guard without real root
  cat > "$BIN/id" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = "-u" ]; then echo 0; exit 0; fi
exec /usr/bin/id "$@"
SH
  chmod +x "$BIN/id"
  run --separate-stderr env PATH="$BIN:$PATH" bash "$SCRIPT" up
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"root"* ]]
}

@test "AC-029-37: logs and PID files live in the gitignored run dir" {
  local pre post
  pre=$(git -C "$REPO_ROOT" status --porcelain)
  bash "$SCRIPT" up >/dev/null
  [ -d "$JUDGMENT_LOCAL_RUN_DIR" ]
  [ "$(count_pids)" -eq 1 ]
  # a log file exists for the server process
  ls "$JUDGMENT_LOCAL_RUN_DIR"/*.log >/dev/null
  bash "$SCRIPT" down >/dev/null
  # the repo-default run dir is gitignored (Task 3: .cache/judgment/)
  git -C "$REPO_ROOT" check-ignore -q .cache/judgment/kev.pid
  # the up/down cycle created nothing in the repo tree outside .cache/:
  # the tracked-file status is identical before and after
  post=$(git -C "$REPO_ROOT" status --porcelain)
  [ "$pre" = "$post" ]
}

@test "unit: stale PID file (process gone) is cleaned by status and reports stopped" {
  mkdir -p "$JUDGMENT_LOCAL_RUN_DIR"
  # a PID that cannot be ours: sleep 0.01 then die
  sleep 0.05 & local dead=$!
  kill "$dead" 2>/dev/null; wait "$dead" 2>/dev/null || true
  echo "$dead" > "$JUDGMENT_LOCAL_RUN_DIR/kev.pid"
  run bash "$SCRIPT" status
  assert_exit_code 0 "$status"
  [[ "$output" == *"stopped"* ]]
  [ ! -f "$JUDGMENT_LOCAL_RUN_DIR/kev.pid" ]
}

@test "unit: stale PID file (process gone) is cleaned by down without error" {
  mkdir -p "$JUDGMENT_LOCAL_RUN_DIR"
  echo 999999 > "$JUDGMENT_LOCAL_RUN_DIR/kev.pid"
  run --separate-stderr bash "$SCRIPT" down
  assert_exit_code 0 "$status"
  [[ "$output$stderr" == *"not running"* ]]
  [ ! -f "$JUDGMENT_LOCAL_RUN_DIR/kev.pid" ]
}

@test "AC-029-38: Makefile targets judgment-up and judgment-down invoke the script" {
  grep -qE '^judgment-up:.*' "$REPO_ROOT/Makefile"
  grep -qE '^judgment-down:.*' "$REPO_ROOT/Makefile"
  grep -A2 '^judgment-up:' "$REPO_ROOT/Makefile" | grep -q 'scripts/judgment-local-up.sh up'
  grep -A2 '^judgment-down:' "$REPO_ROOT/Makefile" | grep -q 'scripts/judgment-local-up.sh down'
}

@test "unit: unknown subcommand is a usage error" {
  run --separate-stderr bash "$SCRIPT" bogus
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"usage"* ]]
}

@test "unit: up kills its own process and fails cleanly when health never answers" {
  # point the command at a listener that never serves (crash immediately)
  export JUDGMENT_LOCAL_TIMEOUT_SECONDS=2
  export JUDGMENT_LOCAL_UP_CMD="python3 -c 'import sys; sys.exit(0)'"
  run bash "$SCRIPT" up
  [ "$status" -ne 0 ]
  [ "$(count_pids)" -eq 0 ]
}

# ── Spec 029 post-archive amendment: 16GB-VRAM OOM hardening ─────────────────
# Two live-machine defects, each pinned by a unit test (the amendment record
# is appended to docs/changes/029-local-judgment-backend.md by the Verifier):
# (1) plain `make judgment-up` OOM-crashed the Kev server during CUDA-graph
# buffer prealloc on the 16GB card — the fix default-exports
# PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True, overridable;
# (2) the health wait could not distinguish "slow" from "crashed" and burned
# the full timeout polling a dead process — the fix fail-fasts, dumps the log
# tail, and cleans up.

# env_probe_server — recipe command that records the value the server process
# actually received into its log, then serves health like the normal mock.
env_probe_server() {
  cat > "$TMPDIR_HELPER/env_probe.sh" <<'SH'
#!/usr/bin/env bash
printf 'ALLOC_PROBE[%s]\n' "${PYTORCH_CUDA_ALLOC_CONF-<unset>}"
exec python3 "$@"
SH
  export JUDGMENT_LOCAL_UP_CMD="bash $TMPDIR_HELPER/env_probe.sh $TMPDIR_HELPER/mock_server.py $PORT"
}

@test "unit: up default-exports PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True to the server" {
  # setup() guarantees PYTORCH_CUDA_ALLOC_CONF is unset here — the default applies
  env_probe_server
  run bash "$SCRIPT" up
  assert_exit_code 0 "$status"
  bash "$SCRIPT" down >/dev/null
  grep -qF 'ALLOC_PROBE[expandable_segments:True]' "$JUDGMENT_LOCAL_RUN_DIR/kev.log"
}

@test "unit: a pre-set PYTORCH_CUDA_ALLOC_CONF reaches the server unchanged (override respected)" {
  env_probe_server
  export PYTORCH_CUDA_ALLOC_CONF="max_split_size_mb:128,expandable_segments:False"
  run bash "$SCRIPT" up
  assert_exit_code 0 "$status"
  bash "$SCRIPT" down >/dev/null
  grep -qF 'ALLOC_PROBE[max_split_size_mb:128,expandable_segments:False]' "$JUDGMENT_LOCAL_RUN_DIR/kev.log"
}

@test "unit: up fail-fasts when the server process dies — exits before the timeout, dumps the log tail, cleans PID files" {
  # Mock "server" that crashes immediately, printing an OOM-style traceback to
  # its log (repro of the live 16GB-card failure). The health timeout is set
  # far above the crash-detection time so the elapsed assertion can only pass
  # via the early-exit branch, never by completing the poll loop.
  cat > "$TMPDIR_HELPER/crasher.sh" <<'SH'
#!/usr/bin/env bash
echo "torch.OutOfMemoryError: CUDA out of memory. Tried to allocate 1.00 GiB. GPU 0 has a total capacity of 15.99 GiB (fake repro traceback)" >&2
exit 1
SH
  export JUDGMENT_LOCAL_UP_CMD="bash $TMPDIR_HELPER/crasher.sh"
  export JUDGMENT_LOCAL_TIMEOUT_SECONDS=30
  local t0 t1
  t0=$(date +%s)
  run --separate-stderr bash "$SCRIPT" up
  t1=$(date +%s)
  assert_exit_code 1 "$status"
  [ $((t1 - t0)) -lt "$JUDGMENT_LOCAL_TIMEOUT_SECONDS" ]
  # early-exit branch, not the timeout path: the timeout message must not appear
  [[ "$stderr" != *"timeout"* ]]
  # clear error naming the dead server and the log path, plus the log tail so
  # the traceback surfaces without digging
  [[ "$stderr" == *"server process died"* ]]
  [[ "$stderr" == *"last 15 lines"* ]]
  [[ "$stderr" == *"OutOfMemoryError"* ]]
  # teardown reused: PID files cleaned, nothing left tracked
  [ "$(count_pids)" -eq 0 ]
}
