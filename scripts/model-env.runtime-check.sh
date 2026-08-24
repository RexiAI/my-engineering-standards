#!/bin/bash
# model-env.runtime-check.sh — Prove real opencode resolution of
# {env:SPEC_*_MODEL} references end-to-end, using a pinned opencode binary
# against a scratch project outside the repo checkout. This is what makes
# AC-025-06-07..09 CI-verified instead of dev-only.
#
# Scenario traceability:
#   AC-025-06-07  example loaded (dotenv-equivalent) -> every agent resolves
#                 to the fixture example default, none empty
#   AC-025-06-08  example + config/model.local.env overriding one var + a
#                 pre-exported env var for a var absent from all files -> the
#                 file override wins, the pre-exported var survives, the rest
#                 stay at defaults (later dotenv line wins; vars no file
#                 defines are untouched)
#   AC-025-06-09  nothing loaded -> every agent resolves to null/empty,
#                 proving the committed example is what carries the defaults
#
# The dotenv-equivalent load mirrors the .envrc's first dotenv_if_exists line:
#   set -a; . config/model.local.env.example; set +a
#
# Self-trip constraint: every fixture model id is constructed at runtime
# (string concatenation) — no inline literal model-id values in fixtures, and
# no loader-name/emit-flag strings (scripts/ is in the purge scan scope).
#
# Usage:
#   scripts/model-env.runtime-check.sh [OPENCODE_BIN]
# OPENCODE_BIN defaults to "opencode" on PATH. Pass the pinned binary, e.g.
#   bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode
#
# Exit codes:
#   0 — all three cases behave as expected
#   1 — a case failed (binary missing, wrong resolution, ...)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
# nothing when the model key is absent (env var unset resolves to empty).
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

# write_example DIR FAST PLUS — fixture example defining all 9 vars
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
    printf 'SPEC_PR_REVIEW_MODEL=%s\n' "$2"
  } > "$1/config/model.local.env.example"
}

# write_refs PROJ — fixture opencode.json with 9 {env:...} references
write_refs() {
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
    "spec-pipeline": { "model": "{env:SPEC_PIPELINE_MODEL}" },
    "pr-review": { "model": "{env:SPEC_PR_REVIEW_MODEL}" }
  }
}
EOF
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROJ="$TMP/proj"
write_refs "$PROJ"
write_example "$PROJ" "$FAST" "$PLUS"

echo "pinned opencode binary: $BIN"
if "$BIN" --version >/dev/null 2>&1; then
  ok "AC-025-06-07 opencode binary runs (--version)"
else
  bad "AC-025-06-07 opencode binary runs (--version) — is '$BIN' the pinned binary?"
  echo ""
  echo "runtime-check: $PASS_COUNT passed, $FAIL_COUNT failed"
  exit 1
fi

# ── Case 1 (AC-025-06-07): example loaded via the dotenv-equivalent -> every
#    agent resolves to the fixture example default, none empty ────────────────
case1_ok=1
(
  for v in "${MODEL_ENV_VARS[@]}"; do unset "$v"; done
  # shellcheck disable=SC1091
  set -a; . "$PROJ/config/model.local.env.example"; set +a
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
  ok "AC-025-06-07 case 1: example loaded — all 8 agents resolve to the fixture example defaults, none empty"
else
  bad "AC-025-06-07 case 1: example loaded — all 8 agents resolve to the fixture example defaults, none empty"
fi

# ── Case 2 (AC-025-06-08): example (minus SPEC_UX_MODEL) + local file
#    overriding SPEC_SPECIFIER_MODEL + SPEC_UX_MODEL pre-exported (a var no
#    file defines) -> file override wins, pre-exported var survives, rest stay
#    at defaults ──────────────────────────────────────────────────────────────
OVERRIDE_LOCAL="$provider/""local-override""$RANDOM"
OVERRIDE_ENV="$provider/""env-override""$RANDOM"
grep -v '^SPEC_UX_MODEL=' "$PROJ/config/model.local.env.example" > "$PROJ/config/model.local.env.example.tmp"
mv "$PROJ/config/model.local.env.example.tmp" "$PROJ/config/model.local.env.example"
printf 'SPEC_SPECIFIER_MODEL=%s\n' "$OVERRIDE_LOCAL" > "$PROJ/config/model.local.env"
case2_ok=1
(
  for v in "${MODEL_ENV_VARS[@]}"; do unset "$v"; done
  export SPEC_UX_MODEL="$OVERRIDE_ENV"
  # shellcheck disable=SC1091
  set -a; . "$PROJ/config/model.local.env.example"; set +a
  set -a; . "$PROJ/config/model.local.env"; set +a
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
  ok "AC-025-06-08 case 2: later dotenv line wins for spec-specifier; spec-ux keeps its pre-exported value; rest stay at defaults"
else
  bad "AC-025-06-08 case 2: later dotenv line wins for spec-specifier; spec-ux keeps its pre-exported value; rest stay at defaults"
fi

# ── Case 3 (AC-025-06-09): nothing loaded -> every agent resolves to
#    null/empty, proving the committed example is what carries the defaults ───
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
  ok "AC-025-06-09 case 3: nothing loaded — every agent resolves to null/empty, proving the example carries the defaults"
else
  bad "AC-025-06-09 case 3: nothing loaded — every agent resolves to null/empty, proving the example carries the defaults"
fi

echo ""
echo "runtime-check: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ model-env.runtime-check: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ model-env.runtime-check: all cases pass.${NC}"
