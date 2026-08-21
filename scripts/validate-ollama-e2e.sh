#!/bin/bash
# validate-ollama-e2e.sh — Run a real spec-pipeline stage agent against
# ollama/qwen3.8:27b in a two-turn session, then prove the fix: no
# "no user query found" errors in the run's log slice and the thread retained
# across turns. Emits the machine-readable per-stage decision line that Task 4
# consumes. (spec 001-ollama-context, Task 3)
#
# Probe semantics (per 20-acceptance/AC-003-e2e-validation.md):
#   - Turn 1: `opencode run --agent <agent> -m ollama/qwen3.8:27b` with a task
#     whose prompt embeds a unique marker token.
#   - Turn 2: `opencode run -c --agent <agent> -m ollama/qwen3.8:27b` — a
#     follow-up referencing turn-1 content and asking for the marker (continues
#     the same session, testing thread retention across turns).
#   - After the run the script greps the log slice [offset, now] of
#     ~/.local/share/opencode/log/opencode.log for "no user query found"
#     attributed to modelID=qwen3.8:27b; any occurrence -> failure.
#   - Thread retention: the turn-2 final answer must contain the turn-1 marker.
#
# Decision line (AC-003-04/05): emitted to stdout and to --out <file>:
#   LOCAL_STAGES=<space-separated agent ids>
#   CLOUD_FALLBACK_STAGES=<space-separated agent ids>
# Default: all eight stage agents are LOCAL; the run's stage moves to
# CLOUD_FALLBACK_STAGES only when the evidence shows it fails (non-zero turn-2
# exit, a "no user query found" error in its log slice, or the marker dropped).
#
# Usage:
#   scripts/validate-ollama-e2e.sh [--out <file>] [--agent spec-specifier]
#       [--model ollama/qwen3.8:27b] [--log ~/.local/share/opencode/log/opencode.log]
#
# Exit codes:
#   0 — e2e passed, decision line emitted
#   1 — e2e failed (no-user-query-found in slice, or marker not retained)
#   2 — tooling failure: opencode unavailable, log unreadable, or --out missing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/check-common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/model-env.vars.sh"

OUT_FILE=""
AGENT="spec-specifier"
MODEL="ollama/qwen3.8:27b"
LOG="${HOME}/.local/share/opencode/log/opencode.log"

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_FILE="${2:-}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --agent) AGENT="${2:-spec-specifier}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --model) MODEL="${2:-ollama/qwen3.8:27b}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --log) LOG="${2:-}"; [ $# -gt 1 ] && shift 2 || shift ;;
    -h|--help) sed -n 's/^#   \(.*\)$/\1/p' "$0" | sed -n '/Usage:/,$p'; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
  esac
done

require_tools validate-ollama-e2e opencode grep sed tail wc date

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# ── Tooling / log preflight (AC-003-06): exit 2, never a clean run ───────────
if [ -z "$OUT_FILE" ]; then
  echo "ERROR: --out <file> is required (AC-003-04 decision file)" >&2
  exit 2
fi
if [ ! -r "$LOG" ]; then
  echo "ERROR: log '$LOG' is missing or unreadable (AC-003-06 tooling failure)" >&2
  exit 2
fi

# ── Log offset before the run (AC-003-02: the slice is [run start, now]) ─────
LOG_OFFSET="$(wc -l < "$LOG" | tr -d ' ')"

# ── The run: two turns, marker embedded in turn 1 ────────────────────────────
MARKER="MKT_E2E_$(date +%s)_$RANDOM"
TURN1_TASK="Answer briefly. Do NOT mention this token in your answer: $MARKER. Just reply OK."
TURN2_FOLLOWUP="Earlier I gave you a unique marker token but told you not to mention it. Now please reply with exactly that marker token and nothing else."

echo "== Turn 1: opencode run --agent $AGENT -m $MODEL =="
set +e
SPEC_SPECIFIER_MODEL="$MODEL" TURN1_OUT="$(opencode run --agent "$AGENT" -m "$MODEL" "$TURN1_TASK" --format json 2>&1)"
TURN1_RC=$?
set -e
echo "turn 1 exit: $TURN1_RC"

echo "== Turn 2: opencode run -c --agent $AGENT -m $MODEL (thread continuation) =="
set +e
SPEC_SPECIFIER_MODEL="$MODEL" TURN2_OUT="$(opencode run -c --agent "$AGENT" -m "$MODEL" "$TURN2_FOLLOWUP" --format json 2>&1)"
TURN2_RC=$?
set -e
echo "turn 2 exit: $TURN2_RC"

# ── Log slice grep for "no user query found" (AC-003-02) ─────────────────────
slice_fail="$(tail -n +"$((LOG_OFFSET + 1))" "$LOG" 2>/dev/null \
  | grep -F 'no user query found' \
  | grep -F 'qwen3.8:27b' || true)"

# ── Thread retention: turn-2 answer contains the marker (AC-003-03) ──────────
marker_retained=1
if printf '%s' "$TURN2_OUT" | grep -qF "$MARKER"; then
  marker_retained=0
fi

# ── Per-stage decision (AC-003-04/05) ────────────────────────────────────────
# Default: all eight stages LOCAL. The run's stage moves to CLOUD only on
# failure evidence: turn-2 non-zero exit, a "no user query found" in the slice,
# or the marker dropped.
LOCAL=("${MODEL_ENV_AGENTS[@]}")
CLOUD=()
stage_failed=0
if [ "$TURN2_RC" -ne 0 ]; then
  stage_failed=1
fi
if [ -n "$slice_fail" ]; then
  stage_failed=1
fi
if [ "$marker_retained" -eq 1 ]; then
  stage_failed=1
fi
if [ "$stage_failed" -eq 1 ]; then
  LOCAL=()
  CLOUD=("$AGENT")
  # The other stages default to LOCAL (no failure evidence for them, AC-003-05).
  for a in "${MODEL_ENV_AGENTS[@]}"; do
    [ "$a" = "$AGENT" ] || LOCAL+=("$a")
  done
fi

LOCAL_LINE="LOCAL_STAGES=${LOCAL[*]}"
CLOUD_LINE="CLOUD_FALLBACK_STAGES=${CLOUD[*]}"
printf '%s\n%s\n' "$LOCAL_LINE" "$CLOUD_LINE" | tee "$OUT_FILE"

echo ""
if [ "$stage_failed" -eq 1 ]; then
  echo -e "\033[0;31m✘ e2e failed: stage $AGENT shows failure evidence (turn2_rc=$TURN2_RC, slice_no_user_query=$( [ -n "$slice_fail" ] && echo yes || echo no ), marker_retained=$([ "$marker_retained" -eq 0 ] && echo yes || echo no)).${NC}"
  exit 1
fi
echo -e "\033[0;32m✔ e2e passed: no 'no user query found' in slice, marker retained across turns.${NC}"
exit 0
