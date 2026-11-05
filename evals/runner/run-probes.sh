#!/bin/bash
# run-probes.sh — run the three behavior probes.
#
#   run-probes.sh --hermetic [--runs-file FILE]
#       Grade each probe's solution direction and its recorded broken variant
#       with no agent. Print one line per probe. Append nothing. Exit 0 only
#       when every positive scores 1 and every broken variant scores 0.
#
#   run-probes.sh --record [--runs-file FILE]
#       Opt-in real-agent mode. Requires EVAL_ALLOW_AGENT=1; appends one
#       record per probe through evals/runner/run-task.sh. Exit 0 only when
#       every probe's reward is 1.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Tasks and variants always come from the package this script lives in. The
# runner's worktree repository is separately overridable (EVAL_REPO_ROOT) so
# tests can point it at a throwaway repository.
PROBES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EVAL_REPO_ROOT="${EVAL_REPO_ROOT:-$PROBES_ROOT}"
export EVAL_REPO_ROOT
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/init.sh"

MODE=""
RUNS_FILE="${EVAL_RUNS_FILE:-$PROBES_ROOT/runs.jsonl}"
while [ $# -gt 0 ]; do
  case "$1" in
    --hermetic) MODE="hermetic"; shift ;;
    --record) MODE="record"; shift ;;
    --runs-file|-f)
      RUNS_FILE="${2:-}"
      [ -n "$RUNS_FILE" ] || { echo "run-probes: --runs-file requires a path" >&2; exit 2; }
      shift 2 ;;
    *)
      echo "run-probes: unknown option: $1" >&2; exit 2 ;;
  esac
done

case "$MODE" in
  hermetic|record) ;;
  *)
    echo "usage: run-probes.sh (--hermetic | --record) [--runs-file FILE]" >&2
    exit 2
    ;;
esac

PROBES=(
  "001-ambiguous-specifier:ambiguous-specifier"
  "002-red-gate-halt:red-gate-halt"
  "003-missing-gh-token:missing-gh-token"
)

if [ "$MODE" = "hermetic" ]; then
  FAILED=0
  for entry in "${PROBES[@]}"; do
    TASK_NAME="${entry%%:*}"
    PROBE_ID="${entry#*:}"
    TASK="$PROBES_ROOT/evals/tasks/$TASK_NAME"
    VARIANT="$PROBES_ROOT/evals/probes/variants/$PROBE_ID"
    SOLUTION_DIR="$(eval_task_field "$TASK" oracle.solution)"

    grade_workspace "$TASK" "$TASK/$SOLUTION_DIR"
    SOLUTION_REWARD="$GRADE_REWARD"
    grade_workspace "$TASK" "$VARIANT"
    BROKEN_REWARD="$GRADE_REWARD"
    BROKEN_FAILS="$GRADE_FAILS"

    echo "probe: $PROBE_ID solution=$SOLUTION_REWARD broken=$BROKEN_REWARD fails=${BROKEN_FAILS:-none}"
    if [ "$SOLUTION_REWARD" != "1" ] || [ "$BROKEN_REWARD" != "0" ]; then
      FAILED=1
    fi
  done
  # Hermetic mode is host-only by definition: no model, no network, no Docker.
  # The control therefore runs with `sandbox=none` explicitly and proves the
  # fail-closed *detection* layer (a landed source write must record a block).
  # The real container boundary is `evals/probes/isolation/control.sh` with its
  # default `EVAL_SANDBOX=docker`, run separately on a Docker host.
  if ! EVAL_SANDBOX=none bash "$SCRIPT_DIR/../probes/isolation/control.sh"; then
    FAILED=1
  fi
  [ "$FAILED" -eq 0 ] && exit 0
  exit 1
fi

# ── --record: opt-in, credentialed, one record per probe. ───────────────────
if [ "${EVAL_ALLOW_AGENT:-}" != "1" ]; then
  echo "run-probes: --record requires EVAL_ALLOW_AGENT=1 (real-agent runs are opt-in)" >&2
  exit 2
fi
# Fail closed: real-agent probes need the container boundary. Refuse before any
# record is appended when the sandbox mode is unknown, Docker is missing, or
# the pinned image has not been built.
if ! sandbox_preflight; then
  echo "run-probes: --record refused: agent sandbox unavailable (environment block); nothing appended" >&2
  exit 2
fi

FAILED=0
for entry in "${PROBES[@]}"; do
  TASK_NAME="${entry%%:*}"
  TASK="$PROBES_ROOT/evals/tasks/$TASK_NAME"
  STATUS=0
  OUT="$(bash "$SCRIPT_DIR/run-task.sh" --runs-file "$RUNS_FILE" "$TASK" 2>&1)" || STATUS=$?
  printf '%s\n' "$OUT"
  if [ "$STATUS" -ne 0 ] || ! grep -q '^REWARD=1$' <<< "$OUT"; then
    FAILED=1
  fi
done
[ "$FAILED" -eq 0 ] && exit 0
exit 1
