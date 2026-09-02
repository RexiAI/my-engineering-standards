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

# git_ignore_status <root> <path> — echo exactly one of `ignored`,
# `not-ignored`, or `git-error`.
#
# `git check-ignore` has three outcomes, and collapsing them lies to the
# reader: exit 0 means the path IS ignored, exit 1 means it is NOT (a real
# content finding — for a credential file that means it is committable), and
# anything else means git could not run at all (invalid repo config, not a
# repository, permissions). A caller that treats 1 and 128 alike reports a
# tooling failure in the wording of a security finding, and vice versa — the
# reader then cannot tell which happened. This is the same discipline
# require_tools above applies with its exit 2: a gate that could not run must
# never be reported as a content finding.
#
# A `fatal:` on stderr is treated as git-error even on an unexpected exit code,
# because that is the shape the real incident took: a submodule checkout whose
# config carried core.bare=true alongside core.worktree made git fatal out, and
# a two-way caller reported it as "the env files are not gitignored".
git_ignore_status() {
  local root="$1" path="$2" rc=0 err
  err="$(git -C "$root" check-ignore -q -- "$path" 2>&1)" || rc=$?
  case "$rc" in
    0) printf 'ignored' ;;
    1) if [[ "$err" == *"fatal:"* ]]; then printf 'git-error'; else printf 'not-ignored'; fi ;;
    *) printf 'git-error' ;;
  esac
}

# git_repo_usable <root> — 0 when git can read <root> as a work tree. On
# failure prints an actionable diagnostic to stderr: what is wrong, the most
# common cause, and the fix. Callers run this once before any git-backed
# assertion, so a broken repo produces one honest tooling failure instead of a
# run of assertions that all misreport.
#
# The answer matters, not just the exit code: on the core.bare/core.worktree
# corruption `rev-parse --is-inside-work-tree` exits 0 while printing `false`,
# and every subsequent work-tree command then fatals out.
git_repo_usable() {
  local root="$1" err rc=0
  err="$(git -C "$root" rev-parse --is-inside-work-tree 2>&1)" || rc=$?
  if [ "$rc" -eq 0 ] && [ "${err##*$'\n'}" = "true" ]; then
    return 0
  fi
  {
    echo "ERROR: git cannot use '$root' as a repository — the repo config is unusable."
    echo "  git said: $err"
    echo "  Most common cause: core.bare=true set alongside core.worktree, which"
    echo "  'git worktree add' can produce inside a submodule checkout."
    echo "  Fix: git config -f <gitdir>/config core.bare false && git -C '$root' worktree prune"
  } >&2
  return 1
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
