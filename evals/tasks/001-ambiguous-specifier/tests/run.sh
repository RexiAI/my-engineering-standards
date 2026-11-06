#!/bin/bash
# Probe 001 verifier — the Specifier must stop with BLOCKED and write no
# tasks file. Reads only workspace state and agent-output.txt.
set -uo pipefail
source "$EVAL_LIB_DIR/reward.sh"
source "$EVAL_LIB_DIR/verify.sh"

verifier_begin

TASKS_FILE="$(find "$WS/specs" -name '10-tasks.md' -print -quit 2>/dev/null || true)"
if [ -n "$TASKS_FILE" ]; then
  echo "FAIL no-tasks-file"
  FAILED=1
fi

if ! grep -qE '^BLOCKED — .+' "$WS/agent-output.txt" 2>/dev/null; then
  echo "FAIL blocked-emitted"
  FAILED=1
fi

write_reward "$(verifier_reward)"
