#!/usr/bin/env bash
# judgment-local-up.sh — start/stop/status/health for the local judgment
# backend recipe selected by the spec 029 hardware spike. Parameterized by the
# spike report (35-spike-report.md, archived to docs/changes/029-local-
# judgment-backend.md): serving command, port, health endpoint, process count.
#
# Subcommands:
#   up      Start the recipe's process(es), wait (bounded) for the health
#           endpoint, print the JUDGMENT_* env lines for the per-machine env
#           file. Idempotent when already running and healthy. Fails fast
#           (non-zero, log tail on stderr) if a server process dies during
#           the wait instead of burning the full timeout.
#   down    Stop every process started by `up`; remove PID files. Idempotent
#           when nothing is running.
#   status  Print "running (pid <n>, port <p>)" or "stopped". Always exit 0.
#   health  Poll the health endpoint; exit 0 when healthy, 1 on timeout
#           (JUDGMENT_LOCAL_TIMEOUT_SECONDS, default 120).
#
# Run-state (PID files + logs) lives in a gitignored directory (OQ-029-04
# ruling: one PID file per process; stale files cleaned on status/down):
#   ${JUDGMENT_LOCAL_RUN_DIR:-<repo root>/.cache/judgment}
# Model/package downloads go to the tools' own caches (HF default
# ~/.cache/huggingface, uv default), never into the repo tree (spec 029 Task 3).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Recipe parameters — values cited from the spike report ───────────────────
# §Install steps: the winning recipe builds a uv environment from the backend
# repo clone. Default clone location is outside the repo; downloads land in
# tool caches only.
JUDGMENT_KEV_DIR="${JUDGMENT_KEV_DIR:-$HOME/.local/share/judgment-local/kev}"
# §Serving recipe: exact serving command (single process), port, health probe
# path, and the API path typed-judgment.sh posts to.
JUDGMENT_LOCAL_PORT="${JUDGMENT_LOCAL_PORT:-8009}"
JUDGMENT_LOCAL_HEALTH_PATH="${JUDGMENT_LOCAL_HEALTH_PATH:-/v1/models}"
JUDGMENT_LOCAL_API_PATH="${JUDGMENT_LOCAL_API_PATH:-/v1/systemone}"
JUDGMENT_LOCAL_HEALTH_HOST="127.0.0.1"
JUDGMENT_LOCAL_UP_CMD="${JUDGMENT_LOCAL_UP_CMD:-uv run --extra serve python -m kev.serve --run jaredpalmer/kev-4b --port $JUDGMENT_LOCAL_PORT}"
# §Serving recipe — process count: this recipe runs ONE process; its PID file
# name is the process name (OQ-029-04: per-process PID files; a two-process
# CLM recipe would list "encoder clm-serve" here).
JUDGMENT_LOCAL_PROCESSES="${JUDGMENT_LOCAL_PROCESSES:-kev}"
# §Recipe ops notes: first load downloads the weights and warms the model; the
# bounded health-wait budget for `up` (overridable; `health` uses the same).
JUDGMENT_LOCAL_TIMEOUT_SECONDS="${JUDGMENT_LOCAL_TIMEOUT_SECONDS:-120}"
JUDGMENT_LOCAL_RUN_DIR="${JUDGMENT_LOCAL_RUN_DIR:-$REPO_ROOT/.cache/judgment}"

die() { echo "judgment-local-up: $*" >&2; exit 1; }
info() { echo "judgment-local-up: $*"; }

refuse_root() {
  if [ "$(id -u)" -eq 0 ]; then
    die "refusing to run as root; run the local judgment backend as your normal user (model caches and PID files are per-user)"
  fi
}

pid_file() { printf '%s/%s.pid\n' "$JUDGMENT_LOCAL_RUN_DIR" "$1"; }
log_file() { printf '%s/%s.log\n' "$JUDGMENT_LOCAL_RUN_DIR" "$1"; }

health_url() { printf 'http://%s:%s%s\n' "$JUDGMENT_LOCAL_HEALTH_HOST" "$JUDGMENT_LOCAL_PORT" "$JUDGMENT_LOCAL_HEALTH_PATH"; }

api_url() { printf 'http://localhost:%s%s\n' "$JUDGMENT_LOCAL_PORT" "$JUDGMENT_LOCAL_API_PATH"; }

pid_alive() { [ -n "$1" ] && kill -0 "$1" 2>/dev/null; }

child_pids() { # $1 = pid; direct children, one per line (empty when none)
  pgrep -P "$1" 2>/dev/null || true
}

kill_group() { # $1 = signal, $2 = leader pid, $3 = child pids (space-separated)
  local sig="$1" pid="$2" kids="$3"
  [ -n "$kids" ] && kill -"$sig" $kids 2>/dev/null
  kill -"$sig" "$pid" 2>/dev/null
}

wait_for_exit() { # $1 = pid; bounded (~4s) poll for the leader to exit
  local n=0
  while pid_alive "$1" && [ "$n" -lt 20 ]; do sleep 0.2; n=$((n + 1)); done
}

force_kill_survivors() { # $1 = child pids; -9 any that outlived the leader
  local c
  for c in $1; do pid_alive "$c" && kill -9 "$c" 2>/dev/null; done
}

term_tree() { # $1 = pid; TERM the process and its children, then -9 after grace
  # Needed because the recipe launcher (`uv run`) waits on its python child
  # instead of exec-ing it: the tracked PID alone is not the server process
  # (spike report §Recipe ops notes).
  local pid="$1" kids
  kids="$(child_pids "$pid")"
  kill_group TERM "$pid" "$kids"
  wait_for_exit "$pid"
  if pid_alive "$pid"; then kill_group KILL "$pid" "$kids"; fi
  force_kill_survivors "$kids"
  return 0
}

# read_pid <name> — echo the tracked pid or ""; removes a stale PID file.
read_pid() {
  local f pid
  f="$(pid_file "$1")"
  [ -f "$f" ] || { echo ""; return 0; }
  pid="$(cat "$f" 2>/dev/null || echo "")"
  if [ -z "$pid" ] || ! pid_alive "$pid"; then
    rm -f "$f"
    echo ""
    return 0
  fi
  echo "$pid"
}

healthy_now() { curl -fsS --max-time 5 "$(health_url)" >/dev/null 2>&1; }

# tracked_processes_alive — 0 while every tracked recipe PID is alive; a
# missing or dead PID file counts as dead. Reads the PID files without
# removing them (teardown stays stop_tracked's job). Spec 029 amendment:
# lets `up` tell "slow" apart from "crashed" instead of burning the health
# budget polling a dead process (live repro: the 16GB-card torch OOM killed
# the server in seconds, the old loop waited the full 120s).
tracked_processes_alive() {
  local p pid
  for p in $JUDGMENT_LOCAL_PROCESSES; do
    pid="$(cat "$(pid_file "$p")" 2>/dev/null)" || return 1
    pid_alive "$pid" || return 1
  done
  return 0
}

# health_wait <seconds> [watch] — bounded poll for the health endpoint.
# With "watch" (used by `up` only), returns 2 as soon as a tracked recipe
# process has died: a crashed server can never become healthy, so waiting
# is wasted time. Return 1 = timeout, unchanged. The standalone `health`
# subcommand omits watch (AC-029-35 timeout contract untouched).
health_wait() {
  local deadline=$(( $(date +%s) + $1 )) watch="${2:-}"
  while [ "$(date +%s)" -lt "$deadline" ]; do
    healthy_now && return 0
    if [ -n "$watch" ] && ! tracked_processes_alive; then return 2; fi
    sleep 1
  done
  return 1
}

ensure_recipe_installed() {
  # Idempotent bootstrap of the winning recipe (spike §Install steps). Skipped
  # when the serve command was overridden (tests) or the clone already exists.
  case "$JUDGMENT_LOCAL_UP_CMD" in
    *uv\ run\ --extra\ serve*) ;;  # default recipe below needs the clone
    *) return 0 ;;                 # custom command (tests/other hosts): no bootstrap
  esac
  if [ ! -d "$JUDGMENT_KEV_DIR/.venv" ]; then
    info "installing recipe into $JUDGMENT_KEV_DIR (clone + uv sync; downloads go to tool caches)"
    mkdir -p "$(dirname "$JUDGMENT_KEV_DIR")"
    [ -d "$JUDGMENT_KEV_DIR/.git" ] || git clone --depth 1 https://github.com/jaredpalmer/kev.git "$JUDGMENT_KEV_DIR" >&2
    ( cd "$JUDGMENT_KEV_DIR" && uv sync --extra serve ) >&2
  fi
}

print_env_lines() {
  # The exact lines to add to the gitignored per-machine env file
  # (config/model.local.env). Values per spike report §Serving recipe and
  # §Recommended confidence threshold.
  echo "JUDGMENT_BACKEND=local"
  echo "JUDGMENT_API_URL=$(api_url)"
  echo "# optional (local backend serves open by default; no key required):"
  echo "#   JUDGMENT_API_KEY=<key>   only if the server was configured with KEV_API_KEY"
  echo "#   JUDGMENT_MODEL unset     -> the script sends the backend default alias (spike §Serving recipe)"
  echo "#   JUDGMENT_MIN_CONFIDENCE=0.28   recalibrated for this backend (spike §Recommended confidence threshold)"
}

process_count() { # number of processes declared by the recipe
  local -a p=($JUDGMENT_LOCAL_PROCESSES)
  printf '%s\n' "${#p[@]}"
}

count_running() { # number of recipe processes with a live tracked pid
  local p n=0
  for p in $JUDGMENT_LOCAL_PROCESSES; do
    [ -n "$(read_pid "$p")" ] && n=$((n + 1))
  done
  printf '%s\n' "$n"
}

start_process() { # $1 = process name; background the recipe command, track its leader pid
  local p="$1"
  info "starting $p (log: $(log_file "$p"))"
  # Spec 029 amendment (live repro on a 16GB-VRAM card, RTX 5060 Ti): plain
  # `make judgment-up` crashed the Kev server with torch.OutOfMemoryError
  # during CUDA-graph buffer prealloc (~1GB) — desktop VRAM baseline (~2.4GB)
  # + weights (~10.8GB) + allocator fragmentation exceeded the card. torch's
  # own error suggests the remedy: expandable_segments defeats the
  # fragmentation failure (confirmed: with it set the server starts healthy
  # and judgments are correct on this machine). Default-exported here so the
  # child inherits it; a pre-set value wins untouched (${VAR:-default}).
  export PYTORCH_CUDA_ALLOC_CONF="${PYTORCH_CUDA_ALLOC_CONF:-expandable_segments:True}"
  # The tracked pid is the backgrounded leader; the recipe launcher
  # (`uv run`) waits on its python child instead of exec-ing it, so
  # teardown kills the whole tree via term_tree (spike report §Recipe ops
  # notes). The clone dir is embedded quoted (%q) — no env forwarding.
  nohup bash -c "cd $(printf '%q' "$JUDGMENT_KEV_DIR") && exec $JUDGMENT_LOCAL_UP_CMD" \
    >>"$(log_file "$p")" 2>&1 < /dev/null &
  echo $! > "$(pid_file "$p")"
  [ -s "$(pid_file "$p")" ] || die "failed to write PID file for $p"
}

stop_tracked() { # stop every tracked process and remove its PID files (silent teardown)
  local p pid
  for p in $JUDGMENT_LOCAL_PROCESSES; do
    pid="$(read_pid "$p")"
    [ -n "$pid" ] && term_tree "$pid"
    rm -f "$(pid_file "$p")"
  done
}

report_startup_crash() { # crash-path diagnostic: name the log, dump its last
  # ~15 lines so OOM tracebacks surface without digging (spec 029 amendment)
  local log
  log="$(log_file "${JUDGMENT_LOCAL_PROCESSES%% *}")"
  echo "judgment-local-up: server process died during health wait (crashed, not slow) — log: $log" >&2
  echo "judgment-local-up: last 15 lines of $log:" >&2
  [ -f "$log" ] && tail -n 15 "$log" >&2
  return 0
}

wait_healthy_or_stop() { # bounded health wait; on crash or timeout stop everything and die
  info "waiting up to ${JUDGMENT_LOCAL_TIMEOUT_SECONDS}s for health at $(health_url)"
  local rc=0
  health_wait "$JUDGMENT_LOCAL_TIMEOUT_SECONDS" watch || rc=$?
  [ "$rc" -eq 0 ] && return 0
  stop_tracked   # reused for both branches: PID files removed, processes stopped
  if [ "$rc" -eq 2 ]; then
    report_startup_crash
    exit 1
  fi
  die "health wait timeout after ${JUDGMENT_LOCAL_TIMEOUT_SECONDS}s (server never answered on $(health_url)); processes stopped, PID files removed — see $(log_file "${JUDGMENT_LOCAL_PROCESSES%% *}")"
}

reset_partial_startup() { # partial state: stop what is tracked, then start clean
  info "partial startup state detected — resetting"
  cmd_down || true
}

cmd_up() {
  refuse_root
  mkdir -p "$JUDGMENT_LOCAL_RUN_DIR"
  local running; running="$(count_running)"
  if [ "$running" -eq "$(process_count)" ] && healthy_now; then
    info "already running and healthy — no duplicate started"
    print_env_lines
    return 0
  fi
  if [ "$running" -gt 0 ]; then
    reset_partial_startup
  fi
  ensure_recipe_installed
  local p
  for p in $JUDGMENT_LOCAL_PROCESSES; do start_process "$p"; done
  wait_healthy_or_stop
  info "healthy"
  print_env_lines
}

cmd_down() {
  refuse_root
  local p pid stopped=0
  for p in $JUDGMENT_LOCAL_PROCESSES; do
    pid="$(read_pid "$p")"   # removes stale files itself
    if [ -z "$pid" ]; then
      info "$p: not running"
      continue
    fi
    term_tree "$pid"
    rm -f "$(pid_file "$p")"
    info "$p: stopped (pid $pid)"
    stopped=1
  done
  if [ "$stopped" -eq 0 ]; then info "server not running"; fi
  return 0
}

cmd_status() {
  refuse_root
  mkdir -p "$JUDGMENT_LOCAL_RUN_DIR"
  if [ "$(count_running)" -gt 0 ]; then
    local p pid
    for p in $JUDGMENT_LOCAL_PROCESSES; do
      pid="$(read_pid "$p")"
      [ -n "$pid" ] && echo "$p: running (pid $pid, port $JUDGMENT_LOCAL_PORT)"
    done
  else
    echo "stopped"
  fi
  return 0
}

cmd_health() {
  refuse_root
  if health_wait "$JUDGMENT_LOCAL_TIMEOUT_SECONDS"; then
    info "healthy ($(health_url))"
    return 0
  fi
  echo "judgment-local-up: health check timeout after ${JUDGMENT_LOCAL_TIMEOUT_SECONDS}s (no answer from $(health_url))" >&2
  exit 1
}

usage() {
  echo "usage: judgment-local-up.sh {up|down|status|health}" >&2
  exit 2
}

main() {
  [ "$#" -eq 1 ] || usage
  case "$1" in
    up) cmd_up ;;
    down) cmd_down ;;
    status) cmd_status ;;
    health) cmd_health ;;
    *) usage ;;
  esac
}

main "$@"
