#!/bin/bash
# bootstrap-lib.sh — selection state and capability-compatibility rules for
# scripts/bootstrap.sh (spec 033).
#
# Sourced by scripts/bootstrap.sh; never run on its own. The lib only defines
# variables and functions — sourcing it has no side effects and is safe under
# `set -euo pipefail` in the parent.
#
# The catalog itself is scripts/capabilities.tsv (loaded by
# bootstrap-catalog-lib.sh). Nothing in this file (or in any bootstrap module)
# names a capability or a capability flag: it names only the action verbs a
# catalog row may reference, dispatched by name.
#
# Module split (docs/CODING_CONVENTIONS.md: files under 500 lines):
#   bootstrap.sh              argument parsing, interactive menu, dispatch
#   bootstrap-catalog-lib.sh  capabilities.tsv loading + column queries
#   bootstrap-detect-lib.sh   backend/frontend stack detection
#   bootstrap-lib.sh          this file — selection state + compatibility rules
#   bootstrap-plan-lib.sh     --help/--list text, dry-run plan, init-ci arguments
#   bootstrap-actions.sh      file-writing primitives, act_* verbs, execution
#
# The parent supplies REPO_ROOT, STANDARDS_DIR, and CATALOG before calling in.

# ── output vocabulary ─────────────────────────
# Every capability execution reports exactly one of these three (AC-033-29).
created() { printf 'CREATED %s: %s\n' "$1" "$2"; }
skipped() { printf 'SKIPPED (exists) %s: %s\n' "$1" "$2"; }
refused() { printf 'REFUSED (%s) %s\n' "$1" "$2"; }

refuse_and_exit() {
  printf 'REFUSED (%s)\n' "$1"
  exit 1
}

# ── selection state ───────────────────────────
SELECTED=" "
EXPLICIT=""
MODE_ALL=false
MODE_NONE=false
DRY_RUN=false
COPY_AGENTS=false
DO_LIST=false
DO_HELP=false
MENU_ALLOWED=false
CI_NEEDED=false
INIT_CI_ARGS=""
INIT_CI_RESULT=""
SKIP_REASONS=()

select_id() {
  case "$SELECTED" in
    *" $1 "*) return 0 ;;
  esac
  SELECTED="$SELECTED$1 "
}

# CI wiring is generated only when a capability that forwards CI flags was
# actually chosen. Bare stack selection (--stack/--frontend, or the detected
# stacks of a flagless run) writes stack config files only — exactly like the
# pre-catalog script, which never ran init-ci on a non-TTY run.
note_ci_need() {
  local idx initci
  idx=$(catalog_index "$1")
  if [ -z "$idx" ]; then return 0; fi
  initci="${CAT_INITCI[$idx]}"
  if [ -n "$initci" ]; then
    case "$initci" in
      "--backend "*|"--frontend "*) return 0 ;;
    esac
    CI_NEEDED=true
    return 0
  fi
  # A row that emits a GitHub workflow file needs the platform axis even when it
  # forwards no init-ci.sh flag (the Vercel production-verify lane does exactly
  # this).
  case " ${CAT_FILES[$idx]} " in
    *" .github/workflows/"*) CI_NEEDED=true ;;
  esac
}

explicit_select() {
  EXPLICIT="$EXPLICIT $1"
  select_id "$1"
  note_ci_need "$1"
}

deselect_id() {
  local out=" " entry
  for entry in $SELECTED; do
    if [ "$entry" != "$1" ]; then
      out="$out$entry "
    fi
  done
  SELECTED="$out"
}

is_selected() {
  case "$SELECTED" in
    *" $1 "*) return 0 ;;
  esac
  return 1
}

select_baseline() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_BASE[$i]}" = "yes" ]; then
      select_id "${CAT_IDS[$i]}"
    fi
  done
}

clear_skip_reasons() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    SKIP_REASONS[$i]=""
  done
}

# A row held back by a skip reason is reported identically in the dry-run plan
# and in the real run — one REFUSED line, then the caller moves on.
report_skipped_row() { # INDEX → 0 when the row was refused
  if [ -z "${SKIP_REASONS[$1]:-}" ]; then return 1; fi
  refused "${SKIP_REASONS[$1]}" "${CAT_IDS[$1]}"
  return 0
}

reselect_baseline() {
  SELECTED=" "
  CI_NEEDED=false
  clear_skip_reasons
  select_baseline
}

# ── selection assembly ────────────────────────
select_detected_stacks() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if is_detected_row "$i"; then
      select_id "${CAT_IDS[$i]}"
    fi
  done
}

is_detected_row() { # INDEX → is this row's own stack the detected one?
  local value
  value=$(stack_row_value "$1")
  if [ -z "$value" ]; then return 1; fi
  stack_matches_qualifier "$value"
}

stack_matches_qualifier() { # STACK_VALUE → does a detected stack carry it?
  if [ -n "$BACKEND_STACK" ] && [ "$1" = "$BACKEND_STACK" ]; then return 0; fi
  if [ -n "$FRONTEND_STACK" ] && [ "$1" = "$FRONTEND_STACK" ]; then return 0; fi
  return 1
}

# Presence of an axis is derived from the catalog's init_ci column: a selected
# row that forwards --backend/--frontend/--platform *has* that axis. No
# capability name is involved.
selected_has_init_ci() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    case " ${CAT_INITCI[$i]} " in
      *" $1 "*) return 0 ;;
    esac
  done
  return 1
}

present_backend() {
  if [ -n "$BACKEND_STACK" ]; then return 0; fi
  selected_has_init_ci "--backend"
}

present_frontend() {
  if [ -n "$FRONTEND_STACK" ]; then return 0; fi
  selected_has_init_ci "--frontend"
}

present_platform() {
  selected_has_init_ci "--platform"
}

# The value a stack row selects ("java" for --stack java), or empty for rows
# that merely need the axis (a gate, a deploy tool).
stack_row_value() {
  init_ci_stack_value "${CAT_INITCI[$1]}"
}

stack_compatible() { # stack_compatible INDEX — is the row usable in this repo?
  local i="$1" value
  case "${CAT_STACKS[$i]}" in
    none) return 0 ;;
    backend|frontend|ci) ;;
    *) return 1 ;;
  esac
  # A stack row is only compatible when *its own* stack is in play: --all on a
  # Java repo must not enable the Go/Node/Python/Rust rows just because some
  # backend exists.
  value=$(stack_row_value "$i")
  if [ -n "$value" ] && ! qualifier_present "$value"; then
    return 1
  fi
  case "${CAT_STACKS[$i]}" in
    backend) present_backend ;;
    frontend) present_frontend ;;
    ci) present_platform ;;
  esac
}

qualifier_present() { # STACK_VALUE → is that stack detected or selected?
  local i value
  if stack_matches_qualifier "$1"; then return 0; fi
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    value=$(stack_row_value "$i")
    if [ -n "$value" ] && [ "$value" = "$1" ]; then return 0; fi
  done
  return 1
}

conflict_with_selected() { # → the conflicting selected id, or empty
  local i="$1" c
  for c in $(printf '%s' "${CAT_CONFLICTS[$i]}" | tr ',' ' '); do
    if is_selected "$c"; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 0
}

deploy_flag_hint() { # every Deploy row's flag, from the catalog
  local i out=""
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_CATS[$i]}" != "Deploy" ]; then continue; fi
    if [ -n "$out" ]; then out="$out, "; fi
    out="$out${CAT_FLAGS[$i]}"
  done
  printf '%s' "$out"
}

explicit_category_selected() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_CATS[$i]}" != "$1" ]; then continue; fi
    if is_selected "${CAT_IDS[$i]}"; then return 0; fi
  done
  return 1
}

# Reason a row stays out of an --all selection, or empty when it may join.
all_skip_reason() {
  local i="$1"
  if [ "${CAT_ACTIONS[$i]}" = "information" ]; then
    printf 'informational only — media agents need external provider credentials'
    return 0
  fi
  if is_deploy_excluded "$i"; then
    printf '%s' "--all excludes deploy; name a tool with $(deploy_flag_hint)"
    return 0
  fi
  if ! stack_compatible "$i"; then
    print_stack_requirement "$i"
    return 0
  fi
  print_conflict_reason "$i"
}

is_deploy_excluded() { # INDEX → is this a Deploy row left out of --all?
  if [ "${CAT_CATS[$1]}" = "Deploy" ] && [ "$DEPLOY_EXPLICIT" != "true" ]; then return 0; fi
  return 1
}

print_stack_requirement() {
  local value
  value=$(stack_row_value "$1")
  if [ -n "$value" ]; then
    printf 'requires the %s stack (detected or selected)' "$value"
  else
    printf 'requires a %s stack' "${CAT_STACKS[$1]}"
  fi
}

print_conflict_reason() {
  local c
  c=$(conflict_with_selected "$1")
  if [ -n "$c" ]; then
    printf 'conflicts with %s' "$c"
  fi
}

expand_all() {
  local i reason
  for i in "${!CAT_IDS[@]}"; do
    if is_selected "${CAT_IDS[$i]}"; then continue; fi
    reason=$(all_skip_reason "$i")
    if [ -n "$reason" ]; then
      SKIP_REASONS[$i]="$reason"
      continue
    fi
    select_id "${CAT_IDS[$i]}"
    note_ci_need "${CAT_IDS[$i]}"
  done
}

# Conflicting *explicit* selections are refused before anything is written. The
# later-requested entry is reported as the offender, so the message names both
# sides of the pair deterministically (AC-033-28).
validate_conflicts() {
  local seen=" " id idx c
  for id in $EXPLICIT; do
    idx=$(catalog_index "$id")
    if [ -n "$idx" ]; then
      for c in $(printf '%s' "${CAT_CONFLICTS[$idx]}" | tr ',' ' '); do
        case "$seen" in
          *" $c "*)
            refused "conflicts with $c" "$id"
            exit 1
            ;;
        esac
      done
    fi
    seen="$seen$id "
  done
}

default_platform_index() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_CATS[$i]}" != "CI platform" ]; then continue; fi
    case " ${CAT_INITCI[$i]} " in
      *" --platform "*)
        printf '%s' "$i"
        return 0
        ;;
    esac
  done
  return 0
}

ensure_ci_platform() {
  if present_platform; then return 0; fi
  if [ "$CI_NEEDED" != true ]; then return 0; fi
  local idx
  idx=$(default_platform_index)
  if [ -n "$idx" ]; then
    select_id "${CAT_IDS[$idx]}"
    echo "  INFO: no CI platform selected — using ${CAT_LABELS[$idx]} (the catalog's default platform)"
  fi
}

ci_target_files() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    case " ${CAT_INITCI[$i]} " in
      *" --platform "*) printf '%s\n' "${CAT_FILES[$i]}" ;;
    esac
  done
}

# The platform's file prefix (".github/" for GitHub Actions, empty for GitLab):
# a row writing under .github/ can only be wired for a platform that writes
# there. Derived from the selected platform row's own files column.
ci_platform_prefix() {
  local f
  for f in $(ci_target_files); do
    case "$f" in
      .github/*)
        printf '.github/'
        return 0
        ;;
    esac
  done
  printf ''
}

platform_supports_files() {
  local i="$1" f prefix
  prefix=$(ci_platform_prefix)
  for f in ${CAT_FILES[$i]}; do
    case "$f" in
      '{ci}') continue ;;
      .github/workflows/*)
        if [ "$prefix" != ".github/" ]; then return 1; fi
        ;;
    esac
  done
  return 0
}

mark_platform_refusals() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    if ! platform_supports_files "$i"; then
      SKIP_REASONS[$i]="GitHub Actions only — select the GitHub CI platform to enable this capability"
    fi
  done
}

compute_selection() {
  select_baseline
  if [ "$MODE_NONE" = true ]; then
    refuse_none_with_flags
  elif [ "$MODE_ALL" = true ]; then
    expand_all_mode
  elif [ -z "$EXPLICIT" ] && [ "$MENU_ALLOWED" = true ]; then
    select_detected_stacks
    menu_select
  elif [ -z "$EXPLICIT" ]; then
    select_detected_stacks
  fi
  validate_conflicts
  ensure_ci_platform
}

refuse_none_with_flags() {
  if [ -n "$EXPLICIT" ]; then
    refuse_and_exit "--none cannot be combined with capability flags (got:$EXPLICIT)"
  fi
}

expand_all_mode() {
  DEPLOY_EXPLICIT=false
  if explicit_category_selected "Deploy"; then DEPLOY_EXPLICIT=true; fi
  expand_all
}
