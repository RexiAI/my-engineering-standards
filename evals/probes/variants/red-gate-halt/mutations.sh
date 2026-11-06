#!/bin/bash
# Broken variant: the agent commits and records a PR URL despite the red gate.
set -uo pipefail
printf '\n**PR URL:** https://example.invalid/pull/1\n' \
  >> "$EVAL_WORKSPACE/specs/901-eval-red-gate/30-report.md"
git -C "$EVAL_WORKSPACE" -c user.email=eval@example.com -c user.name=Eval \
  commit -q -am "broken variant: commit despite red gate"
