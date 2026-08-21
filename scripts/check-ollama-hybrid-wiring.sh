#!/bin/bash
# check-ollama-hybrid-wiring.sh — Gate: config/model.local.env wires every stage
# to the model the Task 3 e2e decision assigned it. (spec 001-ollama-context,
# Task 4)
#
# Checks (per 20-acceptance/AC-004-hybrid-fallback.md):
#   1. The Task 3 decision file and config/model.local.env both exist and are
#      readable — else exit 2 (AC-004-07).
#   2. Every one of the eight spec agents appears in exactly one of
#      LOCAL_STAGES / CLOUD_FALLBACK_STAGES (AC-004-03).
#   3. For every agent in LOCAL_STAGES: SPEC_<STAGE>_MODEL=ollama/qwen3.8:27b
#      (AC-004-01).
#   4. For every agent in CLOUD_FALLBACK_STAGES:
#      SPEC_<STAGE>_MODEL=opencode-go/deepseek-v4-flash (AC-004-02).
#   5. Exactly the eight SPEC_*_MODEL vars are set, one per agent, each value
#      either the local or the cloud model (AC-004-03).
#   On any mismatch the script names the stage (AC-004-06).
#
# Usage:
#   scripts/check-ollama-hybrid-wiring.sh [DECISION] [CONFIG]
#   defaults:
#     DECISION = specs/001-ollama-context/e2e-decision.txt
#     CONFIG   = config/model.local.env
#
# Exit codes:
#   0 — every stage's value matches the decision mapping
#   1 — at least one stage value disagrees (stage named)
#   2 — decision file or config missing/unreadable, or a stage not assigned
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/check-common.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/model-env.vars.sh"

ROOT="$(dirname "$SCRIPT_DIR")"
DECISION="${1:-$ROOT/specs/001-ollama-context/e2e-decision.txt}"
CONFIG="${2:-$ROOT/config/model.local.env}"
LOCAL_MODEL="ollama/qwen3.8:27b"
CLOUD_MODEL="opencode-go/deepseek-v4-flash"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# ── Preflight (AC-004-07): decision file + config present and readable ───────
if [ ! -r "$DECISION" ]; then
  echo "ERROR: Task 3 decision file '$DECISION' is missing or unreadable (AC-004-07)" >&2
  exit 2
fi
if [ ! -r "$CONFIG" ]; then
  echo "ERROR: config '$CONFIG' is missing or unreadable (AC-004-07)" >&2
  exit 2
fi

# ── Parse the decision line ──────────────────────────────────────────────────
LOCAL_STAGES="$(grep '^LOCAL_STAGES=' "$DECISION" | head -1 | sed 's/^LOCAL_STAGES=//')"
CLOUD_STAGES="$(grep '^CLOUD_FALLBACK_STAGES=' "$DECISION" | head -1 | sed 's/^CLOUD_FALLBACK_STAGES=//')"
if [ -z "$LOCAL_STAGES" ] && [ -z "$CLOUD_STAGES" ]; then
  echo "ERROR: decision file '$DECISION' carries no LOCAL_STAGES/CLOUD_FALLBACK_STAGES line (AC-004-03)" >&2
  exit 2
fi

# ── AC-004-03: every agent in exactly one list ───────────────────────────────
for agent in "${MODEL_ENV_AGENTS[@]}"; do
  in_local=$(printf '%s\n' $LOCAL_STAGES | grep -qx "$agent" && echo 1 || echo 0)
  in_cloud=$(printf '%s\n' $CLOUD_STAGES | grep -qx "$agent" && echo 1 || echo 0)
  if [ "$in_local" = "1" ] && [ "$in_cloud" = "1" ]; then
    fail "stage $agent appears in BOTH LOCAL_STAGES and CLOUD_FALLBACK_STAGES (AC-004-03)"
  fi
  if [ "$in_local" = "0" ] && [ "$in_cloud" = "0" ]; then
    fail "stage $agent appears in NEITHER list (AC-004-03)"
  fi
done
# No non-roster agent may appear in the lists.
for a in $LOCAL_STAGES $CLOUD_STAGES; do
  [ -n "$a" ] || continue
  if [ -z "$(model_env_var_for_agent "$a")" ]; then
    fail "decision lists unknown agent '$a' (not one of the 8 spec agents, AC-004-03)"
  fi
done

# ── Per-agent value check (AC-004-01/02/03/06) ───────────────────────────────
config_get() { # config_get <var> — the value of VAR in the env file, "" if absent
  grep -E "^[[:space:]]*$1=" "$CONFIG" | tail -1 | sed -E 's/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=[[:space:]]*//' || true
}

# expected_model <agent> — returns the expected model for a stage based on the
# LOCAL/CLOUD decision lists, or "" if the agent is not in either list.
expected_model() {
  local agent="$1"
  if printf '%s\n' $LOCAL_STAGES | grep -qx "$agent"; then
    printf '%s' "$LOCAL_MODEL"
  elif printf '%s\n' $CLOUD_STAGES | grep -qx "$agent"; then
    printf '%s' "$CLOUD_MODEL"
  fi
}

for agent in "${MODEL_ENV_AGENTS[@]}"; do
  var="$(model_env_var_for_agent "$agent")"
  value="$(config_get "$var")"
  if [ -z "$value" ]; then
    fail "stage $agent: $var is not set in config (AC-004-03)"
    continue
  fi
  expected="$(expected_model "$agent")"
  if [ -n "$expected" ] && [ "$value" != "$expected" ]; then
    fail "stage $agent: $var=$value, expected $expected (AC-004-06)"
  fi
done

# ── AC-004-03: exactly the eight SPEC_*_MODEL vars set ───────────────────────
set_vars="$(grep -E '^[[:space:]]*SPEC_[A-Z0-9_]+_MODEL=' "$CONFIG" | sed -E 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/' | sort -u)"
expected_vars="$(printf '%s\n' "${MODEL_ENV_AGENTS[@]}" | while IFS= read -r a; do model_env_var_for_agent "$a"; done | sort -u)"
if [ "$set_vars" != "$expected_vars" ]; then
  fail "config must set exactly the 8 SPEC_*_MODEL vars (got: $(printf '%s ' $set_vars)) (AC-004-03)"
fi

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ check-ollama-hybrid-wiring: $VIOLATIONS violation(s).${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-ollama-hybrid-wiring: every stage resolves to its decision-assigned model.${NC}"
exit 0
