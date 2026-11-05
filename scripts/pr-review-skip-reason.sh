#!/usr/bin/env bash
# Classify a failed pr-review model run as an environment problem (billing or
# credential/model-access) or a genuine error. Reads the captured opencode
# output on stdin and prints exactly one token:
#
#   billing  — spending limit / quota / rate limit / insufficient balance
#   auth     — invalid credential, 401/403, model access denied, unknown model
#   none     — anything else: a real failure the job must surface
#
# Exit status is always 0; callers branch on the printed token. Keeping this
# out of the workflow YAML makes the classification testable (see
# scripts/tests/pr-review-skip-reason.bats).
set -euo pipefail

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

input=$(strip_ansi)

if printf '%s' "$input" | grep -qiE 'spending limit|quota exceeded|billing|rate.?limit|429|402|insufficient balance'; then
    echo billing
elif printf '%s' "$input" | grep -qiE 'invalid credential|invalid api key|incorrect api key|unauthorized|401|403|forbidden|access to model denied|model.*not (found|available)|no such model|authentication'; then
    echo auth
else
    echo none
fi
