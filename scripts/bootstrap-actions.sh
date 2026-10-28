#!/bin/bash
# bootstrap-actions.sh — the writing half of scripts/bootstrap.sh (spec 033):
# file-writing primitives, the act_* verbs a catalog row dispatches to, and the
# execution loop that reports CREATED / SKIPPED (exists) / REFUSED.
#
# Sourced by scripts/bootstrap.sh; never run on its own. The verb names are the
# contract with scripts/capabilities.tsv (`action` column, `-` → `_`): a row
# saying `copy-template` dispatches to act_copy_template. Nothing here names a
# capability or a capability flag.
#
# The lib only defines functions, so sourcing it is side-effect free under
# `set -euo pipefail`.

STANDARDS_PIN_PLACEHOLDER='__STANDARDS_PIN__'
BACKEND_LANGUAGE_PLACEHOLDER='__BACKEND_LANGUAGE__'

# ── file-writing primitives ───────────────────
STANDARDS_PIN=""

read_standards_pin() {
  local pin
  pin=$(sed -n 's/^STANDARDS_PIN="\([0-9a-f]\{7,\}\)"$/\1/p' \
    "$STANDARDS_DIR/scripts/init-ci.sh" | head -1)
  if [ -z "$pin" ]; then
    echo "ERROR: could not read STANDARDS_PIN from scripts/init-ci.sh" >&2
    exit 1
  fi
  printf '%s' "$pin"
}

render_template() { # substitute the pin + backend placeholders; harmless for plain files
  local src="$1" pin="$STANDARDS_PIN"
  if grep -qF "$STANDARDS_PIN_PLACEHOLDER" "$src"; then
    if [ -z "$pin" ]; then
      pin=$(read_standards_pin)
      STANDARDS_PIN="$pin"
    fi
  fi
  sed -e "s|$STANDARDS_PIN_PLACEHOLDER|$pin|g" \
      -e "s|$BACKEND_LANGUAGE_PLACEHOLDER|$PRIMARY_BACKEND_VALUE|g" "$src"
}

# → 0 wrote, 1 already existed, 2 template not shipped
copy_item() { # copy_item DEST SRC APPEND
  local dest="$REPO_ROOT/$1" src="$STANDARDS_DIR/$2"
  if [ "$3" = "true" ]; then
    copy_item_append "$1" "$2" "$dest" "$src"
    return $?
  fi
  if [ -e "$dest" ] || [ -L "$dest" ]; then return 1; fi
  if [ ! -f "$src" ]; then return 2; fi
  mkdir -p "$(dirname "$dest")"
  render_template "$src" > "$dest"
  warn_github_scripts_paths "$1" "$src"
  return 0
}

# Append one template behind a sentinel line, so a re-run is a no-op (the
# sentinel is already there) and a human can see where the block came from.
copy_item_append() { # APPEND_DEST SRC DESTPATH SRCPATH
  local sentinel="# >>> standards:$2"
  if [ -f "$3" ] && grep -qF "$sentinel" "$3"; then return 1; fi
  if [ ! -f "$4" ]; then return 2; fi
  mkdir -p "$(dirname "$3")"
  printf '\n%s\n' "$sentinel" >> "$3"
  render_template "$4" >> "$3"
  return 0
}

# A workflow copied out of the standards repo still cites repo-relative
# scripts/ paths; the child needs those rewritten under .standards/.
warn_github_scripts_paths() { # DEST SRC
  case "$1" in
    .github/*)
      if grep -qE '(^|[[:space:]"])scripts/' "$2" 2>/dev/null; then
        echo "  INFO: $1 was copied from the standards repo — rewrite repo-relative 'scripts/' paths to '.standards/scripts/' for this child"
      fi
      ;;
  esac
}

ensure_line() { # → 0 appended, 1 already present
  local file="$1" line="$2" comment="${3:-}"
  if [ ! -f "$file" ]; then : > "$file"; fi
  if grep -qxF "$line" "$file" 2>/dev/null; then return 1; fi
  if [ -n "$comment" ]; then printf '\n%s\n' "$comment" >> "$file"; fi
  printf '%s\n' "$line" >> "$file"
  return 0
}

# ── action verbs ──────────────────────────────
# Each verb takes the catalog index it serves, appends to DETAIL, and bumps
# ACT_APPLIED (files it handled) / ACT_CREATED (files it wrote this run).
ACT_APPLIED=0
ACT_CREATED=0
DETAIL=""

write_agents_pointer() {
  cat > "$REPO_ROOT/AGENTS.md" << 'AGENTS_POINTER_EOF'
# Engineering Standards (pointer)

This repo follows the shared engineering standards maintained in the
`.standards/` git submodule. This file is a real file, not a symlink, on
purpose: CI and hosting platforms check out without initializing submodules,
and a dangling `AGENTS.md` symlink crashes builds that stat it (a Next dev
server fails with ENOENT at startup, before compiling anything).

Run `git submodule update --init --recursive`, then read the full standards
index at [.standards/AGENTS.md](.standards/AGENTS.md).
AGENTS_POINTER_EOF
}

remove_okf_symlink() {
  if [ -L "$REPO_ROOT/okf" ]; then
    rm "$REPO_ROOT/okf"
    ACT_CREATED=$((ACT_CREATED + 1))
    echo "  INFO: removed the root okf symlink — reference .standards/okf/ directly"
  fi
}

# Per-file bookkeeping every act_* verb that writes a catalog item shares:
# ENTRY_DEST is the absolute destination, ACT_APPLIED counts the entry as
# handled, DETAIL lists it. One reason to change — the outcome-accounting
# contract (CREATED / SKIPPED (exists) / REFUSED) — so it lives once.
track_file_entry() { # REPO_RELATIVE_PATH
  ENTRY_DEST="$REPO_ROOT/$1"
  ACT_APPLIED=$((ACT_APPLIED + 1))
  DETAIL="$DETAIL$1, "
}

act_pointer() { # real AGENTS.md pointer file, never a symlink
  local entry
  for entry in ${CAT_FILES[$1]}; do
    track_file_entry "$entry"
    if [ -L "$ENTRY_DEST" ]; then
      rm "$ENTRY_DEST"
      write_agents_pointer
      ACT_CREATED=$((ACT_CREATED + 1))
      echo "  INFO: replaced the $entry symlink with a real pointer file"
      continue
    fi
    if [ -f "$ENTRY_DEST" ]; then continue; fi
    write_agents_pointer
    ACT_CREATED=$((ACT_CREATED + 1))
  done
  remove_okf_symlink
}

act_bridge() { # opencode.json bridge template
  local entry
  for entry in ${CAT_FILES[$1]}; do
    track_file_entry "$entry"
    if [ -f "$ENTRY_DEST" ]; then
      warn_bridge_without_model_block "$entry" "$ENTRY_DEST"
      continue
    fi
    cp "$STANDARDS_DIR/templates/opencode.json.bridge" "$ENTRY_DEST"
    ACT_CREATED=$((ACT_CREATED + 1))
  done
}

warn_bridge_without_model_block() { # ENTRY EXISTING_FILE
  if ! grep -q '{env:SPEC_PIPELINE_MODEL}' "$2"; then
    echo "  WARN: existing $1 lacks the agent.*.model {env:SPEC_*_MODEL} block — copy it from templates/opencode.json.bridge so pipeline stages resolve per-model"
  fi
}

act_envrc() { # .envrc + .gitignore + config/.gitignore
  ACT_APPLIED=$((ACT_APPLIED + 1))
  DETAIL="$DETAIL.envrc, .gitignore, config/.gitignore, "
  if [ ! -f "$REPO_ROOT/.envrc" ]; then
    cp "$STANDARDS_DIR/templates/.envrc.child" "$REPO_ROOT/.envrc"
    ACT_CREATED=$((ACT_CREATED + 1))
  fi
  if ensure_line "$REPO_ROOT/.gitignore" ".envrc" \
       "# Per-machine direnv file (spec 025): never committed."; then
    ACT_CREATED=$((ACT_CREATED + 1))
  fi
  mkdir -p "$REPO_ROOT/config"
  if ensure_line "$REPO_ROOT/config/.gitignore" "model.local.env"; then
    ACT_CREATED=$((ACT_CREATED + 1))
  fi
  if ensure_line "$REPO_ROOT/config/.gitignore" "agent.local.env"; then
    ACT_CREATED=$((ACT_CREATED + 1))
  fi
}

act_gitattributes() {
  local entry
  for entry in ${CAT_FILES[$1]}; do
    track_file_entry "$entry"
    if [ -f "$ENTRY_DEST" ]; then continue; fi
    write_gitattributes "$ENTRY_DEST"
    ACT_CREATED=$((ACT_CREATED + 1))
  done
}

write_gitattributes() { # FILE
  cat > "$1" << 'GITATTR_EOF'
# Normalize line endings regardless of core.autocrlf: LF everywhere except
# explicit Windows scripts.
* text=auto eol=lf
*.sh text eol=lf
Makefile* text eol=lf
*.bat text eol=crlf
GITATTR_EOF
}

act_pr_template() {
  local entry
  for entry in ${CAT_FILES[$1]}; do
    track_file_entry "$entry"
    if [ -f "$ENTRY_DEST" ]; then continue; fi
    mkdir -p "$(dirname "$ENTRY_DEST")"
    cp "$STANDARDS_DIR/templates/PULL_REQUEST_TEMPLATE.md" "$ENTRY_DEST"
    ACT_CREATED=$((ACT_CREATED + 1))
  done
}

# Copy one DEST:SRC item as an executable script.
copy_executable() { # ITEM
  split_item "$1"
  ACT_APPLIED=$((ACT_APPLIED + 1))
  DETAIL="$DETAIL$ITEM_DEST, "
  if [ -f "$REPO_ROOT/$ITEM_DEST" ]; then return 0; fi
  cp "$STANDARDS_DIR/$ITEM_SRC" "$REPO_ROOT/$ITEM_DEST"
  chmod +x "$REPO_ROOT/$ITEM_DEST"
  ACT_CREATED=$((ACT_CREATED + 1))
}

copy_each_executable() { # INDEX — every files item of the row, +x
  local entry
  for entry in ${CAT_FILES[$1]}; do
    copy_executable "$entry"
  done
}

act_session_scripts() { # copy + chmod +x
  copy_each_executable "$1"
}

act_git_hook() { # copy + chmod +x + core.hooksPath
  mkdir -p "$REPO_ROOT/.githooks"
  copy_each_executable "$1"
  set_hooks_path
}

set_hooks_path() {
  if git -C "$REPO_ROOT" config core.hooksPath .githooks 2>/dev/null; then
    echo "  INFO: core.hooksPath = .githooks"
  else
    echo "  WARN: could not set core.hooksPath — run manually: git config core.hooksPath .githooks"
  fi
}

act_opencode_wiring() { # symlink by default, real copies with --copy-agents
  local entry dest base src
  mkdir -p "$REPO_ROOT/.opencode"
  for entry in ${CAT_FILES[$1]}; do
    dest="$REPO_ROOT/$entry"
    base="${entry##*/}"
    src="$STANDARDS_DIR/$base"
    ACT_APPLIED=$((ACT_APPLIED + 1))
    DETAIL="$DETAIL$entry, "
    if [ -e "$dest" ] || [ -L "$dest" ]; then continue; fi
    if [ "$COPY_AGENTS" = true ]; then
      cp -r "$src" "$dest"
    else
      ln -s "../.standards/$base" "$dest"
    fi
    ACT_CREATED=$((ACT_CREATED + 1))
  done
}

# Accounts for the {ci} placeholder: init-ci.sh writes those files, not this
# verb, but they are part of the row's write plan.
ci_plan_detail() {
  ACT_APPLIED=$((ACT_APPLIED + 1))
  DETAIL="$DETAIL$(ci_target_files | paste -sd', ' -)"
  DETAIL="$DETAIL, "
}

act_copy_template() { # every DEST:SRC / +DEST:SRC item in the row
  local entry
  for entry in ${CAT_FILES[$1]}; do
    if [ "$entry" = "{ci}" ]; then
      ci_plan_detail
      continue
    fi
    apply_copy_item "$entry"
  done
}

apply_copy_item() { # ITEM — copy one template item, reporting it in DETAIL
  local rc=0
  split_item "$1"
  if [ -n "$ITEM_QUAL" ] && ! qualifier_present "$ITEM_QUAL"; then
    return 0
  fi
  copy_item "$ITEM_DEST" "$ITEM_SRC" "$ITEM_APPEND" || rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "  WARN: template not shipped: $ITEM_SRC"
    return 0
  fi
  ACT_APPLIED=$((ACT_APPLIED + 1))
  DETAIL="$DETAIL$ITEM_DEST, "
  if [ "$rc" -eq 0 ]; then ACT_CREATED=$((ACT_CREATED + 1)); fi
}

act_merge_tsconfig() { # merge strict + noImplicitReturns into tsconfig*.json
  if ! command -v node >/dev/null 2>&1; then
    echo "  WARN: node not found — enable strict: true manually in tsconfig*.json"
    return 0
  fi
  merge_tsconfig_files
}

merge_tsconfig_files() {
  local tsconf
  for tsconf in "$REPO_ROOT"/tsconfig*.json; do
    [ -e "$tsconf" ] || continue
    merge_one_tsconfig "$tsconf"
  done
}

merge_one_tsconfig() { # FILE
  node -e '
      const fs = require("fs");
      const p = process.argv[1];
      let j;
      try { j = JSON.parse(fs.readFileSync(p, "utf8")); }
      catch { console.log("  WARN: " + p + " — not plain JSON (comments present); enable strict:true manually"); process.exit(0); }
      const c = j.compilerOptions || {};
      if (c.strict === true && c.noImplicitReturns === true) { process.exit(0); }
      j.compilerOptions = Object.assign({}, c);
      if (j.compilerOptions.strict !== true) j.compilerOptions.strict = true;
      if (j.compilerOptions.noImplicitReturns !== true) j.compilerOptions.noImplicitReturns = true;
      fs.writeFileSync(p, JSON.stringify(j, null, 2) + "\n");
      console.log("  INFO: strict + noImplicitReturns merged into " + p);
    ' "$1" || echo "  WARN: merge failed for $1 — check manually"
}

# ── init-ci.sh invocation ─────────────────────
ci_target_exists() {
  local f
  for f in $(ci_target_files); do
    if [ -f "$REPO_ROOT/$f" ]; then return 0; fi
  done
  return 1
}

run_init_ci() {
  INIT_CI_RESULT=""
  if [ -z "$INIT_CI_ARGS" ]; then return 0; fi
  if ci_target_exists; then
    INIT_CI_RESULT="SKIPPED (exists)"
    return 0
  fi
  echo ""
  echo "--- CI generation (init-ci.sh $INIT_CI_ARGS) ---"
  local rc=0
  # shellcheck disable=SC2086  # INIT_CI_ARGS is a flag string, deliberately word-split
  ( cd "$REPO_ROOT" && bash "$STANDARDS_DIR/scripts/init-ci.sh" $INIT_CI_ARGS ) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ERROR: init-ci.sh failed (exit $rc)" >&2
    exit 1
  fi
  INIT_CI_RESULT="CREATED"
}

report_init_ci_entries() {
  local i
  if [ -z "$INIT_CI_RESULT" ]; then return 0; fi
  for i in "${!CAT_IDS[@]}"; do
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    if [ "${CAT_ACTIONS[$i]}" != "none" ]; then continue; fi
    if [ -n "${SKIP_REASONS[$i]:-}" ]; then continue; fi
    printf '%s %s: %s [init-ci: %s]\n' "$INIT_CI_RESULT" "${CAT_IDS[$i]}" \
      "$(render_files "$i")" "${CAT_INITCI[$i]}"
  done
}

# ── execution ─────────────────────────────────
run_capability() { # run_capability INDEX
  local i="$1" id="${CAT_IDS[$1]}"
  if [ "${CAT_ACTIONS[$i]}" = "information" ]; then
    refused "informational only — no files are written for this capability" "$id"
    return 0
  fi
  ACT_APPLIED=0
  ACT_CREATED=0
  DETAIL=""
  run_capability_actions "$i" "$id"
  DETAIL="${DETAIL%, }"
  report_capability "$id"
}

run_capability_actions() { # INDEX ID — one act_* call per action verb in the row
  local i="$1" id="$2" a actions
  actions=$(printf '%s' "${CAT_ACTIONS[$i]}" | tr ',' ' ')
  for a in $actions; do
    dispatch_action "$a" "$i" "$id"
  done
}

dispatch_action() { # VERB INDEX ID
  local a="$1" fn
  fn="act_$(printf '%s' "$1" | tr '-' '_')"
  if ! declare -F "$fn" >/dev/null; then
    echo "ERROR: unknown action '$a' in catalog row $3" >&2
    exit 1
  fi
  "$fn" "$2"
}

report_capability() { # ID — the one outcome line for this capability
  if [ "$ACT_APPLIED" -eq 0 ]; then
    refused "no catalog asset applies to the selected stacks" "$1"
    return 0
  fi
  if [ "$ACT_CREATED" -gt 0 ]; then
    created "$1" "$DETAIL"
  else
    skipped "$1" "$DETAIL"
  fi
}

execute_all() {
  local i
  for i in "${!CAT_IDS[@]}"; do
    if report_skipped_row "$i"; then continue; fi
    if ! is_selected "${CAT_IDS[$i]}"; then continue; fi
    if [ "${CAT_ACTIONS[$i]}" = "none" ]; then continue; fi
    run_capability "$i"
  done
  run_init_ci
  report_init_ci_entries
  print_summary
}
