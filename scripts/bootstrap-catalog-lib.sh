#!/bin/bash
# bootstrap-catalog-lib.sh — data access for scripts/capabilities.tsv (spec 033):
# loading the catalog into its column arrays, and the queries every other
# bootstrap module asks of it (id lookup, flag lookup, flag values, flag names,
# the init-ci flag values).
#
# Sourced by scripts/bootstrap.sh; never run on its own. The catalog is the
# single source of truth — this module names no capability and no capability
# flag, it only reads columns.
#
# The lib only defines variables and functions, so sourcing it is side-effect
# free under `set -euo pipefail` in the parent.

# ── catalog ───────────────────────────────────
# Fields: id|label|category|stack|flag|baseline|action|files|init_ci|conflicts
CAT_IDS=()
CAT_LABELS=()
CAT_CATS=()
CAT_STACKS=()
CAT_FLAGS=()
CAT_BASE=()
CAT_ACTIONS=()
CAT_FILES=()
CAT_INITCI=()
CAT_CONFLICTS=()

load_catalog() {
  if [ ! -f "$CATALOG" ]; then
    echo "ERROR: capability catalog not found: $CATALOG" >&2
    exit 1
  fi
  local id label cat stack flag base action files initci conflicts
  while IFS='|' read -r id label cat stack flag base action files initci conflicts; do
    case "$id" in
      ''|'#'*) continue ;;
    esac
    CAT_IDS[${#CAT_IDS[@]}]="$id"
    CAT_LABELS[${#CAT_LABELS[@]}]="$label"
    CAT_CATS[${#CAT_CATS[@]}]="$cat"
    CAT_STACKS[${#CAT_STACKS[@]}]="$stack"
    CAT_FLAGS[${#CAT_FLAGS[@]}]="$flag"
    CAT_BASE[${#CAT_BASE[@]}]="$base"
    CAT_ACTIONS[${#CAT_ACTIONS[@]}]="$action"
    CAT_FILES[${#CAT_FILES[@]}]="$files"
    CAT_INITCI[${#CAT_INITCI[@]}]="$initci"
    CAT_CONFLICTS[${#CAT_CONFLICTS[@]}]="$conflicts"
  done < "$CATALOG"
  if [ "${#CAT_IDS[@]}" -eq 0 ]; then
    echo "ERROR: capability catalog is empty: $CATALOG" >&2
    exit 1
  fi
}

catalog_index() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_IDS[$i]}" = "$1" ]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 0
}

flag_ids() { # flag_ids "<flag or 'flag value'>" → ids answering to it
  local i
  for i in "${!CAT_FLAGS[@]}"; do
    if [ "${CAT_FLAGS[$i]}" = "$1" ]; then
      printf '%s\n' "${CAT_IDS[$i]}"
    fi
  done
  return 0
}

flag_takes_value() {
  local i
  for i in "${!CAT_FLAGS[@]}"; do
    case "${CAT_FLAGS[$i]}" in
      "$1 "*) return 0 ;;
    esac
  done
  return 1
}

flag_values() { # flag_values --stack → "java|go|node|python|rust"
  local i
  for i in "${!CAT_FLAGS[@]}"; do
    case "${CAT_FLAGS[$i]}" in
      "$1 "*) printf '%s\n' "${CAT_FLAGS[$i]#"$1 "}" ;;
    esac
  done | paste -sd'|' - 2>/dev/null || true
}

catalog_flag_names() {
  local i name seen=" "
  for i in "${!CAT_IDS[@]}"; do
    name="${CAT_FLAGS[$i]%% *}"
    case "$seen" in
      *" $name "*) continue ;;
    esac
    seen="$seen$name "
    printf '%s\n' "$name"
  done
}

information_ids() {
  local i out=""
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_ACTIONS[$i]}" = "information" ]; then
      out="$out ${CAT_IDS[$i]}"
    fi
  done
  printf '%s' "${out# }"
}

# The token following a flag in an init-ci argument string.
init_ci_flag_value() { # INIT_CI_STRING FLAG → value, or empty
  local prev="" tok
  for tok in $1; do
    if [ "$prev" = "$2" ]; then printf '%s' "$tok"; return 0; fi
    prev="$tok"
  done
  printf ''
}

# The first stack-axis value in an init-ci argument string — whichever of
# --backend/--frontend appears first.
init_ci_stack_value() { # INIT_CI_STRING → value, or empty
  local prev="" tok
  for tok in $1; do
    case "$prev" in
      --backend|--frontend) printf '%s' "$tok"; return 0 ;;
    esac
    prev="$tok"
  done
  printf ''
}

