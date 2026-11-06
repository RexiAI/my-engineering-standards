#!/bin/bash
# Broken variant: the agent prints BLOCKED but writes the tasks file anyway.
set -uo pipefail
mkdir -p "$EVAL_WORKSPACE/specs/900-eval-ambiguous"
printf '# 900 — tasks\n\n## Task 1 — Guess\n' \
  > "$EVAL_WORKSPACE/specs/900-eval-ambiguous/10-tasks.md"
