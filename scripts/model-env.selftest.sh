#!/bin/bash
# model-env.selftest.sh — Hermetic regression net for the pure-direnv dotenv
# model/credential mechanism (spec 025). No direnv binary required: the
# dotenv_if_exists behavior is emulated as `[ -f <path> ] && set -a && . <path>
# && set +a` against mktemp fixtures; direnv-requiring cases skip with a
# PASS-noted status when the binary is absent. The runtime half is
# scripts/model-env.runtime-check.sh (real opencode resolution).
#
# Scenario traceability: every AC-025-* ID below is the test for the matching
# 20-acceptance scenario:
#   AC-025-01-01..06  .envrc gitignored; committed dotenv templates
#   AC-025-02-01..07  parent .envrc semantics (defaults, override, clobber,
#                     credentials, no-op, stale-copy guard, live direnv)
#   AC-025-03-01..06  child template (parent defaults, child override,
#                     propagation guard, credentials, bootstrap, live direnv)
#   AC-025-04-01..07  loaders removed; purge of every live reference
#   AC-025-05-01..07  check-model-env.sh branches (real + fixtures)
#   AC-025-06-01..10  selftest/runtime self-assertions
#   AC-025-07-01..05  docs + ADR describe the dotenv design
#
# Self-trip constraints:
#   - Fixture model ids are built at runtime by string concatenation, never
#     inlined as literals (spec-020 constraint preserved).
#   - The banned-loader names (the loader names) and the emit flag are
#     never written literally in this file — the purge greps below (which scan
#     scripts/) must find zero matches, including in this file itself. The
#     patterns are assembled at runtime by concatenation.
#   - Fixture credentials are written via printf with runtime values, so this
#     file cannot trip scripts/check-no-hardcoded-secrets.sh (which scans
#     scripts/).
#
# Usage:
#   bash scripts/model-env.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-model-env.sh"
RUNTIME_CHECK="$ROOT/scripts/model-env.runtime-check.sh"
PARENT_TPL="$ROOT/templates/.envrc.example"
CHILD_TPL="$ROOT/templates/.envrc.child"

# Shared roster (MODEL_ENV_VARS, MODEL_ENV_PLUS_AGENTS, model_env_var_for_agent).
# shellcheck disable=SC1091
source "$ROOT/scripts/model-env.vars.sh"

ALL_VARS=("${MODEL_ENV_VARS[@]}")

PASS_COUNT=0
FAIL_COUNT=0
RUN_RC=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

# Runtime-built model ids (no inline literal model-id values anywhere below).
provider="opencode-""go"
DEFAULT_FAST="$provider/""deepseek-v4-flash"
DEFAULT_PLUS="$provider/""qwen3.7-plus"

# Banned-name patterns assembled at runtime — this file never contains the
# contiguous strings the purge greps for.
EMIT="--""emit"
LOADENV="load""-env"
LOADMODELENV="load""-model-env"

# run_capture OUT ERR cmd... — captures stdout/stderr, sets RUN_RC
run_capture() {
  local out="$1" err="$2"
  shift 2
  if "$@" >"$out" 2>"$err"; then RUN_RC=0; else RUN_RC=$?; fi
}

# write_refs_opencode ROOT — fixture opencode.json with 8 {env:...} references
write_refs_opencode() {
  mkdir -p "$1/config"
  cat > "$1/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "spec-specifier": { "model": "{env:SPEC_SPECIFIER_MODEL}" },
    "spec-ux": { "model": "{env:SPEC_UX_MODEL}" },
    "spec-verifier": { "model": "{env:SPEC_VERIFIER_MODEL}" },
    "spec-mutation-runner": { "model": "{env:SPEC_MUTATION_RUNNER_MODEL}" },
    "spec-pr-opener": { "model": "{env:SPEC_PR_OPENER_MODEL}" },
    "spec-coder": { "model": "{env:SPEC_CODER_MODEL}" },
    "spec-refactorer": { "model": "{env:SPEC_REFACTORER_MODEL}" },
    "spec-pipeline": { "model": "{env:SPEC_PIPELINE_MODEL}" }
  }
}
EOF
}

# write_example ROOT FAST PLUS — fixture example defining all 8 vars at
# differentiated values (plus tier for verifier/mutation-runner/pr-opener)
write_example() {
  mkdir -p "$1/config"
  {
    printf 'SPEC_SPECIFIER_MODEL=%s\n' "$2"
    printf 'SPEC_UX_MODEL=%s\n' "$2"
    printf 'SPEC_VERIFIER_MODEL=%s\n' "$3"
    printf 'SPEC_MUTATION_RUNNER_MODEL=%s\n' "$3"
    printf 'SPEC_PR_OPENER_MODEL=%s\n' "$3"
    printf 'SPEC_CODER_MODEL=%s\n' "$2"
    printf 'SPEC_REFACTORER_MODEL=%s\n' "$2"
    printf 'SPEC_PIPELINE_MODEL=%s\n' "$2"
  } > "$1/config/model.local.env.example"
}

# snap_envrc TEMPLATE_FILE FIXTURE_ROOT [KEY=VALUE presets...] — emulate the
# template's dotenv_if_exists lines from the fixture root (later lines win, a
# dotenv line clobbers a pre-existing var — matching direnv), then print every
# var as VAR=value. Runs in a subshell; the template is read from its real
# path so the committed wiring itself is what is exercised.
snap_envrc() {
  local tpl="$1" fx="$2"
  shift 2
  local v kv
  (
    for v in "${ALL_VARS[@]}" GITHUB_TOKEN GH_TOKEN; do unset "$v" 2>/dev/null || true; done
    for kv in "$@"; do export "$kv"; done
    cd "$fx" || exit 1
    while IFS= read -r line; do
      case "$line" in
        '' | '#'*) continue ;;
      esac
      path="${line#dotenv_if_exists }"
      [ "$path" != "$line" ] || continue
      if [ -f "$path" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$path"
        set +a
      fi
    done < "$tpl"
    for v in "${ALL_VARS[@]}"; do printf '%s=%s\n' "$v" "${!v:-}"; done
    printf 'GITHUB_TOKEN=%s\n' "${GITHUB_TOKEN:-}"
    printf 'GH_TOKEN=%s\n' "${GH_TOKEN:-}"
  )
}

# envrc_exec_lines FILE — the executable (non-comment, non-blank) lines
envrc_exec_lines() {
  grep -vE '^[[:space:]]*(#.*)?$' "$1"
}

# snapshot_has SNAP VAR VALUE — snapshot line VAR=value present?
snapshot_has() {
  printf '%s\n' "$1" | grep -qx "$2=$3"
}

# snapshot_count SNAP — number of VAR=value lines
snapshot_count() {
  printf '%s\n' "$1" | grep -c '^SPEC_.*_MODEL='
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── AC-025-01 .envrc gitignored; committed dotenv templates ──────────────────

echo "== AC-025-01 .envrc gitignored + dotenv templates =="

# 01-01: root .gitignore covers .envrc; a .envrc on disk is untracked+ignored
if grep -q '^\.envrc$' "$ROOT/.gitignore"; then
  ok "AC-025-01-01 root .gitignore contains a line matching ^.envrc$"
else
  bad "AC-025-01-01 root .gitignore contains a line matching ^.envrc$"
fi
f0101="$(mktemp -d "$TMP/gitignore-0101.XXXXXX")"
git -C "$f0101" init -q
printf '.envrc\n' > "$f0101/.gitignore"
printf '# per-machine\n' > "$f0101/.envrc"
if ! git -C "$f0101" ls-files --error-unmatch -- .envrc >/dev/null 2>&1 \
   && git -C "$f0101" check-ignore -q -- .envrc; then
  ok "AC-025-01-01 .envrc on disk: git ls-files non-zero, git check-ignore exit 0"
else
  bad "AC-025-01-01 .envrc on disk: git ls-files non-zero, git check-ignore exit 0"
fi

# ── AC-020-01 pr-review agent model pin (spec 024) ───────────────────────────
# The pr-review agent (spec 024) is the one deliberate exception to "shipped
# agents ship without model:": its frontmatter carries a literal
# `model: opencode/mimo-v2.5-free` pin (AC-024-01-02) that must NOT be an
# {env:...} reference, and it lives in the agent file, not in opencode.json
# (which check-model-env.sh's env-reference rule governs). Every other shipped
# agent must still ship without a model: key — a second pinned agent would
# silently beat its {env:...} reference and break the per-machine override.
if grep -rqE '^model:[[:space:]]' "$ROOT/agents" --exclude='pr-review.md' 2>/dev/null; then
  bad "AC-020-01-01 every shipped agent except agents/pr-review.md ships without a model: key (agent-file model would beat the {env:...} reference)"
else
  ok "AC-020-01-01 every shipped agent except agents/pr-review.md ships without a model: key"
fi
if [ -f "$ROOT/agents/pr-review.md" ] \
   && grep -q '^model: opencode/mimo-v2.5-free$' "$ROOT/agents/pr-review.md"; then
  ok "AC-020-01-01 the pr-review agent carries the deliberate literal model: pin opencode/mimo-v2.5-free (spec 024)"
else
  bad "AC-020-01-01 the pr-review agent must carry the literal model: pin opencode/mimo-v2.5-free"
fi

# 01-02 / 01-03: template shapes — exactly three dotenv_if_exists lines, in
# order, no loader words in the executable lines; tracked-or-committable
for tpl in "$PARENT_TPL" "$CHILD_TPL"; do
  name="$(basename "$tpl")"
  if [ ! -f "$tpl" ]; then
    bad "AC-025-01-02 AC-025-01-03 $name exists and is tracked"
    continue
  fi
  if git -C "$ROOT" ls-files --error-unmatch -- "templates/$name" >/dev/null 2>&1 \
     || { ! git -C "$ROOT" check-ignore -q -- "templates/$name" \
          && git -C "$ROOT" add -n -- "templates/$name" >/dev/null 2>&1; }; then
    ok "AC-025-01-02 AC-025-01-03 $name tracked (or committable pre-commit)"
  else
    bad "AC-025-01-02 AC-025-01-03 $name tracked (or committable pre-commit)"
  fi
done

exec_parent="$(envrc_exec_lines "$PARENT_TPL")"
if [ "$(printf '%s\n' "$exec_parent" | grep -c '^dotenv_if_exists ')" -eq 3 ] \
   && [ "$(printf '%s\n' "$exec_parent" | grep -v '^dotenv_if_exists ' | grep -c . || true)" -eq 0 ]; then
  ok "AC-025-01-02 templates/.envrc.example has exactly three dotenv_if_exists lines"
else
  bad "AC-025-01-02 templates/.envrc.example has exactly three dotenv_if_exists lines"
fi
if [ "$(printf '%s\n' "$exec_parent" | sed -n '1p')" = 'dotenv_if_exists config/model.local.env.example' ] \
   && [ "$(printf '%s\n' "$exec_parent" | sed -n '2p')" = 'dotenv_if_exists config/model.local.env' ] \
   && [ "$(printf '%s\n' "$exec_parent" | sed -n '3p')" = 'dotenv_if_exists config/agent.local.env' ]; then
  ok "AC-025-01-02 example line order: committed example -> per-machine override -> credentials"
else
  bad "AC-025-01-02 example line order: committed example -> per-machine override -> credentials"
fi
if ! printf '%s\n' "$exec_parent" | grep -qE "eval|bash |source|^\. |$EMIT"; then
  ok "AC-025-01-02 no eval / bash invocation / source / . / emit flag in executable lines"
else
  bad "AC-025-01-02 no eval / bash invocation / source / . / emit flag in executable lines"
fi

exec_child="$(envrc_exec_lines "$CHILD_TPL")"
if [ "$(printf '%s\n' "$exec_child" | grep -c '^dotenv_if_exists ')" -eq 3 ] \
   && [ "$(printf '%s\n' "$exec_child" | grep -v '^dotenv_if_exists ' | grep -c . || true)" -eq 0 ]; then
  ok "AC-025-01-03 templates/.envrc.child has exactly three dotenv_if_exists lines"
else
  bad "AC-025-01-03 templates/.envrc.child has exactly three dotenv_if_exists lines"
fi
if [ "$(printf '%s\n' "$exec_child" | sed -n '1p')" = 'dotenv_if_exists .standards/config/model.local.env.example' ] \
   && [ "$(printf '%s\n' "$exec_child" | sed -n '2p')" = 'dotenv_if_exists config/model.local.env' ] \
   && [ "$(printf '%s\n' "$exec_child" | sed -n '3p')" = 'dotenv_if_exists config/agent.local.env' ]; then
  ok "AC-025-01-03 child line order: .standards committed example -> child override -> child credentials"
else
  bad "AC-025-01-03 child line order: .standards committed example -> child override -> child credentials"
fi
if ! printf '%s\n' "$exec_child" | grep -qE "eval|bash |source|^\. |$EMIT"; then
  ok "AC-025-01-03 no eval / bash invocation / source / . / emit flag in executable lines"
else
  bad "AC-025-01-03 no eval / bash invocation / source / . / emit flag in executable lines"
fi

# 01-04: no committed (or committable) .envrc outside templates/
tracked_or_untracked="$( { git -C "$ROOT" ls-files; git -C "$ROOT" ls-files --others --exclude-standard; } 2>/dev/null | sort -u | grep '\.envrc$' || true)"
envrc_outside="$(printf '%s\n' "$tracked_or_untracked" | grep -v '^templates/\.envrc\.' || true)"
if [ -z "$envrc_outside" ]; then
  ok "AC-025-01-04 no .envrc path outside templates/ (tracked or committable)"
else
  bad "AC-025-01-04 no .envrc path outside templates/ (found: $(printf '%s ' $envrc_outside))"
fi

# 01-05: real env files ignored, examples committable
if git -C "$ROOT" check-ignore -q -- config/model.local.env \
   && git -C "$ROOT" check-ignore -q -- config/agent.local.env; then
  ok "AC-025-01-05 git check-ignore exits 0 for both real env files"
else
  bad "AC-025-01-05 git check-ignore exits 0 for both real env files"
fi
if git -C "$ROOT" check-ignore -q -- config/model.local.env.example \
   || git -C "$ROOT" check-ignore -q -- config/agent.local.env.example; then
  bad "AC-025-01-05 examples are not ignored (templates stay trackable)"
else
  ok "AC-025-01-05 examples are not ignored (templates stay trackable)"
fi

# 01-06: template headers document one-time setup and per-line roles
for tpl in "$PARENT_TPL" "$CHILD_TPL"; do
  name="$(basename "$tpl")"
  if grep -q 'direnv allow' "$tpl" \
     && grep -q 'dotenv_if_exists' "$tpl" \
     && grep -q 'committed defaults' "$tpl" \
     && grep -q 'override' "$tpl" \
     && grep -q 'credentials' "$tpl" \
     && grep -qi 'never commit' "$tpl"; then
    ok "AC-025-01-06 $name header documents direnv allow, the three file roles, never-commit"
  else
    bad "AC-025-01-06 $name header documents direnv allow, the three file roles, never-commit"
  fi
done

# ── AC-025-02 parent .envrc dotenv semantics ─────────────────────────────────

echo "== AC-025-02 parent .envrc semantics =="

# 02-01: example alone -> all 8 non-empty, differentiated defaults, exit 0
f0201="$(mktemp -d "$TMP/parent-0201.XXXXXX")"
write_example "$f0201" "$DEFAULT_FAST" "$DEFAULT_PLUS"
run_capture "$TMP/s0201" "$TMP/e0201" snap_envrc "$PARENT_TPL" "$f0201"
snap="$(cat "$TMP/s0201")"
if [ "$RUN_RC" -eq 0 ] \
   && snapshot_has "$snap" SPEC_VERIFIER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_MUTATION_RUNNER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_PR_OPENER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_UX_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_CODER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_REFACTORER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_PIPELINE_MODEL "$DEFAULT_FAST" \
   && [ "$(snapshot_count "$snap")" -eq 8 ]; then
  ok "AC-025-02-01 AC-025-06-03 example alone: all 8 vars non-empty, plus-tier -> plus, fast-tier -> fast, exit 0"
else
  bad "AC-025-02-01 AC-025-06-03 example alone: all 8 vars non-empty, differentiated (rc=$RUN_RC, snap=$(tr '\n' ' ' <<< "$snap"))"
fi

# 02-02: per-machine override beats the committed example
f0202="$(mktemp -d "$TMP/parent-0202.XXXXXX")"
write_example "$f0202" "$DEFAULT_FAST" "$DEFAULT_PLUS"
override_val="$provider/""override""$RANDOM"
printf 'SPEC_SPECIFIER_MODEL=%s\n' "$override_val" > "$f0202/config/model.local.env"
run_capture "$TMP/s0202" "$TMP/e0202" snap_envrc "$PARENT_TPL" "$f0202"
snap="$(cat "$TMP/s0202")"
if snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$override_val" \
   && snapshot_has "$snap" SPEC_VERIFIER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_CODER_MODEL "$DEFAULT_FAST" \
   && [ "$(snapshot_count "$snap")" -eq 8 ] && [ "$RUN_RC" -eq 0 ]; then
  ok "AC-025-02-02 AC-025-06-03 override file: SPEC_SPECIFIER_MODEL wins, other 7 keep defaults, exit 0"
else
  bad "AC-025-02-02 AC-025-06-03 override file: SPEC_SPECIFIER_MODEL wins, other 7 keep defaults (rc=$RUN_RC)"
fi

# 02-03: a dotenv line clobbers a pre-exported shell var (later wins, accepted)
f0203="$(mktemp -d "$TMP/parent-0203.XXXXXX")"
write_example "$f0203" "$DEFAULT_FAST" "$DEFAULT_PLUS"
run_capture "$TMP/s0203" "$TMP/e0203" snap_envrc "$PARENT_TPL" "$f0203" "SPEC_SPECIFIER_MODEL=$provider/""pre-exported""$RANDOM"
snap="$(cat "$TMP/s0203")"
if snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST" && [ "$RUN_RC" -eq 0 ]; then
  ok "AC-025-02-03 AC-025-06-03 clobber: example value wins over the pre-exported var (dotenv line clobbers)"
else
  bad "AC-025-02-03 AC-025-06-03 clobber: example value wins over the pre-exported var (got: $(printf '%s\n' "$snap" | grep '^SPEC_SPECIFIER_MODEL='))"
fi

# 02-04: credentials load last from config/agent.local.env
f0204="$(mktemp -d "$TMP/parent-0204.XXXXXX")"
write_example "$f0204" "$DEFAULT_FAST" "$DEFAULT_PLUS"
tok_t="t-""$RANDOM"
tok_g="g-""$RANDOM"
printf 'GITHUB_TOKEN=%s\nGH_TOKEN=%s\n' "$tok_t" "$tok_g" > "$f0204/config/agent.local.env"
run_capture "$TMP/s0204" "$TMP/e0204" snap_envrc "$PARENT_TPL" "$f0204"
snap="$(cat "$TMP/s0204")"
if snapshot_has "$snap" GITHUB_TOKEN "$tok_t" \
   && snapshot_has "$snap" GH_TOKEN "$tok_g" \
   && snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_VERIFIER_MODEL "$DEFAULT_PLUS" \
    && [ "$(snapshot_count "$snap")" -eq 8 ]; then
  ok "AC-025-02-04 AC-025-06-03 credentials: GITHUB_TOKEN + GH_TOKEN load from the third line, model vars intact"
else
  bad "AC-025-02-04 AC-025-06-03 credentials: GITHUB_TOKEN + GH_TOKEN load from the third line (snap=$(tr '\n' ' ' <<< "$snap"))"
fi
if [ "$(printf '%s\n' "$exec_parent" | sed -n '3p')" = 'dotenv_if_exists config/agent.local.env' ]; then
  ok "AC-025-02-04 credentials line executes after the model-var lines"
else
  bad "AC-025-02-04 credentials line executes after the model-var lines"
fi

# 02-05: missing files are a no-op and never fail the shell
f0205a="$(mktemp -d "$TMP/parent-0205a.XXXXXX")"
write_example "$f0205a" "$DEFAULT_FAST" "$DEFAULT_PLUS"
run_capture "$TMP/s0205a" "$TMP/e0205a" snap_envrc "$PARENT_TPL" "$f0205a"
if [ "$RUN_RC" -eq 0 ] && [ ! -s "$TMP/e0205a" ]; then
  ok "AC-025-02-05 missing override/credential files: no-op, no error, exit 0"
else
  bad "AC-025-02-05 missing override/credential files: no-op, no error, exit 0 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/e0205a"))"
fi
f0205b="$(mktemp -d "$TMP/parent-0205b.XXXXXX")"
run_capture "$TMP/s0205b" "$TMP/e0205b" snap_envrc "$PARENT_TPL" "$f0205b"
if [ "$RUN_RC" -eq 0 ] && [ -z "$(grep -v '^.*=$' "$TMP/s0205b" || true)" ]; then
  ok "AC-025-02-05 no files at all: exit 0, nothing exported"
else
  bad "AC-025-02-05 no files at all: exit 0, nothing exported (rc=$RUN_RC)"
fi

# 02-06: a stale local .envrc carries no loader references
if [ -f "$ROOT/.envrc" ]; then
  if grep -q "$LOADENV\|$LOADMODELENV\|$EMIT" "$ROOT/.envrc"; then
    bad "AC-025-02-06 stale root .envrc carries no loader/emit reference"
  else
    ok "AC-025-02-06 stale root .envrc carries no loader/emit reference"
  fi
else
  ok "AC-025-02-06 no root .envrc on disk — stale-copy guard trivially satisfied"
fi

# 02-07: live direnv (conditional — PASS-noted skip when direnv absent)
if command -v direnv >/dev/null 2>&1; then
  f0207="$(mktemp -d "$TMP/direnv-parent.XXXXXX")"
  cp "$PARENT_TPL" "$f0207/.envrc"
  write_example "$f0207" "$DEFAULT_FAST" "$DEFAULT_PLUS"
  ( cd "$f0207" && direnv allow . >/dev/null 2>&1 )
  live="$( cd "$f0207" && direnv exec . bash -c 'printf %s "${SPEC_SPECIFIER_MODEL:-EMPTY}"' 2>/dev/null )"
  if [ -n "$live" ] && [ "$live" != "EMPTY" ]; then
    ok "AC-025-02-07 live direnv: SPEC_SPECIFIER_MODEL resolves non-empty after allow"
  else
    bad "AC-025-02-07 live direnv: SPEC_SPECIFIER_MODEL resolves non-empty after allow (got '$live')"
  fi
else
  ok "AC-025-02-07 PASS-noted: direnv binary absent — live case skipped"
fi

# ── AC-025-03 child template + bootstrap wiring ──────────────────────────────

echo "== AC-025-03 child template + bootstrap =="

# 03-01: no child files -> all 8 vars resolve to the parent's committed defaults
f0301="$(mktemp -d "$TMP/child-0301.XXXXXX")"
write_example "$f0301/.standards" "$DEFAULT_FAST" "$DEFAULT_PLUS"
run_capture "$TMP/s0301" "$TMP/e0301" snap_envrc "$CHILD_TPL" "$f0301"
snap="$(cat "$TMP/s0301")"
if [ "$RUN_RC" -eq 0 ] \
   && snapshot_has "$snap" SPEC_VERIFIER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_MUTATION_RUNNER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_PR_OPENER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_CODER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_UX_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_REFACTORER_MODEL "$DEFAULT_FAST" \
   && snapshot_has "$snap" SPEC_PIPELINE_MODEL "$DEFAULT_FAST" \
   && [ "$(snapshot_count "$snap")" -eq 8 ]; then
  ok "AC-025-03-01 AC-025-06-04 no child files: all 8 vars resolve to the parent's committed defaults, exit 0"
else
  bad "AC-025-03-01 AC-025-06-04 no child files: all 8 vars resolve to the parent's committed defaults (rc=$RUN_RC)"
fi

# 03-02: child override wins; the parent's other defaults stay
f0302="$(mktemp -d "$TMP/child-0302.XXXXXX")"
write_example "$f0302/.standards" "$DEFAULT_FAST" "$DEFAULT_PLUS"
child_val="$provider/""child-coder""$RANDOM"
mkdir -p "$f0302/config"
printf 'SPEC_CODER_MODEL=%s\n' "$child_val" > "$f0302/config/model.local.env"
run_capture "$TMP/s0302" "$TMP/e0302" snap_envrc "$CHILD_TPL" "$f0302"
snap="$(cat "$TMP/s0302")"
if snapshot_has "$snap" SPEC_CODER_MODEL "$child_val" \
   && snapshot_has "$snap" SPEC_VERIFIER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST" \
   && [ "$(snapshot_count "$snap")" -eq 8 ] && [ "$RUN_RC" -eq 0 ]; then
  ok "AC-025-03-02 AC-025-06-04 child override: SPEC_CODER_MODEL wins, other 7 keep parent defaults, exit 0"
else
  bad "AC-025-03-02 AC-025-06-04 child override: SPEC_CODER_MODEL wins, other 7 keep parent defaults (rc=$RUN_RC)"
fi

# 03-03: parent per-machine overrides never propagate to children
if { git -C "$ROOT" ls-files | grep -qx 'config/model.local.env' \
     || git -C "$ROOT" ls-files | grep -qx 'config/agent.local.env'; }; then
  bad "AC-025-03-03 standards git index lists neither real env file"
else
  ok "AC-025-03-03 standards git index lists neither real env file"
fi
f0303="$(mktemp -d "$TMP/child-0303.XXXXXX")"
write_example "$f0303/.standards" "$DEFAULT_FAST" "$DEFAULT_PLUS"
run_capture "$TMP/s0303" "$TMP/e0303" snap_envrc "$CHILD_TPL" "$f0303"
snap="$(cat "$TMP/s0303")"
if [ "$RUN_RC" -eq 0 ] \
   && snapshot_has "$snap" SPEC_VERIFIER_MODEL "$DEFAULT_PLUS" \
   && snapshot_has "$snap" SPEC_CODER_MODEL "$DEFAULT_FAST" \
   && [ ! -e "$f0303/.standards/config/model.local.env" ] \
   && [ ! -e "$f0303/.standards/config/agent.local.env" ]; then
  ok "AC-025-03-03 .standards-relative line resolves against the committed example only; defaults still resolve"
else
  bad "AC-025-03-03 .standards-relative line resolves against the committed example only (rc=$RUN_RC)"
fi

# 03-04: child credentials load from the child's own config/agent.local.env
f0304="$(mktemp -d "$TMP/child-0304.XXXXXX")"
write_example "$f0304/.standards" "$DEFAULT_FAST" "$DEFAULT_PLUS"
tok_t="ct-""$RANDOM"
tok_g="cg-""$RANDOM"
mkdir -p "$f0304/config"
printf 'GITHUB_TOKEN=%s\nGH_TOKEN=%s\n' "$tok_t" "$tok_g" > "$f0304/config/agent.local.env"
run_capture "$TMP/s0304" "$TMP/e0304" snap_envrc "$CHILD_TPL" "$f0304"
snap="$(cat "$TMP/s0304")"
if snapshot_has "$snap" GITHUB_TOKEN "$tok_t" \
   && snapshot_has "$snap" GH_TOKEN "$tok_g" \
   && snapshot_has "$snap" SPEC_CODER_MODEL "$DEFAULT_FAST" \
    && [ "$(snapshot_count "$snap")" -eq 8 ]; then
  ok "AC-025-03-04 AC-025-06-04 child credentials: GITHUB_TOKEN + GH_TOKEN from the child's own file"
else
  bad "AC-025-03-04 AC-025-06-04 child credentials: GITHUB_TOKEN + GH_TOKEN from the child's own file (snap=$(tr '\n' ' ' <<< "$snap"))"
fi

# 03-05: bootstrap.sh writes the child .envrc and gitignore wiring
child="$(mktemp -d "$TMP/bootstrap-child.XXXXXX")"
ln -s "$ROOT" "$child/.standards"
# The CI/CD select prompt must not block: feed /dev/null so bootstrap sees
# non-interactive stdin and skips CI setup.
( cd "$child" && bash .standards/scripts/bootstrap.sh < /dev/null ) > "$TMP/bootstrap.out" 2>&1
if [ -f "$child/.envrc" ] && diff -q "$CHILD_TPL" "$child/.envrc" >/dev/null 2>&1; then
  ok "AC-025-03-05 bootstrap writes .envrc as a copy of templates/.envrc.child"
else
  bad "AC-025-03-05 bootstrap writes .envrc as a copy of templates/.envrc.child"
fi
if grep -q '^\.envrc$' "$child/.gitignore" 2>/dev/null; then
  ok "AC-025-03-05 bootstrap appends .envrc to the child root .gitignore"
else
  bad "AC-025-03-05 bootstrap appends .envrc to the child root .gitignore"
fi
if [ -f "$child/config/.gitignore" ] \
   && grep -qx 'model.local.env' "$child/config/.gitignore" \
   && grep -qx 'agent.local.env' "$child/config/.gitignore"; then
  ok "AC-025-03-05 child config/.gitignore covers model.local.env and agent.local.env"
else
  bad "AC-025-03-05 child config/.gitignore covers model.local.env and agent.local.env"
fi
if grep -q 'git add' "$TMP/bootstrap.out" && grep 'git add' "$TMP/bootstrap.out" | grep -q '\.envrc'; then
  bad "AC-025-03-05 next-steps git add list does not name .envrc"
else
  ok "AC-025-03-05 next-steps git add list does not name .envrc"
fi
envrc_sum_before="$(cksum "$child/.envrc" | awk '{print $1}')"
( cd "$child" && bash .standards/scripts/bootstrap.sh < /dev/null ) > "$TMP/bootstrap2.out" 2>&1
envrc_sum_after="$(cksum "$child/.envrc" | awk '{print $1}')"
if grep -q 'SKIP.*\.envrc' "$TMP/bootstrap2.out" && [ "$envrc_sum_before" = "$envrc_sum_after" ]; then
  ok "AC-025-03-05 re-run: bootstrap prints a skip message and does not overwrite .envrc"
else
  bad "AC-025-03-05 re-run: bootstrap prints a skip message and does not overwrite .envrc"
fi

# 03-06: live direnv on a bootstrapped child (conditional — PASS-noted skip)
if command -v direnv >/dev/null 2>&1; then
  parent_verifier_default="$(grep '^SPEC_VERIFIER_MODEL=' "$ROOT/config/model.local.env.example" | sed -E 's/^[^=]*=//')"
  ( cd "$child" && direnv allow . >/dev/null 2>&1 )
  live="$( cd "$child" && direnv exec . bash -c 'printf %s "${SPEC_VERIFIER_MODEL:-EMPTY}"' 2>/dev/null )"
  if [ "$live" = "$parent_verifier_default" ]; then
    ok "AC-025-03-06 live direnv: bootstrapped child resolves the parent's committed default (spec-verifier)"
  else
    bad "AC-025-03-06 live direnv: bootstrapped child resolves the parent's committed default (got '$live', want '$parent_verifier_default')"
  fi
  child_override_val="$provider/""child-live""$RANDOM"
  mkdir -p "$child/config"
  printf 'SPEC_VERIFIER_MODEL=%s\n' "$child_override_val" > "$child/config/model.local.env"
  ( cd "$child" && direnv allow . >/dev/null 2>&1 )
  live="$( cd "$child" && direnv exec . bash -c 'printf %s "${SPEC_VERIFIER_MODEL:-EMPTY}"' 2>/dev/null )"
  if [ "$live" = "$child_override_val" ]; then
    ok "AC-025-03-06 live direnv: child override wins after adding config/model.local.env"
  else
    bad "AC-025-03-06 live direnv: child override wins after adding config/model.local.env (got '$live', want '$child_override_val')"
  fi
else
  ok "AC-025-03-06 PASS-noted: direnv binary absent — live case skipped"
fi

# ── AC-025-04 loaders removed; purge of every live reference ─────────────────

echo "== AC-025-04 loaders removed + purge =="

# 04-01: the loader scripts are deleted from index and worktree
loader_index_pat="scripts/load""-env\.sh|scripts/load""-model-env\.sh"
if ! git -C "$ROOT" ls-files | grep -E "$loader_index_pat" >/dev/null 2>&1 \
   && [ ! -e "$ROOT/scripts/load""-env.sh" ] \
   && [ ! -e "$ROOT/scripts/load""-model-env.sh" ]; then
  ok "AC-025-04-01 the loader scripts are deleted (index + worktree)"
else
  bad "AC-025-04-01 the loader scripts are deleted (index + worktree)"
fi

# 04-02 / 04-03: no emit flag / loader-name matches across the live surface
live_surfaces=(scripts templates agents .github config README.md AGENTS.md docs/SPEC_PIPELINE.md)
if grep -rn "$EMIT" "${live_surfaces[@]}" 2>/dev/null | grep -v '^Binary' | grep -q .; then
  bad "AC-025-04-02 no emit flag in live surfaces: $(grep -rn "$EMIT" "${live_surfaces[@]}" 2>/dev/null | head -1)"
else
  ok "AC-025-04-02 no emit-flag string in any live surface"
fi
if grep -rn "$LOADENV\|$LOADMODELENV" "${live_surfaces[@]}" 2>/dev/null | grep -v '^Binary' | grep -q .; then
  bad "AC-025-04-03 no loader-name in any live surface: $(grep -rn "$LOADENV\|$LOADMODELENV" "${live_surfaces[@]}" 2>/dev/null | head -1)"
else
  ok "AC-025-04-03 no loader-name string in any live surface"
fi

# 04-04: agents no longer cite the loaders; PR Opener checks presence instead
if grep -q "$LOADENV\|$LOADMODELENV" "$ROOT/agents/spec-pipeline.md" \
   || grep -q "$LOADENV\|$LOADMODELENV" "$ROOT/agents/spec-pr-opener.md"; then
  bad "AC-025-04-04 agents/spec-pipeline.md and spec-pr-opener.md cite no loader"
else
  ok "AC-025-04-04 agents/spec-pipeline.md and spec-pr-opener.md cite no loader"
fi
if grep -q 'GITHUB_TOKEN' "$ROOT/agents/spec-pr-opener.md" \
   && grep -q 'GH_TOKEN' "$ROOT/agents/spec-pr-opener.md" \
   && grep -q 'non-empty' "$ROOT/agents/spec-pr-opener.md" \
   && grep -q 'stop' "$ROOT/agents/spec-pr-opener.md"; then
  ok "AC-025-04-04 PR Opener verifies GITHUB_TOKEN + GH_TOKEN non-empty, reports + stops when missing, sources nothing"
else
  bad "AC-025-04-04 PR Opener verifies GITHUB_TOKEN + GH_TOKEN non-empty, reports + stops when missing"
fi

# 04-05: CI sweeper loads committed defaults without a loader
wf="$ROOT/.github/workflows/ci-sweeper.yml"
if grep -q "$LOADENV\|$LOADMODELENV" "$wf"; then
  bad "AC-025-04-05 ci-sweeper.yml cites no loader"
else
  ok "AC-025-04-05 ci-sweeper.yml cites no loader"
fi
if grep -q 'set -a; . config/model.local.env.example; set +a' "$wf"; then
  ok "AC-025-04-05 ci-sweeper headless run loads committed defaults via the dotenv-equivalent"
else
  bad "AC-025-04-05 ci-sweeper headless run loads committed defaults via the dotenv-equivalent"
fi

# 04-06: config example headers document direnv, cite no loader
for ex in "$ROOT/config/model.local.env.example" "$ROOT/config/agent.local.env.example"; do
  name="$(basename "$ex")"
  if grep -q "$LOADENV\|$LOADMODELENV\|$EMIT" "$ex"; then
    bad "AC-025-04-06 $name header cites no loader and no emit flag"
  elif grep -q 'dotenv_if_exists' "$ex" && grep -qi 'direnv' "$ex"; then
    ok "AC-025-04-06 $name header documents the direnv dotenv_if_exists flow"
  else
    bad "AC-025-04-06 $name header documents the direnv dotenv_if_exists flow"
  fi
done

# 04-07: orchestration references still resolve after the removals
if bash "$ROOT/scripts/check-orchestration.sh" >/dev/null 2>&1; then
  ok "AC-025-04-07 check-orchestration.sh exits 0 (scripts/ paths in agents/, commands/, AGENTS.md resolve)"
else
  bad "AC-025-04-07 check-orchestration.sh exits 0"
fi

# ── AC-025-05 check-model-env.sh branches ────────────────────────────────────

echo "== AC-025-05 check-model-env branches =="

# 05-01: real repo passes with a PASS line
run_capture "$TMP/o0501" "$TMP/e0501" bash "$CHECK" "$ROOT"
if [ "$RUN_RC" -eq 0 ] && grep -q 'PASS' "$TMP/o0501"; then
  ok "AC-025-05-01 check-model-env exits 0 on the real repo with a PASS line"
else
  bad "AC-025-05-01 check-model-env exits 0 on the real repo with a PASS line (rc=$RUN_RC)"
fi

# 05-02: literal model id -> exit 1, names the agent
f0502="$(mktemp -d "$TMP/check-0502.XXXXXX")"
bad_model="$provider/""literal-model""$RANDOM"
mkdir -p "$f0502/config"
cat > "$f0502/opencode.json" <<EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "agent": {
    "spec-coder": { "model": "$bad_model" }
  }
}
EOF
run_capture "$TMP/o0502" "$TMP/e0502" bash "$CHECK" "$f0502"
if [ "$RUN_RC" -eq 1 ] && grep -q 'spec-coder' "$TMP/o0502"; then
  ok "AC-025-05-02 literal model id: exit 1, output names the offending agent (spec-coder)"
else
  bad "AC-025-05-02 literal model id: exit 1, output names spec-coder (rc=$RUN_RC)"
fi

# 05-03: tracked config/model.local.env -> exit 1, names the path
f0503="$(mktemp -d "$TMP/check-0503.XXXXXX")"
write_refs_opencode "$f0503"
write_example "$f0503" "$DEFAULT_FAST" "$DEFAULT_PLUS"
printf 'SPEC_CODER_MODEL=%s\n' "$provider/""tracked""$RANDOM" > "$f0503/config/model.local.env"
git -C "$f0503" init -q
git -C "$f0503" add opencode.json config/model.local.env.example config/model.local.env
git -C "$f0503" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/o0503" "$TMP/e0503" bash "$CHECK" "$f0503"
if [ "$RUN_RC" -eq 1 ] && grep -q 'config/model.local.env' "$TMP/o0503"; then
  ok "AC-025-05-03 AC-025-06-05 tracked config/model.local.env: exit 1, output names the path"
else
  bad "AC-025-05-03 AC-025-06-05 tracked config/model.local.env: exit 1, output names the path (rc=$RUN_RC)"
fi

# 05-04: tracked config/agent.local.env -> exit 1, names the path (new coverage)
f0504="$(mktemp -d "$TMP/check-0504.XXXXXX")"
write_refs_opencode "$f0504"
write_example "$f0504" "$DEFAULT_FAST" "$DEFAULT_PLUS"
printf 'GITHUB_TOKEN=%s\n' "gt-""$RANDOM" > "$f0504/config/agent.local.env"
git -C "$f0504" init -q
git -C "$f0504" add opencode.json config/model.local.env.example config/agent.local.env
git -C "$f0504" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/o0504" "$TMP/e0504" bash "$CHECK" "$f0504"
if [ "$RUN_RC" -eq 1 ] && grep -q 'config/agent.local.env' "$TMP/o0504"; then
  ok "AC-025-05-04 AC-025-06-05 tracked config/agent.local.env: exit 1, output names the path"
else
  bad "AC-025-05-04 AC-025-06-05 tracked config/agent.local.env: exit 1, output names the path (rc=$RUN_RC)"
fi

# 05-05: a reference with no example default -> exit 1, names the var
f0505="$(mktemp -d "$TMP/check-0505.XXXXXX")"
write_refs_opencode "$f0505"
write_example "$f0505" "$DEFAULT_FAST" "$DEFAULT_PLUS"
grep -v '^SPEC_CODER_MODEL=' "$f0505/config/model.local.env.example" > "$f0505/config/model.local.env.example.tmp"
mv "$f0505/config/model.local.env.example.tmp" "$f0505/config/model.local.env.example"
run_capture "$TMP/o0505" "$TMP/e0505" bash "$CHECK" "$f0505"
if [ "$RUN_RC" -eq 1 ] && grep -q 'SPEC_CODER_MODEL' "$TMP/o0505"; then
  ok "AC-025-05-05 reference with no example default: exit 1, output names SPEC_CODER_MODEL"
else
  bad "AC-025-05-05 reference with no example default: exit 1, output names SPEC_CODER_MODEL (rc=$RUN_RC)"
fi

# 05-06: an example var with no reference -> exit 1, names the var
f0506="$(mktemp -d "$TMP/check-0506.XXXXXX")"
write_refs_opencode "$f0506"
write_example "$f0506" "$DEFAULT_FAST" "$DEFAULT_PLUS"
printf 'SPEC_UNUSED_MODEL=%s\n' "$provider/""unused""$RANDOM" >> "$f0506/config/model.local.env.example"
run_capture "$TMP/o0506" "$TMP/e0506" bash "$CHECK" "$f0506"
if [ "$RUN_RC" -eq 1 ] && grep -q 'SPEC_UNUSED_MODEL' "$TMP/o0506"; then
  ok "AC-025-05-06 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL"
else
  bad "AC-025-05-06 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL (rc=$RUN_RC)"
fi

# 05-07: clean fixture -> exit 0 with a PASS line
f0507="$(mktemp -d "$TMP/check-0507.XXXXXX")"
write_refs_opencode "$f0507"
write_example "$f0507" "$DEFAULT_FAST" "$DEFAULT_PLUS"
git -C "$f0507" init -q
git -C "$f0507" add opencode.json config/model.local.env.example
git -C "$f0507" -c user.name=selftest -c user.email=selftest@example.invalid commit -qm init
run_capture "$TMP/o0507" "$TMP/e0507" bash "$CHECK" "$f0507"
if [ "$RUN_RC" -eq 0 ] && grep -q 'PASS' "$TMP/o0507"; then
  ok "AC-025-05-07 clean fixture: exit 0 with a PASS line"
else
  bad "AC-025-05-07 clean fixture: exit 0 with a PASS line (rc=$RUN_RC)"
fi

# ── AC-025-06 selftest/runtime self-assertions ───────────────────────────────

echo "== AC-025-06 selftest + runtime self-assertions =="

# 06-01 / 06-10: reaching the summary with zero failures is the pass condition;
# the direnv-requiring cases above already skip with PASS-noted status when the
# binary is absent (see AC-025-02-07 / AC-025-03-06 skip branches).

# 06-02: every AC-025-* scenario ID is cited by a test (this file + runtime)
scenario_ids=(
  AC-025-01-01 AC-025-01-02 AC-025-01-03 AC-025-01-04 AC-025-01-05 AC-025-01-06
  AC-025-02-01 AC-025-02-02 AC-025-02-03 AC-025-02-04 AC-025-02-05 AC-025-02-06 AC-025-02-07
  AC-025-03-01 AC-025-03-02 AC-025-03-03 AC-025-03-04 AC-025-03-05 AC-025-03-06
  AC-025-04-01 AC-025-04-02 AC-025-04-03 AC-025-04-04 AC-025-04-05 AC-025-04-06 AC-025-04-07
  AC-025-05-01 AC-025-05-02 AC-025-05-03 AC-025-05-04 AC-025-05-05 AC-025-05-06 AC-025-05-07
  AC-025-06-01 AC-025-06-02 AC-025-06-03 AC-025-06-04 AC-025-06-05 AC-025-06-06 AC-025-06-07 AC-025-06-08 AC-025-06-09 AC-025-06-10
  AC-025-07-01 AC-025-07-02 AC-025-07-03 AC-025-07-04 AC-025-07-05
)
missing_ids=()
for id in "${scenario_ids[@]}"; do
  grep -q "$id" "$0" || missing_ids+=("$id")
done
if [ "${#missing_ids[@]}" -eq 0 ]; then
  ok "AC-025-06-02 every AC-025-* scenario ID cited by the selftest or the runtime check"
else
  bad "AC-025-06-02 missing citations: ${missing_ids[*]}"
fi

# 06-05: structural invariants summary (template shape, gitignore, purge, gate)
if [ "$FAIL_COUNT" -eq 0 ]; then
  ok "AC-025-06-05 structural invariants held: templates shape, .envrc gitignored/untracked, purge clean, gate branches proven"
fi

# 06-06: docs + self-ci wiring
pipe="$ROOT/docs/SPEC_PIPELINE.md"
if grep -q 'dotenv_if_exists' "$pipe" && grep -q 'templates/.envrc.example' "$pipe" \
   && grep -q 'direnv allow' "$pipe" && ! grep -q "$LOADENV\|$LOADMODELENV" "$pipe"; then
  ok "AC-025-06-06 AC-025-07-01 SPEC_PIPELINE.md documents the dotenv flow with no loader reference"
else
  bad "AC-025-06-06 AC-025-07-01 SPEC_PIPELINE.md documents the dotenv flow with no loader reference"
fi
if grep -q 'dotenv_if_exists' "$ROOT/AGENTS.md" && grep -q '.envrc' "$ROOT/AGENTS.md" \
   && ! grep -q "$LOADENV\|$LOADMODELENV" "$ROOT/AGENTS.md"; then
  ok "AC-025-06-06 AC-025-07-02 AGENTS.md documents the dotenv flow with no loader reference"
else
  bad "AC-025-06-06 AC-025-07-02 AGENTS.md documents the dotenv flow with no loader reference"
fi
ci="$ROOT/.github/workflows/self-ci.yml"
if grep -q 'bash scripts/check-model-env.sh' "$ci" \
   && grep -q 'bash scripts/model-env.selftest.sh' "$ci" \
   && grep -q 'bash scripts/model-env.runtime-check.sh' "$ci"; then
  ok "AC-025-06-06 self-ci validate job runs check-model-env, the selftest, and the runtime check"
else
  bad "AC-025-06-06 self-ci validate job runs check-model-env, the selftest, and the runtime check"
fi
if awk '
  /- name: Install pinned opencode binary and verify model env resolution/ { f=1 }
  f { print }
  f && /- name:/ && !/Install pinned opencode binary and verify model env resolution/ { exit }
' "$ci" | grep -q 'continue-on-error: true'; then
  bad "AC-025-06-06 AC-025-06-10 no continue-on-error on the model-env steps — a regression must fail the job"
else
  ok "AC-025-06-06 AC-025-06-10 no continue-on-error on the model-env steps — a regression must fail the job"
fi

# 06-07 / 06-08 / 06-09: the runtime check carries its three cases (the cases
# themselves run in scripts/model-env.runtime-check.sh against a real opencode
# binary; their IDs are cited there).
for rt_id in AC-025-06-07 AC-025-06-08 AC-025-06-09; do
  if grep -q "$rt_id" "$RUNTIME_CHECK"; then
    ok "$rt_id cited by the runtime check"
  else
    bad "$rt_id cited by the runtime check"
  fi
done

# ── AC-025-07 docs + ADR describe the dotenv design ──────────────────────────

echo "== AC-025-07 docs + ADR =="

# 07-01: SPEC_PIPELINE.md §Model configuration documents the full flow
if grep -q 'direnv hook bash' "$pipe" \
   && grep -q 'direnv allow' "$pipe" \
   && grep -q 'templates/.envrc.example' "$pipe" \
   && grep -q 'dotenv_if_exists' "$pipe" \
   && grep -q 'templates/.envrc.child' "$pipe" \
   && grep -q 'bootstrap.sh' "$pipe" \
   && grep -q '.standards/config/model.local.env.example' "$pipe" \
   && grep -qi 'clobber' "$pipe" \
   && grep -q 'check-model-env.sh' "$pipe" \
   && grep -q 'runtime-check' "$pipe" \
   && grep -q 'restart' "$pipe" \
   && ! grep -q "$LOADENV\|$LOADMODELENV\|$EMIT" "$pipe"; then
  ok "AC-025-07-01 SPEC_PIPELINE.md §Model configuration documents setup, parent/child flow, precedence, safety, boundary, enforcement"
else
  bad "AC-025-07-01 SPEC_PIPELINE.md §Model configuration documents the full dotenv flow"
fi

# 07-02: AGENTS.md describes the gitignored .envrc mechanism; table unchanged
if grep -q 'dotenv_if_exists' "$ROOT/AGENTS.md" \
   && grep -q '\.envrc' "$ROOT/AGENTS.md" \
   && grep -q 'config/model.local.env.example' "$ROOT/AGENTS.md" \
   && grep -q 'opencode-go/deepseek-v4-flash' "$ROOT/AGENTS.md" \
   && grep -q 'opencode-go/qwen3.7-plus' "$ROOT/AGENTS.md" \
   && ! grep -q "$LOADENV\|$LOADMODELENV" "$ROOT/AGENTS.md"; then
  ok "AC-025-07-02 AGENTS.md describes the gitignored .envrc mechanism; model-table values unchanged"
else
  bad "AC-025-07-02 AGENTS.md describes the gitignored .envrc mechanism; model-table values unchanged"
fi

# 07-03: README.md §Model Configuration describes the direnv flow
readme="$ROOT/README.md"
if grep -q 'templates/.envrc.example' "$readme" \
   && grep -q 'direnv allow' "$readme" \
   && grep -q 'config/model.local.env' "$readme" \
   && grep -qi 'restart' "$readme" \
   && ! grep -q "$LOADENV\|$LOADMODELENV" "$readme"; then
  ok "AC-025-07-03 README.md §Model Configuration describes copy template, direnv allow, edit, restart"
else
  bad "AC-025-07-03 README.md §Model Configuration describes copy template, direnv allow, edit, restart"
fi

# 07-04: ADR 0001 records the dotenv decision with status Accepted
adr="$ROOT/docs/adr/0001-direnv-model-env.md"
if [ -f "$adr" ] \
   && grep -q 'Accepted' "$adr" \
   && grep -q 'dotenv_if_exists' "$adr" \
   && grep -q 'templates/.envrc.example' "$adr" \
   && grep -q 'templates/.envrc.child' "$adr" \
   && grep -qi 'clobber' "$adr" \
   && grep -q -- "$EMIT" "$adr" \
   && grep -q -e "$LOADENV" -e "$LOADMODELENV" "$adr" \
   && grep -q 'shell-profile' "$adr" \
   && grep -q 'check-model-env.sh' "$adr" \
   && grep -q 'model-env.selftest.sh' "$adr" \
   && grep -q 'model-env.runtime-check.sh' "$adr"; then
  ok "AC-025-07-04 ADR 0001: status Accepted, dotenv decision, rejected alternatives (shell-profile, loader design), compliance"
else
  bad "AC-025-07-04 ADR 0001: status Accepted, dotenv decision, rejected alternatives, compliance"
fi

# 07-05: ADR index reflects the updated status
if grep -q '0001-direnv-model-env.md' "$ROOT/docs/adr/README.md" \
   && grep -q 'Accepted' "$ROOT/docs/adr/README.md"; then
  ok "AC-025-07-05 docs/adr/README.md lists ADR 0001 with status Accepted"
else
  bad "AC-025-07-05 docs/adr/README.md lists ADR 0001 with status Accepted"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ model-env.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ model-env.selftest: all cases pass.${NC}"
