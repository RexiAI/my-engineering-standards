#!/bin/bash
set -euo pipefail

# bootstrap.sh — catalog-driven bootstrap for a child repo that consumes this
# standards repo as a .standards/ submodule.
#
# Every capability this script can wire is one row in scripts/capabilities.tsv.
# That catalog is the single source of truth: --list renders it, the interactive
# menu renders it, --all iterates it, the flag parser matches its `flag` column,
# and --dry-run prints its `files`/`init_ci` columns. This script names no
# capability and no capability flag of its own — it names only the ACTION VERBS
# a row may reference (act_<verb>, dispatched by name).
#
# This file is deliberately the thin shell: argument parsing, the interactive
# menu loop, and dispatch. Everything else lives in sourced modules:
#   bootstrap-catalog-lib.sh  capabilities.tsv loading + column queries
#   bootstrap-detect-lib.sh   backend/frontend stack detection
#   bootstrap-lib.sh          selection state + compatibility rules
#   bootstrap-plan-lib.sh     --help/--list text, dry-run plan, init-ci arguments
#   bootstrap-actions.sh      file-writing primitives, act_* verbs, execution
#
# Usage — run from the child repo root:
#   ./.standards/scripts/bootstrap.sh                       # TTY: menu; non-TTY: core wiring + detected stacks
#   ./.standards/scripts/bootstrap.sh --list
#   ./.standards/scripts/bootstrap.sh --all --dry-run
#   ./.standards/scripts/bootstrap.sh --stack java --with-saga --with-deploy kamal
#   ./.standards/scripts/bootstrap.sh --copy-agents          # copies instead of symlinking agents/commands/skills
#
# Baseline (always-on) capabilities are the catalog's `baseline=yes` rows: core
# wiring plus the spec-pipeline agent symlinks. --none selects exactly that set
# and nothing else; a bare non-TTY run adds the detected stacks (today's
# behavior) but never CI.
#
# Acceptance scenarios: specs/033-bootstrap-capability-catalog/20-acceptance/
# covered by scripts/tests/bootstrap-capability-catalog.bats (AC-033-01..49).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
STANDARDS_DIR="$REPO_ROOT/.standards"
CATALOG="$SCRIPT_DIR/capabilities.tsv"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/bootstrap-catalog-lib.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/bootstrap-detect-lib.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/bootstrap-lib.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/bootstrap-plan-lib.sh"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/bootstrap-actions.sh"

# ── argument parsing ──────────────────────────
# Mode flags toggle a variable and take no value; every other flag is matched
# against the catalog's `flag` column only, so no capability flag is named here.
MODE_FLAG_TABLE="--all:MODE_ALL --none:MODE_NONE --dry-run:DRY_RUN --copy-agents:COPY_AGENTS --list:DO_LIST --help:DO_HELP -h:DO_HELP"

mode_flag_var() { # FLAG → the variable that flag toggles, or empty
  local entry
  for entry in $MODE_FLAG_TABLE; do
    if [ "${entry%%:*}" = "$1" ]; then
      printf '%s' "${entry#*:}"
      return 0
    fi
  done
  printf ''
}

is_mode_flag() { [ -n "$(mode_flag_var "$1")" ]; }

set_mode_flag() { # FLAG — only called for a flag is_mode_flag accepted
  local var
  var=$(mode_flag_var "$1")
  printf -v "$var" '%s' true
}

parse_args() {
  local arg
  while [ $# -gt 0 ]; do
    arg="$1"
    shift
    if is_mode_flag "$arg"; then
      set_mode_flag "$arg"
    elif [ "${arg#-}" != "$arg" ]; then
      parse_capability_flag "$arg" "$@" || shift
    else
      refuse_and_exit "unexpected argument: $arg"
    fi
  done
}

parse_capability_flag() { # FLAG [VALUE ...] → 1 when it consumed VALUE
  local flag="$1"
  shift
  if flag_takes_value "$flag"; then
    select_flag_with_value "$flag" "$@"
    return 1
  fi
  select_flag_tokens "$flag" "unknown flag: $flag (see --help, or --list for the catalog)"
  return 0
}

select_flag_with_value() { # FLAG [VALUE ...]
  local flag="$1" val ids
  if [ $# -lt 2 ]; then
    refuse_and_exit "missing value for $flag (expected: $(flag_values "$flag"))"
  fi
  val="$2"
  ids=$(flag_ids "$flag $val")
  if [ -z "$ids" ]; then
    refuse_and_exit "unknown value '$val' for $flag (expected: $(flag_values "$flag"))"
  fi
  select_ids "$ids"
}

select_flag_tokens() { # FLAG ERROR_MESSAGE
  local ids
  ids=$(flag_ids "$1")
  if [ -z "$ids" ]; then
    refuse_and_exit "$2"
  fi
  select_ids "$ids"
}

select_ids() { # newline-separated catalog ids
  local token
  for token in $1; do
    explicit_select "$token"
  done
}

# ── interactive menu ──────────────────────────
MENU_IDS=()
MENU_NUMS=0

render_menu() {
  local i cat="" num=0
  MENU_IDS=()
  print_menu_header
  for i in "${!CAT_IDS[@]}"; do
    if [ "${CAT_ACTIONS[$i]}" = "information" ]; then continue; fi
    if [ "${CAT_CATS[$i]}" != "$cat" ]; then
      cat="${CAT_CATS[$i]}"
      print_menu_group "$cat"
    fi
    num=$((num + 1))
    MENU_IDS[$num]="${CAT_IDS[$i]}"
    print_menu_row "$i" "$num"
  done
  MENU_NUMS=$num
  print_menu_footer
}

print_menu_header() {
  echo ""
  echo "=== Select capabilities ==="
}

print_menu_group() { printf '\n[%s]\n' "$1"; }

print_menu_row() { # INDEX NUM
  local mark="[ ]" det=""
  if is_selected "${CAT_IDS[$1]}"; then mark="[x]"; fi
  if is_detected_row "$1"; then det="  [detected]"; fi
  printf '%s %2d) %-22s %s%s\n' "$mark" "$2" "${CAT_IDS[$1]}" "${CAT_LABELS[$1]}" "$det"
}

print_menu_footer() {
  printf '\nInformational only (never selected by --all): %s\n' "$(information_ids)"
  echo "Toggle: numbers separated by spaces; 'all'; 'none' (core wiring only — the --none flag)."
}

toggle_token() {
  local tok="$1" id
  case "$tok" in
    ''|*[!0-9]*)
      echo "  WARN: '$tok' is not a menu number"
      return 0
      ;;
  esac
  if [ "$tok" -lt 1 ] || [ "$tok" -gt "$MENU_NUMS" ]; then
    echo "  WARN: no menu entry numbered $tok"
    return 0
  fi
  id="${MENU_IDS[$tok]}"
  if is_selected "$id"; then
    deselect_id "$id"
  else
    select_id "$id"
    note_ci_need "$id"
  fi
}

print_selection() {
  local i ids=""
  for i in "${!CAT_IDS[@]}"; do
    if is_selected "${CAT_IDS[$i]}"; then ids="$ids ${CAT_IDS[$i]}"; fi
  done
  printf 'Selected:%s\n' "$ids"
}

menu_select() {
  render_menu
  read_menu_lines
  echo ""
  print_selection
}

read_menu_lines() {
  local line
  while :; do
    printf 'Selection (Enter accepts): '
    IFS= read -r line || line=""
    if [ -z "$line" ]; then return 0; fi
    apply_menu_line "$line"
    render_menu
  done
}

apply_menu_line() { # LINE — one menu command line
  local tok
  case "$1" in
    all)
      MODE_ALL=true
      DEPLOY_EXPLICIT=false
      expand_all
      ;;
    none)
      reselect_baseline
      ;;
    *)
      for tok in $1; do
        toggle_token "$tok"
      done
      ;;
  esac
}

# ── summary ───────────────────────────────────
# Printed by execute_all as its last act (dispatched from bootstrap-actions.sh).
print_summary() {
  echo ""
  if [ -z "$INIT_CI_ARGS" ]; then
    echo "CI/CD setup skipped (no CI platform selected)."
    echo "To enable more capabilities: ./.standards/scripts/bootstrap.sh --all"
  fi
  echo ""
  echo "=== Bootstrap complete ==="
  echo "Next steps:"
  echo "  1. Review and commit the new files: git status"
  echo "  2. OpenCode auto-discovers AGENTS.md and loads instructions from .standards/"
  echo "  3. Run the session hygiene check: ./session-start-check.sh"
  if [ -d "$STANDARDS_DIR/ci/templates/java-feature" ]; then
    echo "  4. TDD scaffolds available: ci/templates/{java,go,js}-feature (docs/TESTING_TDD_GUIDE.md)"
  fi
}

# ── main ──────────────────────────────────────
main() {
  allow_menu_on_tty "$@"
  load_catalog
  parse_args "$@"
  handle_info_flags
  require_standards_dir
  print_bootstrap_header
  prepare_selection
  if [ "$DRY_RUN" = true ]; then
    print_plan
    exit 0
  fi
  echo ""
  execute_all
}

allow_menu_on_tty() { # "$@" of main — a flagless TTY run opens the menu
  if [ $# -eq 0 ] && [ -t 0 ]; then
    MENU_ALLOWED=true
  fi
}

handle_info_flags() {
  if [ "$DO_HELP" = true ]; then print_help; exit 0; fi
  if [ "$DO_LIST" = true ]; then print_list; exit 0; fi
}

require_standards_dir() {
  if [ ! -d "$STANDARDS_DIR" ]; then
    echo "ERROR: .standards/ not found."
    echo "Run this first: git submodule add git@github.com:RexAI/my-engineering-standards.git .standards"
    exit 1
  fi
}

print_bootstrap_header() {
  echo "=== Engineering Standards Bootstrap ==="
  echo "Repo root: $REPO_ROOT"
}

# Detection, selection, and the one init-ci.sh invocation's arguments — the
# state every later step reads.
prepare_selection() {
  detect_backend
  detect_frontend
  report_detection
  compute_selection
  PRIMARY_BACKEND_VALUE=$(primary_backend)
  mark_platform_refusals
  INIT_CI_ARGS=$(collect_init_ci_args)
}

main "$@"
