#!/bin/bash
# bootstrap-detect-lib.sh — stack detection for scripts/bootstrap.sh (spec 033):
# which backend and frontend marker the child repo carries, and the detection
# report printed before the plan.
#
# Sourced by scripts/bootstrap.sh; never run on its own. Detected stacks drive
# selection: they preselect the matching catalog rows and are the evidence the
# detection report names. Marker precedence is a contract — see
# detect_frontend below.
#
# The lib only defines variables and functions, so sourcing it is side-effect
# free under `set -euo pipefail` in the parent.

# ── detection ─────────────────────────────────
BACKEND_STACK=""
BACKEND_EVIDENCE=""
FRONTEND_STACK=""
FRONTEND_EVIDENCE=""
PRIMARY_BACKEND_VALUE="node"

# Ordered backend markers: stack|marker (a file name, or a glob for the Go case
# where the evidence is the matched file). Go sits before package.json on
# purpose — a Go service that also carries a frontend package.json is still a
# Go backend. First match wins.
BACKEND_MARKERS='java|pom.xml go|*.go node|package.json python|pyproject.toml python|requirements.txt rust|Cargo.toml'

detect_backend() {
  local entry hit
  for entry in $BACKEND_MARKERS; do
    hit=$(first_marker_file "${entry#*|}")
    if [ -n "$hit" ]; then
      BACKEND_STACK="${entry%%|*}"
      BACKEND_EVIDENCE="$hit"
      return 0
    fi
  done
}

first_marker_file() { # MARKER_OR_GLOB → first matching repo-relative file, or empty
  local hit
  # shellcheck disable=SC2086  # the marker is a glob and must expand
  for hit in "$REPO_ROOT"/$1; do
    if [ -f "$hit" ]; then printf '%s' "${hit#"$REPO_ROOT"/}"; return 0; fi
  done
  printf ''
}

# Marker precedence: an Expo app also lists "react", an Ionic app also lists
# "react", so the more specific marker must win before "react" (AC-033-17).
# Listed in precedence order as STACK|GREP_PATTERN.
FRONTEND_MARKERS='react-native|"(expo|react-native)" nextjs|"next" ionic|"@ionic/ react|"react" angular|"@angular/'

detect_frontend() {
  local marker
  if [ ! -f "$REPO_ROOT/package.json" ]; then
    return 0
  fi
  marker=$(frontend_marker)
  if [ -n "$marker" ]; then
    FRONTEND_STACK="$marker"
    FRONTEND_EVIDENCE="package.json"
  fi
}

frontend_marker() { # → the first matching marker in precedence order, or empty
  local entry
  for entry in $FRONTEND_MARKERS; do
    if grep -qE "${entry#*|}" "$REPO_ROOT/package.json" 2>/dev/null; then
      printf '%s' "${entry%%|*}"
      return 0
    fi
  done
  printf ''
}

upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

report_detection() {
  echo ""
  echo "Detection:"
  if [ -n "$BACKEND_STACK" ]; then
    printf '  [%s] detected via %s\n' "$(upper "$BACKEND_STACK")" "$BACKEND_EVIDENCE"
  else
    echo "  [NONE] no backend marker found"
  fi
  if [ -n "$FRONTEND_STACK" ]; then
    printf '  [%s] detected via %s\n' "$(upper "$FRONTEND_STACK")" "$FRONTEND_EVIDENCE"
  else
    echo "  [NONE] no frontend marker found"
  fi
}

primary_backend() {
  if [ -n "$BACKEND_STACK" ]; then
    printf '%s' "$BACKEND_STACK"
    return 0
  fi
  local value
  value=$(first_selected_flag_value --backend)
  printf '%s' "${value:-node}"
}

first_selected_flag_value() { # FLAG → value from the first selected row carrying it
  local i value
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    value=$(init_ci_flag_value "${CAT_INITCI[$i]}" "$1")
    if [ -n "$value" ]; then printf '%s' "$value"; return 0; fi
  done
  printf ''
}

