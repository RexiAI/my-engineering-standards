#!/bin/bash
# model-env.runtime-check.sh — Prove real opencode resolution of
# {env:SPEC_*_MODEL} references end-to-end, using a pinned opencode binary
# against a scratch project outside the repo checkout. This is what makes
# AC-003/AC-004 CI-verified instead of dev-only.
#
# Scenario traceability:
#   AC-020-01-02  local env value overrides the committed default, no commit
#   AC-020-01-03  no local env file still resolves to the committed defaults
#   AC-020-06-04  real opencode resolution in three cases
#
# Three cases, each in a subshell with all 8 SPEC_*_MODEL vars unset first so
# the result is independent of the invoking environment:
#   1. loader sourced, no local file          → every agent's resolved model
#      equals the fixture example default (none null/empty)
#   2. loader sourced, local file overriding one var and a pre-set env var
#      overriding another                     → overrides win, rest at defaults
#   3. loader NOT sourced                     → every agent's model resolves to
#      null/empty — proves the loader is what carries the defaults
#
# Self-trip constraint: every fixture model id is constructed at runtime
# (string concatenation) — no inline literal model-id values in fixtures.
#
# Usage:
#   scripts/model-env.runtime-check.sh [OPENCODE_BIN]
# OPENCODE_BIN defaults to "opencode" on PATH. Pass the pinned binary, e.g.
#   bash scripts/model-env.runtime-check.sh /tmp/opencode
#
# Exit codes:
#   0 — all three cases behave as expected
#   1 — a case failed (binary missing, wrong resolution, ...)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOADER="$ROOT/scripts/load-model-env.sh"
BIN="${1:-opencode}"

# Shared roster (MODEL_ENV_VARS, MODEL_ENV_AGENTS, MODEL_ENV_PLUS_AGENTS).
# shellcheck disable=SC1091
source "$ROOT/scripts/model-env.vars.sh"

PASS_COUNT=0
FAIL_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

# Runtime-built fixture model ids (no inline literal model-id values).
provider="opencode-""go"
FAST="$provider/""fast""$RANDOM""$RANDOM"
PLUS="$provider/""plus""$RANDOM""$RANDOM"

# resolved_model PROJ AGENT — prints the resolved "provider/model" string, or
# nothing when the model key is absent (env var unset ⇒ resolves to empty).
resolved_model() {
  local proj="$1" agent="$2"
  ( cd "$proj" && "$BIN" debug agent "$agent" --pure 2>/dev/null \
    | sed -n '/"model"/,/}/p' \
    | awk -F'"' '/"providerID"/{p=$4} /"modelID"/{m=$4} END{if (p!="" && m!="") print p"/"m}' )
}

# expected_for AGENT — the fixture's committed default for that agent: the
# shared "plus"-tier agents, everything else the "fast" tier.
expected_for() {
  local agent="$1" a
  for a in "${MODEL_ENV_PLUS_AGENTS[@]}"; do
    if [ "$agent" = "$a" ]; then
      echo "$PLUS"
      return
    fi
  done
  echo "$FAST"
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"
mkdir -p "$PROJ/config"
cat > "$PROJ/opencode.json" <<'EOF'
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
{
  printf 'SPEC_SPECIFIER_MODEL=%s\n' "$FAST"
  printf 'SPEC_UX_MODEL=%s\n' "$FAST"
  printf 'SPEC_VERIFIER_MODEL=%s\n' "$PLUS"
  printf 'SPEC_MUTATION_RUNNER_MODEL=%s\n' "$PLUS"
  printf 'SPEC_PR_OPENER_MODEL=%s\n' "$PLUS"
  printf 'SPEC_CODER_MODEL=%s\n' "$FAST"
  printf 'SPEC_REFACTORER_MODEL=%s\n' "$FAST"
  printf 'SPEC_PIPELINE_MODEL=%s\n' "$FAST"
} > "$PROJ/config/model.local.env.example"

echo "pinned opencode binary: $BIN"
if "$BIN" --version >/dev/null 2>&1; then
  ok "AC-020-06-04 opencode binary runs (--version)"
else
  bad "AC-020-06-04 opencode binary runs (--version) — is '$BIN' the pinned v1.18.18 binary?"
  echo ""
  echo "runtime-check: $PASS_COUNT passed, $FAIL_COUNT failed"
  exit 1
fi

# ── Case 1: loader sourced, no local file → example defaults (AC-020-06-04,
#    AC-020-01-03) ────────────────────────────────────────────────────────────
case1_ok=1
(
  for v in "${MODEL_ENV_VARS[@]}"; do unset "$v"; done
  # shellcheck disable=SC1090
  source "$LOADER" "$PROJ"
  for agent in "${MODEL_ENV_AGENTS[@]}"; do
    got="$(resolved_model "$PROJ" "$agent")"
    want="$(expected_for "$agent")"
    if [ "$got" != "$want" ]; then
      echo "  case1: $agent resolved '$got', expected '$want'"
      exit 1
    fi
  done
) && case1_ok=0
if [ "$case1_ok" -eq 0 ]; then
  ok "AC-020-06-04 case 1: loader sourced, no local file — all 8 agents resolve to the fixture example defaults"
else
  bad "AC-020-06-04 case 1: loader sourced, no local file — all 8 agents resolve to the fixture example defaults"
fi

# ── Case 2: local file overrides one var, pre-set env var overrides another
#    (AC-020-06-04, AC-020-01-02) ────────────────────────────────────────────
OVERRIDE_LOCAL="$provider/""local-override""$RANDOM"
OVERRIDE_ENV="$provider/""env-override""$RANDOM"
printf 'SPEC_SPECIFIER_MODEL=%s\n' "$OVERRIDE_LOCAL" > "$PROJ/config/model.local.env"
case2_ok=1
(
  for v in "${MODEL_ENV_VARS[@]}"; do unset "$v"; done
  export SPEC_UX_MODEL="$OVERRIDE_ENV"
  # shellcheck disable=SC1090
  source "$LOADER" "$PROJ"
  for agent in "${MODEL_ENV_AGENTS[@]}"; do
    got="$(resolved_model "$PROJ" "$agent")"
    case "$agent" in
      spec-specifier) want="$OVERRIDE_LOCAL" ;;
      spec-ux) want="$OVERRIDE_ENV" ;;
      *) want="$(expected_for "$agent")" ;;
    esac
    if [ "$got" != "$want" ]; then
      echo "  case2: $agent resolved '$got', expected '$want'"
      exit 1
    fi
  done
) && case2_ok=0
if [ "$case2_ok" -eq 0 ]; then
  ok "AC-020-06-04 case 2: local-file override and pre-set env override win, remaining agents stay at defaults"
else
  bad "AC-020-06-04 case 2: local-file override and pre-set env override win, remaining agents stay at defaults"
fi
rm -f "$PROJ/config/model.local.env"

# ── Case 3: loader NOT sourced → model resolves empty (AC-020-06-04) ────────
case3_ok=1
(
  for v in "${MODEL_ENV_VARS[@]}"; do unset "$v"; done
  for agent in "${MODEL_ENV_AGENTS[@]}"; do
    got="$(resolved_model "$PROJ" "$agent")"
    if [ -n "$got" ]; then
      echo "  case3: $agent resolved '$got', expected empty"
      exit 1
    fi
  done
) && case3_ok=0
if [ "$case3_ok" -eq 0 ]; then
  ok "AC-020-06-04 case 3: loader not sourced — every agent resolves to null/empty, proving the loader carries the defaults"
else
  bad "AC-020-06-04 case 3: loader not sourced — every agent resolves to null/empty, proving the loader carries the defaults"
fi

echo ""
echo "runtime-check: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ model-env.runtime-check: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ model-env.runtime-check: all cases pass.${NC}"
