#!/bin/bash
# autopilot-report.sh — Deterministic morning-report writer for an autopilot
# queue run (spec 035 Task 7, docs/SPEC_PIPELINE.md §Autopilot mode).
#
# Usage:
#   scripts/autopilot-report.sh --manifest <file> [--date YYYY-MM-DD] [--root <dir>]
#
# Manifest format: one spec per line, five pipe-separated fields —
#
#   slug|status|detail|decisions|followup
#
#   slug       the spec slug, e.g. 035-autopilot-mode
#   status     `pr` (detail = PR URL) or `stopped` (detail = stop reason)
#   detail     PR URL or the stop reason
#   decisions  path to that spec's 45-decisions.md, or `-`
#   followup   out-of-scope follow-up proposal text, or `-`
#
# Blank lines and lines starting with `#` are ignored. Fields must not contain
# a pipe. Lines appear in queue order; the orchestrator writes the manifest up
# to and including the spec that stopped the queue.
#
# Location rule (AC-035-21/22):
#   at least one `pr` status  -> docs/changes/autopilot-YYYY-MM-DD.md
#   no `pr` status            -> specs/autopilot-YYYY-MM-DD.md
# YYYY-MM-DD is the UTC date the queue started (--date, default today).
#
# Report shape (AC-035-23): a per-spec status block in queue order, a
# `## Decisions` section, and a `## Stop reasons` / `## Follow-up proposals`
# section only when the manifest carries one.
#
# The output path, relative to --root, is printed to stdout.
#
# Exit codes:
#   0 — report written
#   1 — invalid manifest (nothing written)
#   2 — usage error
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Autopilot mode
set -euo pipefail

REPORT_ROOT=""
START_DATE=""
MANIFEST=""

usage() {
  cat <<'EOF'
Usage:
  scripts/autopilot-report.sh --manifest <file> [--date YYYY-MM-DD] [--root <dir>]

Manifest lines: slug|status|detail|decisions|followup
  status is `pr` (detail = PR URL) or `stopped` (detail = stop reason).
EOF
}

die() { echo "autopilot-report: $1" >&2; exit 1; }

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --root) REPORT_ROOT="${2:-}"; shift 2 ;;
      --date) START_DATE="${2:-}"; shift 2 ;;
      --manifest) MANIFEST="${2:-}"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) usage >&2; exit 2 ;;
    esac
  done
}

# resolve_root — default the report root to this repo (the script's parent).
resolve_root() {
  if [ -z "$REPORT_ROOT" ]; then
    REPORT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
}

# require_manifest — a manifest argument is mandatory and must exist.
require_manifest() {
  [ -n "$MANIFEST" ] || { usage >&2; exit 2; }
  [ -f "$MANIFEST" ] || die "manifest not found: $MANIFEST"
}

# resolve_date — default to today in UTC, then require YYYY-MM-DD.
resolve_date() {
  [ -n "$START_DATE" ] || START_DATE="$(date -u +%Y-%m-%d)"
  case "$START_DATE" in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
    *) die "date must be YYYY-MM-DD (got '$START_DATE')" ;;
  esac
}

# parse_entry <line> — split one manifest line into the E_* fields.
parse_entry() {
  local extra
  IFS='|' read -r E_SLUG E_STATUS E_DETAIL E_DECISIONS E_FOLLOWUP extra <<< "$1"
  E_EXTRA="$extra"
}

# require_field <label> <value> <line> — one manifest field must be non-empty.
require_field() {
  [ -n "$2" ] || die "manifest line is missing the $1 field: $3"
}

# validate_entry <line> — exactly five fields, a slug, a known status, and no
# empty field. Reads the E_* values parse_entry set.
validate_entry() {
  [ -n "$E_EXTRA" ] && die "manifest line has more than five fields: $1"
  [ -n "$E_SLUG" ] || die "manifest line is missing a slug: $1"
  case "$E_STATUS" in
    pr|stopped) ;;
    *) die "manifest line has an invalid status (expected pr or stopped): $1" ;;
  esac
  require_field detail "$E_DETAIL" "$1"
  require_field decisions "$E_DECISIONS" "$1"
  require_field followup "$E_FOLLOWUP" "$1"
}

# append_entry <line> — validate one manifest line, then record it in queue
# order and set the presence flags the conditional sections use.
append_entry() {
  parse_entry "$1"
  validate_entry "$1"
  SLUGS+=("$E_SLUG")
  STATUSES+=("$E_STATUS")
  DETAILS+=("$E_DETAIL")
  DECISION_REFS+=("$E_DECISIONS")
  FOLLOWUPS+=("$E_FOLLOWUP")
  [ "$E_STATUS" = "pr" ] && has_pr=1
  [ "$E_STATUS" = "stopped" ] && has_stop=1
  [ "$E_FOLLOWUP" != "-" ] && has_follow=1
  return 0
}

# load_manifest — every non-blank, non-comment line is one queue entry.
load_manifest() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    append_entry "$line"
  done < "$MANIFEST"
}

# choose_output — AC-035-21/22: any PR puts the report under docs/changes/,
# a queue that opened none puts it under specs/.
choose_output() {
  if [ "$has_pr" -eq 1 ]; then
    printf 'docs/changes/autopilot-%s.md' "$START_DATE"
  else
    printf 'specs/autopilot-%s.md' "$START_DATE"
  fi
}

# write_entry_block <index> — one per-spec status block.
write_entry_block() {
  printf '## %s\n\n' "${SLUGS[$1]}"
  if [ "${STATUSES[$1]}" = "pr" ]; then
    printf 'Status: PR %s\n' "${DETAILS[$1]}"
  else
    printf 'Status: STOPPED — %s\n' "${DETAILS[$1]}"
  fi
  if [ "${DECISION_REFS[$1]}" = "-" ]; then
    printf 'Decisions: none recorded\n\n'
  else
    printf 'Decisions: %s\n\n' "${DECISION_REFS[$1]}"
  fi
}

write_entries() {
  local i=0
  while [ "$i" -lt "${#SLUGS[@]}" ]; do
    write_entry_block "$i"
    i=$((i + 1))
  done
}

write_decisions() {
  local i=0
  printf '## Decisions\n\n'
  while [ "$i" -lt "${#SLUGS[@]}" ]; do
    if [ "${DECISION_REFS[$i]}" = "-" ]; then
      printf -- '- %s: none recorded\n' "${SLUGS[$i]}"
    else
      printf -- '- %s: %s\n' "${SLUGS[$i]}" "${DECISION_REFS[$i]}"
    fi
    i=$((i + 1))
  done
  printf '\n'
}

write_stop_reasons() {
  [ "$has_stop" -eq 1 ] || return 0
  local i=0
  printf '## Stop reasons\n\n'
  while [ "$i" -lt "${#SLUGS[@]}" ]; do
    [ "${STATUSES[$i]}" = "stopped" ] && printf -- '- %s: %s\n' "${SLUGS[$i]}" "${DETAILS[$i]}"
    i=$((i + 1))
  done
  printf '\n'
}

write_followups() {
  [ "$has_follow" -eq 1 ] || return 0
  local i=0
  printf '## Follow-up proposals\n\n'
  while [ "$i" -lt "${#SLUGS[@]}" ]; do
    [ "${FOLLOWUPS[$i]}" != "-" ] && printf -- '- %s: %s\n' "${SLUGS[$i]}" "${FOLLOWUPS[$i]}"
    i=$((i + 1))
  done
  printf '\n'
}

# write_report <out> — the morning-report body (AC-035-23).
write_report() {
  {
    printf '# Autopilot morning report — %s\n\n' "$START_DATE"
    printf 'Queue started %s (UTC). Report written by `scripts/autopilot-report.sh`.\n\n' "$START_DATE"
    write_entries
    write_decisions
    write_stop_reasons
    write_followups
  } > "$1"
}

SLUGS=()
STATUSES=()
DETAILS=()
DECISION_REFS=()
FOLLOWUPS=()
has_pr=0
has_stop=0
has_follow=0

parse_args "$@"
resolve_root
require_manifest
resolve_date
load_manifest
if [ "${#SLUGS[@]}" -eq 0 ]; then
  die "manifest has no spec entries: $MANIFEST"
fi
rel="$(choose_output)"
out="$REPORT_ROOT/$rel"
mkdir -p "$(dirname "$out")"
write_report "$out"
printf '%s\n' "$rel"
