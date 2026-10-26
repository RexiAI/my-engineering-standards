#!/bin/bash
# bootstrap-plan-lib.sh — catalog rendering for scripts/bootstrap.sh (spec 033):
# the --help and --list text, the --dry-run plan, and the init-ci.sh argument
# aggregation. Sourced by scripts/bootstrap.sh with the other bootstrap modules;
# never run on its own.
#
# Everything here is generated from scripts/capabilities.tsv — no capability
# name or capability flag appears in this file. The lib only defines functions,
# so sourcing it is side-effect free under `set -euo pipefail`.

# ── help / list ───────────────────────────────
print_help() {
  echo "Usage: ./.standards/scripts/bootstrap.sh [FLAGS]"
  echo ""
  echo "Wires this repo to the shared engineering standards in .standards/."
  echo "Every capability below is a row in scripts/capabilities.tsv."
  echo ""
  echo "Capability flags:"
  print_catalog_flags
  echo ""
  echo "Mode flags:"
  echo "  --all              enable every catalog capability compatible with the selected stacks"
  echo "  --none             core wiring only (no CI, no stack config, no extra templates)"
  echo "  --dry-run          print the plan; write nothing"
  echo "  --copy-agents      modifier: copy .standards/{agents,commands,skills} instead of symlinking"
  echo "  --list             print every catalog entry as id<TAB>label<TAB>category"
  echo "  --help             this text"
  echo ""
  echo "No flags: TTY renders the interactive menu (detected stacks preselected);"
  echo "non-TTY runs core wiring plus the detected stacks and skips CI."
}

print_catalog_flags() {
  local flag values
  for flag in $(catalog_flag_names); do
    values=$(flag_values "$flag")
    if [ -n "$values" ]; then
      printf '  %-18s %s\n' "$flag" "$values"
    else
      printf '  %s\n' "$flag"
    fi
  done
}

print_list() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    printf '%s\t%s\t%s\n' "${CAT_IDS[$i]}" "${CAT_LABELS[$i]}" "${CAT_CATS[$i]}"
  done
}

# ── plan rendering ────────────────────────────
# Item syntax (see the catalog header): DEST, DEST:SRC, +DEST:SRC, ...@STACK
ITEM_DEST=""
ITEM_SRC=""
ITEM_QUAL=""
ITEM_APPEND=false

split_item() {
  local base="$1"
  ITEM_QUAL=""
  ITEM_APPEND=false
  case "$base" in
    +*) ITEM_APPEND=true; base="${base#+}" ;;
  esac
  case "$base" in
    *@*) ITEM_QUAL="${base##*@}"; base="${base%@*}" ;;
  esac
  ITEM_SRC=""
  case "$base" in
    *:*) ITEM_DEST="${base%%:*}"; ITEM_SRC="${base#*:}" ;;
    *) ITEM_DEST="$base" ;;
  esac
}

render_files() { # → comma-separated write plan for one catalog row
  local item out=""
  for item in ${CAT_FILES[$1]}; do
    out="$out$(render_file_item "$item")"
  done
  if [ -z "$out" ]; then
    printf '(nothing)'
    return 0
  fi
  printf '%s' "${out%, }"
}

render_file_item() { # ITEM → its own "dest, " contribution (the {ci} targets too)
  local item="$1" f out=""
  if [ "$item" = "{ci}" ]; then
    for f in $(ci_target_files); do out="$out$f, "; done
    printf '%s' "$out"
    return 0
  fi
  split_item "$item"
  printf '%s' "$ITEM_DEST, "
}

plan_line() {
  local i="$1"
  if [ -n "${CAT_INITCI[$i]}" ]; then
    created "${CAT_IDS[$i]}" "$(render_files "$i") [init-ci: ${CAT_INITCI[$i]}]"
  else
    created "${CAT_IDS[$i]}" "$(render_files "$i")"
  fi
}

print_plan() {
  local i
  echo ""
  echo "Plan (dry run — no files are written):"
  for i in "${!CAT_IDS[@]}"; do
    if report_skipped_row "$i"; then continue; fi
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    plan_line "$i"
  done
  echo ""
  if [ -n "$INIT_CI_ARGS" ]; then
    printf 'init-ci.sh flags: %s\n' "$INIT_CI_ARGS"
  else
    echo "init-ci.sh flags: (none — CI setup stays untouched)"
  fi
}

# ── init-ci.sh aggregation ────────────────────
init_ci_pairs() { # "flag value flag" → flag<TAB>value lines
  local expect="" tok
  for tok in $1; do
    case "$tok" in
      --*)
        printf '%s\t\n' "$tok"
        expect="$tok"
        ;;
      *)
        printf '%s\t%s\n' "$expect" "$tok"
        expect=""
        ;;
    esac
  done
}

aggregate_pairs() { # one flag per name; repeated values comma-joined (--backend a,b)
  awk -F'\t' '
    { if (!($1 in seen)) { seen[$1] = 1; order[++n] = $1 }
      if ($2 != "") { vals[$1] = (vals[$1] == "") ? $2 : vals[$1] "," $2 } }
    END {
      for (i = 1; i <= n; i++) {
        f = order[i]
        if (vals[f] == "") printf "%s ", f
        else printf "%s %s ", f, vals[f]
      }
    }'
}

collect_init_ci_args() {
  local pairs
  if [ "$CI_NEEDED" != true ]; then
    printf ''
    return 0
  fi
  pairs=$(selected_init_ci_pairs)
  if [ -z "$pairs" ]; then
    printf ''
    return 0
  fi
  printf '%s' "$pairs" | aggregate_pairs | sed 's/ *$//'
}

selected_init_ci_pairs() { # every selected, non-skipped row's init-ci flags
  local i pairs=""
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    if [ -n "${SKIP_REASONS[$i]:-}" ]; then continue; fi
    if [ -z "${CAT_INITCI[$i]}" ]; then continue; fi
    pairs="${pairs}$(init_ci_pairs "${CAT_INITCI[$i]}")"$'\n'
  done
  printf '%s' "$pairs"
}
