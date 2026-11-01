#!/bin/bash
# autopilot-decisions.sh — Deterministic writer for the autopilot decision
# artifacts (spec 035 Task 6, docs/SPEC_PIPELINE.md §Autopilot mode).
#
# An autopilot run records every ask it resolved in
# `specs/NNN-slug/45-decisions.md`, and carries two marker lines in
# `30-report.md`: `Autopilot: true` and `Autopilot decisions: N`.
#
# Usage:
#   scripts/autopilot-decisions.sh add <file> \
#     --condition <text> --options <text> --chosen <text> \
#     --why <text> --reversibility <text> [--at <YYYY-MM-DDTHH:MM:SSZ>]
#   scripts/autopilot-decisions.sh none <file>
#   scripts/autopilot-decisions.sh count <file>
#   scripts/autopilot-decisions.sh mark-report <decisions-file> <report-file>
#
# `add` appends one entry: the six labelled lines Condition:, Options:,
# Chosen:, Why:, Reversibility:, At: (At defaults to the current UTC instant).
# Validation happens before any write: a missing field or a malformed
# timestamp exits 1 and leaves the file untouched.
#
# `none` writes the single line `No autopilot decisions were required` for a
# run that resolved nothing; it refuses to clobber a file that already has
# entries.
#
# `count` prints the number of entries (0 for a missing or no-decision file).
#
# `mark-report` recomputes the count from the decisions file and writes the two
# `30-report.md` marker lines, replacing any previous pair (idempotent).
#
# Exit codes:
#   0 — written / counted
#   1 — validation failure (nothing written)
#   2 — usage error
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Autopilot mode
set -euo pipefail

NO_DECISION_LINE='No autopilot decisions were required'

die() { echo "autopilot-decisions: $1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  scripts/autopilot-decisions.sh add <file> \
    --condition <text> --options <text> --chosen <text> \
    --why <text> --reversibility <text> [--at <YYYY-MM-DDTHH:MM:SSZ>]
  scripts/autopilot-decisions.sh none <file>
  scripts/autopilot-decisions.sh count <file>
  scripts/autopilot-decisions.sh mark-report <decisions-file> <report-file>
EOF
}

ensure_parent() { # ensure_parent <file>
  local dir
  dir="$(dirname "$1")"
  [ -d "$dir" ] || mkdir -p "$dir"
}

count_entries() { # count_entries <file> — print the entry count
  local f="$1" n
  if [ ! -f "$f" ]; then
    printf '0'
    return 0
  fi
  n="$(grep -c '^Condition:' "$f" 2>/dev/null || true)"
  printf '%s' "${n:-0}"
}

iso_utc() { # iso_utc <value> — 0 when value matches YYYY-MM-DDTHH:MM:SSZ
  case "$1" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) return 0 ;;
  esac
  return 1
}

# parse_add_args <--option value ...> — assign each value to the field variable
# of the same name (`--condition` → `condition`). The alternation is the
# membership check; the assignment lands in cmd_add's locals by dynamic scope.
parse_add_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --condition|--options|--chosen|--why|--reversibility|--at)
        printf -v "${1#--}" '%s' "${2:-}"
        shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done
}

# require_add_fields — every field except `at` is mandatory; check them in the
# documented order so the reported missing field is stable.
require_add_fields() {
  [ -n "$condition" ] || die "missing field: Condition"
  [ -n "$options" ] || die "missing field: Options"
  [ -n "$chosen" ] || die "missing field: Chosen"
  [ -n "$why" ] || die "missing field: Why"
  [ -n "$reversibility" ] || die "missing field: Reversibility"
}

# write_entry <file> — append one entry from the caller's validated field
# variables (dynamic scope). A stale no-decision line is cleared first.
write_entry() {
  local file="$1"
  ensure_parent "$file"
  if [ -f "$file" ] && grep -qxF -- "$NO_DECISION_LINE" "$file"; then
    : > "$file"
  fi
  {
    printf 'Condition: %s\n' "$condition"
    printf 'Options: %s\n' "$options"
    printf 'Chosen: %s\n' "$chosen"
    printf 'Why: %s\n' "$why"
    printf 'Reversibility: %s\n' "$reversibility"
    printf 'At: %s\n' "$at"
    printf '\n'
  } >> "$file"
}

cmd_add() {
  local file="${1:-}" condition="" options="" chosen="" why="" reversibility="" at=""
  [ -n "$file" ] || { usage >&2; exit 2; }
  shift

  parse_add_args "$@"
  require_add_fields
  [ -n "$at" ] || at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  iso_utc "$at" || die "At must be an ISO-8601 UTC timestamp YYYY-MM-DDTHH:MM:SSZ (got '$at')"

  write_entry "$file"
}

cmd_none() {
  local file="${1:-}"
  [ -n "$file" ] || { usage >&2; exit 2; }
  local existing
  existing="$(count_entries "$file")"
  if [ "$existing" -ne 0 ]; then
    die "refusing to overwrite $existing decision entr(y/ies) in $file"
  fi
  ensure_parent "$file"
  printf '%s\n' "$NO_DECISION_LINE" > "$file"
}

cmd_count() {
  local file="${1:-}"
  [ -n "$file" ] || { usage >&2; exit 2; }
  printf '%s\n' "$(count_entries "$file")"
}

cmd_mark_report() {
  local decisions="${1:-}" report="${2:-}"
  [ -n "$decisions" ] && [ -n "$report" ] || { usage >&2; exit 2; }
  local n tmp
  n="$(count_entries "$decisions")"
  ensure_parent "$report"
  [ -f "$report" ] || : > "$report"
  tmp="$report.autopilot.$$"
  # Drop any previous marker pair so re-marking is idempotent.
  grep -vE '^Autopilot:[[:space:]]*true[[:space:]]*$|^Autopilot decisions:[[:space:]]*[0-9]+[[:space:]]*$' \
    "$report" > "$tmp" || true
  {
    cat "$tmp"
    [ -s "$tmp" ] && printf '\n'
    printf 'Autopilot: true\n'
    printf 'Autopilot decisions: %s\n' "$n"
  } > "$report"
  rm -f "$tmp"
}

mode="${1:-}"
if [ -z "$mode" ]; then
  usage >&2
  exit 2
fi
shift

case "$mode" in
  add) cmd_add "$@" ;;
  none) cmd_none "$@" ;;
  count) cmd_count "$@" ;;
  mark-report) cmd_mark_report "$@" ;;
  *) usage >&2; exit 2 ;;
esac
