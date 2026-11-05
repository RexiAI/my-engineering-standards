#!/bin/bash
# lite-trigger.sh — Answer one question: did the human request a pipeline mode?
#
# Spec 039 Task 1 (docs/SPEC_PIPELINE.md §Lite mode). Detection is a single
# deterministic rule so every command and agent agrees on it:
#
#   - any single argv element equal to `lite` case-insensitively  -> lite
#   - any single argv element equal to `full` case-insensitively  -> full
#   - both present                                                -> conflict
#   - neither                                                     -> auto
#
# A trigger is an exact whole-token match: `--lite`, `lite-mode`, and `mylite`
# do NOT trigger. Commands and agents call this script instead of re-implementing
# the match.
#
# Usage:
#   scripts/lite-trigger.sh [ARG ...]
#
# Output: exactly one token on stdout — `lite`, `full`, or `auto`.
#
# Exit codes:
#   0 — the answer is `lite`, `full`, or `auto`
#   2 — conflicting tokens: stderr names the conflict, stdout stays empty
#
# The script is read-only: it writes nothing to the filesystem.
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Lite mode
#   docs/spec-pipeline/lite-mode.md
set -euo pipefail

# lowercase <word> — the case-insensitive half of the trigger match. This is the
# only place a mode-bearing argument is lowercased.
lowercase() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

# merge_mode <current> <token> — `auto` adopts the first token and repeating a
# token is a no-op. A different token is the documented conflict: there is no
# precedence between `lite` and `full`, so neither may silently win.
merge_mode() {
  case "$1" in
    auto|"$2") printf '%s' "$2" ;;
    *) printf 'conflict' ;;
  esac
}

mode="auto"
for arg in "$@"; do
  lowered="$(lowercase "$arg")"
  case "$lowered" in
    lite|full) mode="$(merge_mode "$mode" "$lowered")" ;;
  esac
done

if [ "$mode" = "conflict" ]; then
  echo "lite-trigger: conflicting mode tokens — 'lite' and 'full' both requested" >&2
  exit 2
fi

printf '%s\n' "$mode"
