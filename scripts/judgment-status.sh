#!/usr/bin/env bash
# judgment-status.sh — operator surface for the optional local judgment
# backend (spec 034; see docs/SPEC_PIPELINE.md §Typed-judgment layer and
# ADR 0014). `make judgment-status` wires this script.
#
# Reports liveness AND payload fitness — a backend can be alive on
# /v1/models and still fail on a full-size state, which is exactly the
# failure mode the payload cap exists for.
#
#   liveness   reuse the judgment-local-up.sh status signal (PID files in
#              ${JUDGMENT_LOCAL_RUN_DIR:-<repo root>/.cache/judgment}); prints
#              "running (pid <n>, port <p>)" or "stopped".
#   fitness    two probes through scripts/typed-judgment.sh:
#                1. a small synthetic Choice request (state <= 1 KB)
#                2. a max-size request whose state is exactly the payload cap
#                   (JUDGMENT_MAX_STATE_BYTES, default 12288 bytes)
#              Both use the bounded probe from scripts/judgment-lib.sh — the
#              same call shape and synthetic question the preflight uses.
#
# Exit codes: 0 when liveness says running AND both probes pass; 1 when the
# backend is stopped or either probe fails. A failing probe is reported, never
# propagated as a script crash. Read-only: starts and stops nothing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WRAPPER="$SCRIPT_DIR/typed-judgment.sh"
LOCAL_UP="$SCRIPT_DIR/judgment-local-up.sh"
# shellcheck source=judgment-lib.sh
source "$SCRIPT_DIR/judgment-lib.sh"

# An invalid or non-positive JUDGMENT_MAX_STATE_BYTES is not a usage error
# here: this script reports, it never refuses to run. It falls back to the
# wrapper's own default, which the lib owns.
CAP="${JUDGMENT_MAX_STATE_BYTES:-$JUDGMENT_CAP_DEFAULT_BYTES}"
judgment_positive_int "$CAP" || CAP="$JUDGMENT_CAP_DEFAULT_BYTES"

SMALL_STATE='{"probe":"judgment-status","stage":"small","payload":"small synthetic judgment call"}'

# liveness_pid_port <judgment-local-up.sh status text> — echoes "<pid> <port>"
# for a running backend, nothing when stopped. One regex: the two fields are
# read from one match instead of parsing the line twice.
liveness_pid_port() {
  printf '%s\n' "$1" \
    | sed -n 's/.*running (pid \([0-9][0-9]*\), port \([0-9][0-9]*\)).*/\1 \2/p' \
    | head -1
}

# liveness_report — echo "running (pid <n>, port <p>)" or "stopped"; returns 0
# when running, 1 when stopped. The PID-file signal is the same one
# judgment-local-up.sh status uses.
liveness_report() {
  local pid="" port=""
  read -r pid port <<< "$(liveness_pid_port "$(bash "$LOCAL_UP" status 2>/dev/null || true)")" || true
  [ -n "$pid" ] || { printf 'stopped\n'; return 1; }
  printf 'running (pid %s, port %s)\n' "$pid" "${port:-unknown}"
}

report_probe() { # $1 = label, $2 = state byte count, $3 = rc, $4 = reason
  if [ "$3" -eq 0 ]; then
    printf '%s (state %s bytes): pass\n' "$1" "$2"
  else
    printf '%s (state %s bytes): fail (reason=%s)\n' "$1" "$2" "$4"
  fi
}

main() {
  local running=false
  if liveness_report; then running=true; fi

  # A spent daily cap must not make the operator surface report a false
  # failure: both probes run cap-free (empty means "no cap" to the wrapper).
  JUDGMENT_DAILY_CAP=""

  local small_state small_rc max_state max_rc
  small_state="$SMALL_STATE"
  judgment_run_probe "$WRAPPER" "$(judgment_probe_questions)" "$small_state"
  small_rc="$JUDGMENT_PROBE_RC"
  report_probe "small probe" "$(judgment_byte_len "$small_state")" "$small_rc" "$JUDGMENT_PROBE_REASON"

  max_state="$(head -c "$CAP" /dev/zero | tr '\0' 'x')"
  judgment_run_probe "$WRAPPER" "$(judgment_probe_questions)" "$max_state"
  max_rc="$JUDGMENT_PROBE_RC"
  report_probe "max probe" "$(judgment_byte_len "$max_state")" "$max_rc" "$JUDGMENT_PROBE_REASON"

  if [ "$running" = true ] && [ "$small_rc" -eq 0 ] && [ "$max_rc" -eq 0 ]; then
    exit 0
  fi
  exit 1
}

main "$@"
