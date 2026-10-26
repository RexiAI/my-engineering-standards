#!/usr/bin/env bash
# judgment-preflight.sh — bounded, fail-open fitness probe for the optional
# local typed-judgment backend (spec 034; see docs/SPEC_PIPELINE.md
# §Typed-judgment layer and ADR 0012).
#
# Run as the first action of /spec and /build, before any delegation. It is
# silent when the local backend is not configured (JUDGMENT_BACKEND != local,
# or JUDGMENT_API_URL unset/empty) — the hosted path and the unconfigured
# machine behave exactly as before.
#
# When the local backend IS configured, it makes ONE fitness probe through
# scripts/typed-judgment.sh with a synthetic state (well under 1 KB) and
# exactly one Choice question. That exercises the inference path, not a bare
# /v1/models liveness ping, so a backend that is up but cannot answer is
# caught. The probe is bounded: JUDGMENT_TIMEOUT_SECONDS=5 and
# JUDGMENT_BACKOFF_SECONDS=0 (one attempt, no sleeps). The probe also sets
# JUDGMENT_MIN_CONFIDENCE=0: it measures reachability + inference + payload
# fitness, not the calibration of one synthetic question (a real backend can
# answer correctly below the production threshold). The bounded call, the
# reason-line parse and the synthetic question live in scripts/judgment-lib.sh,
# shared with scripts/judgment-status.sh (spec 034).
#
# Fail-open contract:
#   healthy probe (exit 0)  -> one stdout line containing "healthy"; exit 0.
#   failed probe            -> exactly one stderr warning line containing
#                              "make judgment-up", "continuing without", and
#                              the wrapper-reported reason; exit 0.
#   --require-judgment or JUDGMENT_REQUIRED=1 -> the same warning, but exit 1
#                              instead of 0. Strictness is opt-in.
#
# Cache: the outcome is cached in ${JUDGMENT_CAP_DIR:-<repo root>/.cache}/
# judgment-preflight as "<epoch-seconds> <healthy|unreachable>" (a third
# "<reason>" field is appended for an unhealthy outcome). A run younger than
# JUDGMENT_PREFLIGHT_TTL_SECONDS (default 300) reuses the cached outcome
# without probing; --force re-probes. This realizes "once per invocation" for
# /build's several stages.
#
# Usage:
#   scripts/judgment-preflight.sh [--require-judgment] [--force]
#       [--max-state-bytes <N>]
#
# Exit codes: 0 healthy or fail-open warning; 1 failed probe under strict
# mode; 2 usage error.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
WRAPPER="$SCRIPT_DIR/typed-judgment.sh"
# shellcheck source=judgment-lib.sh
source "$SCRIPT_DIR/judgment-lib.sh"

TTL_DEFAULT=300
CACHE_DIR="${JUDGMENT_CAP_DIR:-$REPO_ROOT/.cache}"
CACHE_FILE="$CACHE_DIR/judgment-preflight"

PROBE_STATE='{"probe":"judgment-preflight","stage":"fitness","payload":"small synthetic judgment call"}'

REQUIRE=false
FORCE=false
MAX_STATE_BYTES=""

usage_error() { echo "judgment-preflight: $*" >&2; exit 2; }

validate_positive_int() { # $1 = value, $2 = label
  judgment_positive_int "$1" || usage_error "$2 must be a positive integer, got: '$1'"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --require-judgment|--force) set_bool_flag "$1"; shift ;;
      --max-state-bytes) take_max_state_bytes "$@"; shift 2 ;;
      *) usage_error "unknown argument: $1" ;;
    esac
  done
}

# set_bool_flag <flag> — the two booleans; the dispatcher matched the pair.
set_bool_flag() {
  case "$1" in
    --require-judgment) REQUIRE=true ;;
    --force) FORCE=true ;;
  esac
}

# take_max_state_bytes <flag> <value> — presence check only; the value is
# validated after the loop with every other argument, so an empty value keeps
# its documented "no cap flag" meaning.
take_max_state_bytes() {
  [ "$#" -ge 2 ] || usage_error "--max-state-bytes needs a positive integer"
  MAX_STATE_BYTES="$2"
}

validate_args() { # --max-state-bytes, when given, must be a positive integer
  [ -z "$MAX_STATE_BYTES" ] || validate_positive_int "$MAX_STATE_BYTES" "--max-state-bytes"
}

strict_enabled() {
  [ "$REQUIRE" = true ] && return 0
  [ "${JUDGMENT_REQUIRED:-}" = "1" ]
}

active_backend() {
  [ "${JUDGMENT_BACKEND:-}" = "local" ] && [ -n "${JUDGMENT_API_URL:-}" ]
}

cache_ttl() {
  local ttl="${JUDGMENT_PREFLIGHT_TTL_SECONDS:-$TTL_DEFAULT}"
  case "$ttl" in ''|*[!0-9]*) ttl="$TTL_DEFAULT" ;; esac
  printf '%s' "$ttl"
}

cache_fresh() {
  [ -f "$CACHE_FILE" ] || return 1
  local ts outcome reason now ttl
  read -r ts outcome reason < "$CACHE_FILE" || return 1
  case "$ts" in ''|*[!0-9]*) return 1 ;; esac
  now="$(date +%s)"
  ttl="$(cache_ttl)"
  [ $(( now - ts )) -lt "$ttl" ]
}

write_cache() { # $1 = healthy|unreachable, $2 = reason (empty when healthy)
  mkdir -p "$CACHE_DIR"
  if [ -n "${2:-}" ]; then
    printf '%s %s %s\n' "$(date +%s)" "$1" "$2" > "$CACHE_FILE"
  else
    printf '%s %s\n' "$(date +%s)" "$1" > "$CACHE_FILE"
  fi
}

# reuse_cached_outcome — a fresh cache entry answers without probing: healthy
# reports and exits 0, unhealthy replays its warning. An absent or stale entry
# returns so the caller probes.
reuse_cached_outcome() {
  cache_fresh || return 0
  local ts outcome reason
  read -r ts outcome reason < "$CACHE_FILE"
  [ "$outcome" = "healthy" ] || handle_unhealthy "${reason:-error}"
  report_healthy
}

report_healthy() {
  echo "judgment-preflight: healthy (local judgment backend answered the fitness probe)"
  exit 0
}

warn_unavailable() { # $1 = reason word
  printf 'judgment-preflight: local judgment backend unavailable (reason: %s) — continuing without the typed-judgment fast-path; run `make judgment-up` to start it\n' "$1" >&2
}

handle_unhealthy() { # $1 = reason word
  warn_unavailable "$1"
  if strict_enabled; then
    exit 1
  fi
  exit 0
}

main() {
  parse_args "$@"
  validate_args
  active_backend || exit 0
  [ "$FORCE" = true ] || reuse_cached_outcome
  judgment_run_probe "$WRAPPER" "$(judgment_probe_questions)" "$PROBE_STATE" "$MAX_STATE_BYTES"
  if [ "$JUDGMENT_PROBE_RC" -eq 0 ]; then
    write_cache healthy ""
    report_healthy
  fi
  write_cache unreachable "$JUDGMENT_PROBE_REASON"
  handle_unhealthy "$JUDGMENT_PROBE_REASON"
}

main "$@"
