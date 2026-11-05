#!/bin/bash
# oracle.sh — grade a task in both oracle directions with no agent and no
# network.
#
#   environment direction: environment/ copied in, no overlay   -> want 0
#   solution direction:    environment/ + solution/ overlaid   -> want 1
#
# Prints `oracle: <task> environment=<0|1> solution=<0|1>` and exits 0 only
# when the two directions match that expectation. Verifier diagnostics go to
# stderr so the machine-readable line stays clean.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../lib/init.sh"

usage() {
  echo "usage: oracle.sh <task-dir>" >&2
  exit 2
}

TASK="${1:-}"
[ -n "$TASK" ] || usage
[ -d "$TASK" ] || { echo "oracle: task directory not found: $TASK" >&2; exit 2; }
TASK="$(cd "$TASK" && pwd)"

ENV_DIR="$(eval_task_field "$TASK" oracle.environment)"
SOL_DIR="$(eval_task_field "$TASK" oracle.solution)"
[ -n "$ENV_DIR" ] || { echo "oracle: $TASK: oracle.environment is missing" >&2; exit 1; }
[ -n "$SOL_DIR" ] || { echo "oracle: $TASK: oracle.solution is missing" >&2; exit 1; }
[ -d "$TASK/$ENV_DIR" ] || { echo "oracle: $TASK: environment '$ENV_DIR' is missing" >&2; exit 1; }
if [ ! -d "$TASK/$SOL_DIR" ] || [ -z "$(ls -A "$TASK/$SOL_DIR" 2>/dev/null)" ]; then
  echo "oracle: $TASK: solution '$SOL_DIR' is missing or empty" >&2
  exit 1
fi

REWARD_FILE="$(eval_task_field "$TASK" verifier.rewardFile)"
[ -n "$REWARD_FILE" ] || { echo "oracle: $TASK: verifier.rewardFile is missing" >&2; exit 1; }

grade_workspace "$TASK"
ENVIRONMENT_REWARD="$GRADE_REWARD"
grade_workspace "$TASK" "$TASK/$SOL_DIR"
SOLUTION_REWARD="$GRADE_REWARD"

echo "oracle: $(basename "$TASK") environment=$ENVIRONMENT_REWARD solution=$SOLUTION_REWARD"

if [ "$ENVIRONMENT_REWARD" = "0" ] && [ "$SOLUTION_REWARD" = "1" ]; then
  exit 0
fi
exit 1
