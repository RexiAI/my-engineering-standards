#!/bin/bash
# gate-report-lib.sh — Shared -ReportPath machinery for the gate scripts
# (spec 012). Sourced by scripts/check-code-principles.sh and
# scripts/check-scenario-traceability.sh: JSON escaping, array serialization,
# the dash-style-insensitive flag-name parser helper, and the atomic report
# write. If the JSON escaping or atomic-write semantics change, they change
# here once instead of in two near-identical copies.
#
# The lib only defines functions — sourcing it has no side effects and is safe
# under `set -euo pipefail` in the parent.

# One parser for both flag styles (spec 012, Open question 1): 007's flags are
# double-dash (--tier, --warn-as-error, --gates, --json), 011/012's are
# single-dash (-BaseRef, -ReportPath). Strip every leading dash and match on
# the name so the styles coexist without two incompatible parsers.
strip_dashes() { local a="$1"; while [ "${a#-}" != "$a" ]; do a="${a#-}"; done; printf '%s' "$a"; }

json_escape() {
  local s="$1"
  s=$(printf '%s' "$s" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
  printf '%s' "$s"
}

json_array() {
  local first=1 item
  for item in "$@"; do
    [ "$first" -eq 1 ] || printf ','
    printf '"%s"' "$(json_escape "$item")"
    first=0
  done
}

# emit_json_report FILE JSON — write JSON atomically: temp sibling + rename, so
# a concurrent/partial reader never sees a half-written report. The write runs
# in a subshell so a shell-level redirect failure is silenced, not spilled raw
# to the terminal — the clean message below carries the reason. Returns 0 on
# success, 1 on failure (the caller's emit_report propagates it).
emit_json_report() {
  local file="$1" json="$2" tmp
  tmp="${file}.tmp.$$"
  if ( printf '%s\n' "$json" > "$tmp" ) 2>/dev/null; then
    mv "$tmp" "$file" || { rm -f "$tmp"; echo "Error: could not write report to $file" >&2; return 1; }
  else
    rm -f "$tmp"
    echo "Error: could not write report to $file" >&2
    return 1
  fi
}
