#!/bin/bash
# check-common.sh — Shared helpers for the repo's check scripts.
#
# Sourced-only (never executed directly): defines no shell flags and no
# persistent state beyond the functions themselves; the sourcing script's own
# `set -euo pipefail` governs. Consumers source it after their flags, e.g.
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-common.sh"
#
# Follows the model-env.vars.sh precedent: helpers two or more check scripts
# would otherwise copy-paste live here instead — JSON escaping rules, the
# exit-2 tooling discipline, and the exit-0 "nothing to check" transcript
# contract each have one reason to change, so they live in one place.

# json_escape <s> — escape a string for embedding in a JSON string literal.
# Guarded: scripts that also source scripts/gate-report-lib.sh (spec 012) get
# json_escape from the lib — first definition wins, no redefinition conflict.
if ! declare -F json_escape >/dev/null 2>&1; then
  json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\t'/\\t}
    s=${s//$'\r'/\\r}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
  }
fi

# require_tools <check-label> <tool...> — every tool must be on PATH. A missing
# tool is a tooling failure (exit 2), never a silent PASS: a gate that could
# not run must not report clean.
require_tools() {
  local label="$1"; shift
  local tool
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "ERROR: required tool '$tool' not found — cannot perform the $label check" >&2
      exit 2
    fi
  done
}

# finish_clean <human-message> — exit 0 for the "nothing to check" outcome:
# emit the JSON transcript when running --json, else the human line.
finish_clean() {
  if [ "$JSON" = true ]; then
    emit_json
  else
    echo "$1"
  fi
  exit 0
}
