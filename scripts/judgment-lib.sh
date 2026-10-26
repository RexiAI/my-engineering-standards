#!/bin/bash
# judgment-lib.sh — shared helpers for the optional typed-judgment layer
# (spec 034). Sourced-only (never executed directly): sets no shell flags and
# no state beyond one data default, so the sourcing script's own
# `set -euo pipefail` governs — the scripts/check-common.sh and
# scripts/model-env.vars.sh model.
#
# Why a lib: three scripts speak the wrapper's contract, and each piece of that
# contract has exactly one reason to change.
#   scripts/typed-judgment.sh     wrapper — emits the reason lines, owns cap math
#   scripts/judgment-preflight.sh consumer — bounded probe, parses the reason
#   scripts/judgment-status.sh    consumer — bounded probe, parses the reason
# A change to the reason-line format, the probe's bounding (timeout, backoff,
# confidence threshold), the payload-cap default, or the synthetic fitness
# question must not need three edits that can drift apart.
#
# Sourcing: callers source it right after their SCRIPT_DIR/REPO_ROOT block, e.g.
#   source "$SCRIPT_DIR/judgment-lib.sh"

# Payload cap default in bytes (docs/SPEC_PIPELINE.md §Typed-judgment layer).
# The fitness probes measure the backend AT this cap, so they must agree with
# the wrapper on the number instead of restating it.
JUDGMENT_CAP_DEFAULT_BYTES=12288

# judgment_byte_len <string> — byte count, whitespace-stripped for arithmetic.
judgment_byte_len() { printf '%s' "$1" | wc -c | tr -d '[:space:]'; }

# judgment_emit_reason <reason-word> — the one machine-readable degradation
# line every consumer greps for. Never debug-gated; never carries the API key
# or the state content.
judgment_emit_reason() { printf 'typed-judgment: reason=%s\n' "$1" >&2; }

# judgment_reason_from_stderr <captured-stderr> — the reason word the wrapper
# wrote, or 'error' when it wrote none (a crash, a usage exit 2).
judgment_reason_from_stderr() {
  local reason
  reason="$(printf '%s\n' "$1" | sed -n 's/^typed-judgment: reason=//p' | head -1)"
  printf '%s' "${reason:-error}"
}

# judgment_positive_int <value> — succeeds when the value is a positive integer.
# Each caller keeps its own error wording: the message carries the script name
# its operator will look for.
judgment_positive_int() {
  case "$1" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -gt 0 ]
}

# judgment_probe_questions — the synthetic Choice question both fitness probes
# ask. One literal: the preflight and `make judgment-status` measure the same
# thing, so they must ask the same thing.
judgment_probe_questions() {
  printf '%s' '{"fitness":{"type":"choice","instructions":"Answer yes to confirm the inference path works.","criteria":{"yes":"the backend answered this synthetic fitness probe","no":"the backend did not answer"},"options":["yes","no"]}}'
}

# judgment_run_probe <wrapper> <questions-json> <state> [cap-bytes]
# One bounded fitness call through the wrapper: 5 s timeout, no backoff (a
# single attempt), confidence threshold 0 — the probe measures reachability,
# inference and payload fitness, not the calibration of one synthetic question.
# The wrapper's stderr is captured so the consumer can print exactly one line.
# cap empty/absent -> no --max-state-bytes flag (the wrapper's own default).
#
# Sets, for the caller:
#   JUDGMENT_PROBE_RC      the wrapper's exit code (0 or 10)
#   JUDGMENT_PROBE_REASON  its reason word, or 'error' when it wrote none
#
# ${args[@]+"${args[@]}"} rather than "${args[@]}": bash 3.2 with `set -u`
# treats an empty array expansion as an unbound variable.
judgment_run_probe() {
  local wrapper="$1" questions="$2" state="$3" cap="${4:-}"
  local -a args=()
  [ -z "$cap" ] || args=(--max-state-bytes "$cap")
  local err rc=0
  err="$(JUDGMENT_TIMEOUT_SECONDS=5 JUDGMENT_BACKOFF_SECONDS=0 JUDGMENT_MIN_CONFIDENCE=0 \
    bash "$wrapper" --questions "$questions" ${args[@]+"${args[@]}"} <<< "$state" \
    2>&1 >/dev/null)" || rc=$?
  JUDGMENT_PROBE_RC="$rc"
  JUDGMENT_PROBE_REASON="$(judgment_reason_from_stderr "$err")"
}
