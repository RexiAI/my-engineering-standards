#!/bin/bash
# check-model-env.sh — Gate: no literal model id in opencode.json, the real env
# files are never tracked, and the committed dotenv-defaults example is wired.
#
# Checks:
#   1. Every agent.*.model value in opencode.json is exactly an
#      {env:SPEC_*_MODEL} reference with the mapped var name; any literal model
#      id (e.g. opencode-go/deepseek-v4-flash) anywhere in the file fails,
#      naming the offending agent. All 8 spec agents must be present.
#   2. config/model.local.env and config/agent.local.env are not tracked by
#      git (git ls-files) — a forced-added or previously-committed real file
#      fails, naming the path.
#   3. config/model.local.env.example exists and defines exactly the 8
#      SPEC_*_MODEL var names, and the set of vars referenced by opencode.json
#      equals the set defined by the example. A reference with no example
#      default, or an example var with no reference, fails naming the var.
#
# Usage:
#   scripts/check-model-env.sh [PROJECT_ROOT]
# PROJECT_ROOT defaults to the repo root, derived from this script's own
# location (the parent of the scripts/ directory). Works against a scratch
# repo by passing its root (and pointing GIT_DIR/--git-dir at it when the
# scratch repo is not the cwd's repo).
#
# Exit codes:
#   0 — all checks pass (brief PASS line)
#   1 — at least one violation (message names the offending agent/path/var)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# Shared roster: MODEL_ENV_AGENTS, MODEL_ENV_VARS, model_env_var_for_agent().
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model-env.vars.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-$(dirname "$SCRIPT_DIR")}"

OPENCODE_JSON="$ROOT/opencode.json"
EXAMPLE="$ROOT/config/model.local.env.example"

# ── Check 1: opencode.json — env references only, all 8 agents present ───────
if [ ! -f "$OPENCODE_JSON" ]; then
  fail "opencode.json not found at $OPENCODE_JSON"
else
  # Strip $schema lines before the whole-file literal scan so the schema URL's
  # slashes cannot false-positive; then flag any remaining provider/model-style
  # token (X/Y) — a literal model id anywhere in the file is a violation.
  # The pr-review provider block (spec 024) is carved out before the scan: it
  # legitimately carries the OpenCode Zen endpoint URL and the provider-side
  # model name, neither of which is an agent model id. The scan's job is to
  # keep the *agent block* env-reference-only — the pr-review agent's model pin
  # lives in agents/pr-review.md frontmatter (the one deliberate exception,
  # spec 024), not in opencode.json. The provider block is the last top-level
  # key, so deleting from its opening line to EOF is sufficient.
  scan="$(sed -E 's/"[[:space:]]*\$schema[[:space:]]*"[[:space:]]*:[[:space:]]*"[^"]*"[[:space:]]*[,]?//' "$OPENCODE_JSON")"
  scan="$(sed -E '/^[[:space:]]*"provider"[[:space:]]*:/,$d' <<< "$scan")"
  literal_line="$(printf '%s\n' "$scan" | grep -nE '[A-Za-z0-9._-]+/[A-Za-z0-9._-]+' | head -1 || true)"
  if [ -n "$literal_line" ]; then
    fail "literal provider/model id found in opencode.json agent block (line $literal_line) — every agent.*.model must be an {env:SPEC_*_MODEL} reference"
  fi

  # Per-agent exact-match on model values; one agent per line.
  while IFS= read -r line; do
    case "$line" in
      *'"model"'*) ;;
      *) continue ;;
    esac
    agent="$(printf '%s' "$line" | sed -nE 's/^[[:space:]]*"([^"]+)"[[:space:]]*:[[:space:]]*\{.*/\1/p')"
    value="$(printf '%s' "$line" | sed -nE 's/.*"model"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/p')"
    expected="$(model_env_var_for_agent "$agent")"
    if [ -z "$expected" ]; then
      fail "agent $agent in opencode.json is not one of the 8 spec agents"
    elif [ "$value" != "{env:$expected}" ]; then
      fail "agent $agent: model value '$value' is not an {env:$expected} reference"
    fi
  done < "$OPENCODE_JSON"

  # Every expected agent must be present in the file.
  for agent in "${MODEL_ENV_AGENTS[@]}"; do
    if ! grep -qE "^[[:space:]]*\"$agent\"[[:space:]]*:" "$OPENCODE_JSON"; then
      fail "agent $agent missing from opencode.json"
    fi
  done
fi

# ── Check 2: the real env files are never tracked ────────────────────────────
for real_env in config/model.local.env config/agent.local.env; do
  if git -C "$ROOT" ls-files --error-unmatch -- "$real_env" >/dev/null 2>&1; then
    fail "$real_env is tracked by git (git ls-files) — the real env file must never be committed"
  fi
done

# ── Check 3: the committed dotenv-defaults example exists and is wired ───────
if [ ! -f "$EXAMPLE" ]; then
  fail "config/model.local.env.example not found at $EXAMPLE — the .envrc's committed dotenv defaults source is missing"
else
  example_vars="$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$EXAMPLE" | sed -E 's/=.*//' | sort -u)"
  referenced_vars="$(grep -oE '\{env:SPEC_[A-Z0-9_]+_MODEL\}' "$OPENCODE_JSON" | sed -E 's/\{env:([^}]+)\}/\1/' | sort -u)"
  expected_vars="$(printf '%s\n' "${MODEL_ENV_AGENTS[@]}" | while IFS= read -r agent; do model_env_var_for_agent "$agent"; done | sort -u)"

  for var in $referenced_vars; do
    if ! printf '%s\n' "$example_vars" | grep -qx "$var"; then
      fail "SPEC_*_MODEL reference $var has no default in config/model.local.env.example — the dotenv defaults source is not wired for it"
    fi
  done
  for var in $example_vars; do
    if ! printf '%s\n' "$referenced_vars" | grep -qx "$var"; then
      fail "example var $var has no {env:...} reference in opencode.json — wiring mismatch"
    fi
  done
  if [ "$example_vars" != "$expected_vars" ]; then
    fail "config/model.local.env.example must define exactly the 8 SPEC_*_MODEL vars (expected: $(printf '%s ' $expected_vars))"
  fi
fi

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ check-model-env: $VIOLATIONS violation(s).${NC}"
  exit 1
fi
echo -e "${GREEN}PASS${NC} check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired."
