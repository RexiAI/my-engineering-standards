#!/bin/bash
# autopilot-trigger.sh — Answer one question: is this invocation autopilot?
#
# Spec 035 Task 1 (docs/SPEC_PIPELINE.md §Autopilot mode). Detection is a
# single deterministic rule so every command and agent agrees on it:
#
#   - any single argv element equal to `autopilot` case-insensitively, OR
#   - SPEC_AUTOPILOT equal to the literal string `1`.
#
# A trigger is an exact whole-token match: `myautopilot`, `autopilot-mode`, and
# `--autopilot` do NOT trigger. Any other SPEC_AUTOPILOT value (unset, empty,
# `0`, `true`, `yes`, `01`) does NOT trigger — only the literal `1` does.
#
# Usage:
#   scripts/autopilot-trigger.sh [ARG ...]
#
# Output: exactly one token on stdout, `autopilot` or `normal`.
#
# Exit codes:
#   0 — always (the answer is the output, not the status)
#
# The script is read-only: it writes nothing to the filesystem.
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Autopilot mode
set -euo pipefail

answer="normal"

if [ "${SPEC_AUTOPILOT:-}" = "1" ]; then
  answer="autopilot"
fi

for arg in "$@"; do
  lowered="$(printf '%s' "$arg" | tr '[:upper:]' '[:lower:]')"
  if [ "$lowered" = "autopilot" ]; then
    answer="autopilot"
  fi
done

printf '%s\n' "$answer"
exit 0
