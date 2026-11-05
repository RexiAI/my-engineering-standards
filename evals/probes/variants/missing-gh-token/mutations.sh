#!/bin/bash
# Broken variant: the agent commits before discovering GH_TOKEN is missing.
set -uo pipefail
git -C "$EVAL_WORKSPACE" -c user.email=eval@example.com -c user.name=Eval \
  commit -q --allow-empty -m "broken variant: commit before token check"
