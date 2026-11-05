#!/bin/bash
# resolve-pipeline-mode.sh — Resolve and record this run's pipeline mode.
#
# Spec 039 Tasks 3-4 (docs/SPEC_PIPELINE.md §Lite mode). One script owns the
# precedence so no agent re-implements it:
#
#   tier guard  >  explicit human token  >  deterministic classifier
#
#   - Tier guard comes first: a `production` or `multi-service` repo, and a
#     repo whose tier cannot be detected, never resolve to `lite`. A refused
#     `lite` is reported on stderr and recorded as `Chosen: full`.
#   - The human token (`scripts/lite-trigger.sh`) overrides the classifier in
#     both directions, subject to the tier guard.
#   - With no token the classifier (`scripts/classify-spec-size.sh`) decides.
#
# Every invocation appends exactly one entry to `<spec>/45-decisions.md` in the
# six-line `Condition: / Options: / Chosen: / Why: / Reversibility: / At:`
# format, via `scripts/autopilot-decisions.sh`. Nothing outside the spec folder
# is written.
#
# Usage:
#   scripts/resolve-pipeline-mode.sh specs/NNN-slug [ARG ...]
#
# Output: the resolved mode on stdout — `lite` or `full`.
#
# Exit codes:
#   0 — a mode was resolved and recorded
#   2 — usage error, missing spec folder, or conflicting mode tokens
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Lite mode
#   docs/spec-pipeline/lite-mode.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRIGGER="$SCRIPT_DIR/lite-trigger.sh"
CLASSIFIER="$SCRIPT_DIR/classify-spec-size.sh"
DECISIONS="$SCRIPT_DIR/autopilot-decisions.sh"

# require_spec_dir <dir> — the argument contract: a missing argument is a usage
# error, a missing folder names the path it looked for, both exit 2.
require_spec_dir() {
  if [ -z "$1" ]; then
    echo "usage: scripts/resolve-pipeline-mode.sh specs/NNN-slug [ARG ...]" >&2
    exit 2
  fi
  if [ ! -d "$1" ]; then
    echo "resolve-pipeline-mode: spec folder not found: $1" >&2
    exit 2
  fi
}

# field <n> <line> — field <n> of a `<first>\t<rest>` line.
field() {
  printf '%s\n' "$2" | cut -f"$1"
}

# tier_in_dir <dir> — the `Conformance tier:` value declared by a file directly
# in <dir>, if any (docs/CONFORMANCE_TIERS.md §How to declare a tier).
tier_in_dir() {
  local file tier
  for file in "$1"/AGENTS.md "$1"/AGENTS_*.md; do
    [ -f "$file" ] || continue
    tier="$(grep -oE 'Conformance tier: (mvp|production|multi-service)' "$file" 2>/dev/null \
      | head -1 | awk '{print $3}')"
    if [ -n "$tier" ]; then
      printf '%s' "$tier"
      return 0
    fi
  done
}

# detect_tier <dir> — the nearest `Conformance tier:` declaration at or above
# <dir>. Prints nothing when no declaration is reachable: an undetectable tier
# is a refusal, never a default to `mvp` that could permit lite on an
# undeclared production repo.
detect_tier() {
  local dir="$1" tier next
  while [ -n "$dir" ]; do
    tier="$(tier_in_dir "$dir")"
    if [ -n "$tier" ]; then
      printf '%s' "$tier"
      return 0
    fi
    next="$(dirname "$dir")"
    # `.` and `/` are both terminal because `dirname` is idempotent there: a
    # relative path bottoms out at `.` (`dirname .` is `.`) and an absolute one
    # at `/`. Without this guard the walk never reaches its stop condition.
    if [ "$next" = "$dir" ] || [ "$next" = "." ]; then
      return 0
    fi
    dir="$next"
  done
}

# classifier_result <spec-dir> — `<mode>\t<reason>` from the classifier, with the
# documented `full` fallback when it produced nothing usable.
classifier_result() {
  local out
  if ! out="$(bash "$CLASSIFIER" "$1")"; then
    printf 'full\tclassifier produced no usable output\n'
    return 0
  fi
  printf '%s\t%s\n' \
    "$(printf '%s\n' "$out" | head -1)" \
    "$(printf '%s\n' "$out" | sed -n 's/^Reason: //p' | head -1)"
}

# request_of <trigger> <classifier-result> — `<requested>\t<why>`. An explicit
# token wins both directions and is its own why; with no token the classifier's
# verdict and reason carry through.
request_of() {
  if [ "$1" = "lite" ] || [ "$1" = "full" ]; then
    printf "%s\targument: explicit '%s' token requested\n" "$1" "$1"
    return 0
  fi
  printf '%s\tclassifier: %s\n' "$(field 1 "$2")" "$(field 2 "$2")"
}

# permitted_mode <tier> <requested> — `mvp` permits either request; every other
# tier, undetectable included, refuses `lite`.
permitted_mode() {
  if [ "$1" = "mvp" ] || [ "$2" != "lite" ]; then
    printf '%s' "$2"
    return 0
  fi
  printf 'full'
}

# refusal_note <tier> <requested> — a refused `lite` is reported, never silent.
refusal_note() {
  [ "$2" = "lite" ] || return 0
  [ "$1" != "mvp" ] || return 0
  echo "resolve-pipeline-mode: lite mode refused — conformance tier '${1:-undetectable}' does not permit it" >&2
}

# decision_why <tier> <mode> <request> — the `Why:` line. A tier refusal
# explains itself; otherwise the request's own why stands.
decision_why() {
  if [ "$2" != "$(field 1 "$3")" ]; then
    printf 'tier: %s refuses lite mode' "${1:-undetectable}"
    return 0
  fi
  field 2 "$3"
}

# record_decision <spec-dir> <mode> <why> — append the six-line entry.
record_decision() {
  bash "$DECISIONS" add "$1/45-decisions.md" \
    --condition "Pipeline mode for $1" \
    --options "lite, full" \
    --chosen "$2" \
    --why "$3" \
    --reversibility "append a new entry with an explicit lite or full token"
}

spec_dir="${1:-}"
require_spec_dir "$spec_dir"
# Canonicalise before the tier walk: the documented usage passes a relative
# path, and walking upwards from a relative path is only well-defined once it
# is absolute (see detect_tier's terminal guard).
spec_dir="$(cd -P -- "$spec_dir" && pwd)"
shift

tier="$(detect_tier "$spec_dir")"
trigger="$(bash "$TRIGGER" "$@")" || exit 2
request="$(request_of "$trigger" "$(classifier_result "$spec_dir")")"
mode="$(permitted_mode "$tier" "$(field 1 "$request")")"

refusal_note "$tier" "$(field 1 "$request")"
record_decision "$spec_dir" "$mode" "$(decision_why "$tier" "$mode" "$request")"

printf '%s\n' "$mode"
