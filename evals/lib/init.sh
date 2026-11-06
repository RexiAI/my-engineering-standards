#!/bin/bash
# init.sh — source the eval libraries every runner needs.
#
# The runner computes SCRIPT_DIR itself; this file locates the library
# directory from its own path so callers need only one `source` line.

EVAL_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$EVAL_LIB_DIR/task.sh"
# shellcheck source=/dev/null
source "$EVAL_LIB_DIR/reward.sh"
# shellcheck source=/dev/null
source "$EVAL_LIB_DIR/workspace.sh"
# shellcheck source=/dev/null
source "$EVAL_LIB_DIR/sandbox.sh"
# shellcheck source=/dev/null
source "$EVAL_LIB_DIR/grade.sh"
