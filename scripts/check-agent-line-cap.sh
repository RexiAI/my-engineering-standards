#!/bin/bash
# check-agent-line-cap.sh — Keep every spec-pipeline agent prompt inside its
# line cap (spec 038).
#
# Agent prompts are loaded into context on every invocation, so an agent file
# that grows into a procedure manual costs tokens on every run and buries the
# decisions it exists to carry. The procedure belongs in a stage doc under
# docs/spec-pipeline/ or a script under scripts/, where it is read on demand;
# the agent keeps the decision, the stop condition, the output, and a path
# reference to the extracted artifact.
#
# The cap applies to agents/spec-*.md only — the orchestrator agent matches the
# glob too, and is in scope by the same rule as the stage agents.
#
# Usage:
#   scripts/check-agent-line-cap.sh [ROOT]
#   ROOT defaults to the repo root (parent of scripts/). Pass a scratch tree
#   with an agents/ directory to check a fixture (scripts/tests/ac-038-line-cap.bats
#   does, so the real agents are never rewritten by a test).
#
# Exit codes:
#   0 — every agents/spec-*.md is at or under MAX_LINES (one OK line per file);
#       a ROOT with no matching file is vacuous, not a failure
#   1 — at least one file is over the cap; each prints
#       `[OVER] <path> <lines> lines (cap <MAX_LINES>)`
#   2 — usage error, or ROOT has no agents/ directory (tooling failure, never
#       a silent pass)
#
# Standards reference:
#   docs/AGENTS_AND_SKILLS.md
#   docs/spec-pipeline/verifier.md
set -euo pipefail

# The one cap value. Raise it only with a spec that says why: it is a gate
# threshold, not a local preference.
MAX_LINES=120

usage() {
  echo "usage: $0 [ROOT]" >&2
  exit 2
}

# repo_root — the tree holding scripts/ and agents/.
repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dirname "$script_dir"
}

# resolve_root [ROOT] — sets ROOT from the sole argument, else the repo root.
resolve_root() {
  [ "$#" -le 1 ] || usage
  ROOT="${1:-$(repo_root)}"
}

# require_agents_dir <root> — a tree with no agents/ is tooling failure, never
# a silent pass. Exit 2 rather than return, because nothing downstream is
# checkable.
require_agents_dir() {
  [ -d "$1/agents" ] && return 0
  echo "ERROR: agents/ directory not found under $1" >&2
  exit 2
}

# line_count <file> — the file's line count, spaces stripped.
line_count() {
  wc -l < "$1" | tr -d ' '
}

# over_cap <lines> — 0 when the count breaks the cap.
over_cap() {
  [ "$1" -gt "$MAX_LINES" ]
}

# scan_agents <root> — print a verdict per file; set CHECKED and OVER. The
# verdict and the count come from one cap decision, so they cannot disagree.
scan_agents() {
  local agent lines tag
  CHECKED=0
  OVER=0
  shopt -s nullglob
  for agent in "$1"/agents/spec-*.md; do
    lines="$(line_count "$agent")"
    CHECKED=$((CHECKED + 1))
    tag='[OK]'
    if over_cap "$lines"; then
      tag='[OVER]'
      OVER=$((OVER + 1))
    fi
    printf '%s %s %s lines (cap %s)\n' "$tag" "${agent#"$1"/}" "$lines" "$MAX_LINES"
  done
  shopt -u nullglob
}

# summarize <root> <checked> <over> — closing verdict; 1 when anything is over.
summarize() {
  if [ "$2" -eq 0 ]; then
    echo "No agents/spec-*.md found under $1 — nothing to check."
    return 0
  fi
  echo ""
  if [ "$3" -eq 0 ]; then
    echo "All $2 agent prompt(s) within the $MAX_LINES-line cap."
    return 0
  fi
  echo "$3 agent prompt(s) exceed the $MAX_LINES-line cap."
  return 1
}

main() {
  resolve_root "$@"
  require_agents_dir "$ROOT"
  scan_agents "$ROOT"
  summarize "$ROOT" "$CHECKED" "$OVER"
}

main "$@"
