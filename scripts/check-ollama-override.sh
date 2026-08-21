#!/bin/bash
# check-ollama-override.sh — Gate: the live systemd ollama override matches the
# shipped template, the service env carries the three OLLAMA_ variables, and the
# running model reports the selected context. (spec 001-ollama-context, Task 2)
#
# Checks (per 20-acceptance/AC-002-systemd-override.md):
#   1. Required tools (cmp, systemctl, ollama) present — else exit 2 (AC-002-05).
#   2. Task 1 summary `selected` read from the benchmark report.
#      - selected=NONE -> SKIP report, exit 0; the live override must still
#        retain OLLAMA_CONTEXT_LENGTH=16384 (AC-002-07).
#      - otherwise:
#        a. Applied file is byte-identical to the template (cmp) (AC-002-02/03);
#           on divergence, name the differing OLLAMA_ variable (AC-002-03).
#        b. `systemctl show ollama.service -p Environment` carries all three
#           OLLAMA_ variables with the template values (AC-002-02/04).
#        c. `ollama ps` reports the model with CONTEXT equal to the selected
#           value (AC-002-02).
#   3. keepalive.conf still carries OLLAMA_KEEP_ALIVE=24h and nothing else
#      (AC-002-08).
#
# Usage:
#   scripts/check-ollama-override.sh [REPORT] [TEMPLATE] [APPLIED] [KEEPALIVE]
#   defaults:
#     REPORT   = specs/001-ollama-context/benchmark-report.csv
#     TEMPLATE = templates/ollama.service.d/context.conf
#     APPLIED  = /etc/systemd/system/ollama.service.d/context.conf
#     KEEPALIVE= /etc/systemd/system/ollama.service.d/keepalive.conf
#
# Exit codes:
#   0 — all checks pass (or selected=NONE SKIP verified)
#   1 — a divergence / missing var / wrong context / keepalive touched
#   2 — missing required tool, or the report/template/applied file unreadable
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/check-common.sh"

ROOT="$(dirname "$SCRIPT_DIR")"
REPORT="${1:-$ROOT/specs/001-ollama-context/benchmark-report.csv}"
TEMPLATE="${2:-$ROOT/templates/ollama.service.d/context.conf}"
APPLIED="${3:-/etc/systemd/system/ollama.service.d/context.conf}"
KEEPALIVE="${4:-/etc/systemd/system/ollama.service.d/keepalive.conf}"
MODEL="qwen3.8:27b"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

VIOLATIONS=0
fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# ── Tooling preflight (AC-002-05): missing tool = exit 2, never a clean run ──
require_tools check-ollama-override cmp systemctl ollama grep awk sed

# ── Read the Task 1 summary `selected` value (never invented) ────────────────
if [ ! -r "$REPORT" ]; then
  echo "ERROR: Task 1 benchmark report '$REPORT' is missing or unreadable (AC-002-02 requires the selected value)" >&2
  exit 2
fi
SELECTED="$(grep '^summary,' "$REPORT" | sed -E 's/.*selected=([^,]+).*/\1/' | head -1)"
if [ -z "$SELECTED" ]; then
  echo "ERROR: no summary `selected=` line found in '$REPORT'" >&2
  exit 2
fi

echo "Task 1 selected: $SELECTED"

# ── selected=NONE -> SKIP (AC-002-07) ────────────────────────────────────────
if [ "$SELECTED" = "NONE" ]; then
  # Live override must still retain OLLAMA_CONTEXT_LENGTH=16384.
  if [ ! -r "$APPLIED" ]; then
    fail "selected=NONE but applied override '$APPLIED' missing"
  elif grep -q 'OLLAMA_CONTEXT_LENGTH=16384' "$APPLIED"; then
    echo -e "${YELLOW}SKIP${NC} selected=NONE — apply skipped; live override retains OLLAMA_CONTEXT_LENGTH=16384"
  else
    fail "selected=NONE but applied override does not retain OLLAMA_CONTEXT_LENGTH=16384"
  fi
  echo ""
  if [ "$VIOLATIONS" -gt 0 ]; then
    echo -e "${RED}✘ check-ollama-override: $VIOLATIONS violation(s).${NC}"
    exit 1
  fi
  echo -e "${GREEN}✔ check-ollama-override: SKIP (selected=NONE) — exit 0.${NC}"
  exit 0
fi

# ── selected != NONE: template must exist and carry the value (AC-002-01) ────
if [ ! -r "$TEMPLATE" ]; then
  echo "ERROR: template '$TEMPLATE' is missing or unreadable (selected=$SELECTED)" >&2
  exit 2
fi
if ! grep -q "OLLAMA_CONTEXT_LENGTH=$SELECTED" "$TEMPLATE"; then
  fail "template does not carry OLLAMA_CONTEXT_LENGTH=$SELECTED (AC-002-01 — the value must equal the report's selected)"
fi

# ── a. Applied file byte-identical to template (AC-002-02/03) ────────────────
if [ ! -r "$APPLIED" ]; then
  echo "ERROR: applied override '$APPLIED' is missing or unreadable" >&2
  exit 2
fi
if cmp -s "$TEMPLATE" "$APPLIED"; then
  pass "applied override is byte-identical to the template"
else
  # Name the differing OLLAMA_ variable (AC-002-03).
  t_vars="$(grep -oE 'OLLAMA_[A-Z_]+=[^" ]+' "$TEMPLATE" | sort)"
  a_vars="$(grep -oE 'OLLAMA_[A-Z_]+=[^" ]+' "$APPLIED" | sort)"
  diffed="$(diff <(printf '%s\n' "$t_vars") <(printf '%s\n' "$a_vars") || true)"
  if [ -n "$diffed" ]; then
    fail "applied override differs from template (AC-002-03); differing OLLAMA_ vars:"; echo "$diffed" | sed 's/^/    /'
  else
    fail "applied override differs from template (AC-002-03), but OLLAMA_ vars match — a header/whitespace divergence"
  fi
fi

# ── b. systemctl show carries the three vars (AC-002-02/04) ──────────────────
SVC_ENV="$(systemctl show ollama.service -p Environment 2>/dev/null || true)"
env_val() { # env_val <name> — value of an OLLAMA_ var in the service env, "" if absent
  printf '%s\n' "$SVC_ENV" | grep -oE "$1=[^ \"']+" | head -1 | cut -d= -f2- || true
}
EXPECTED="OLLAMA_CONTEXT_LENGTH=$SELECTED
OLLAMA_FLASH_ATTENTION=1
OLLAMA_KV_CACHE_TYPE=q8_0"
while IFS= read -r pair; do
  [ -n "$pair" ] || continue
  name="${pair%%=*}"
  want="${pair#*=}"
  have="$(env_val "$name")"
  if [ "$have" != "$want" ]; then
    fail "service env $name=$have, expected $name=$want (AC-002-02/04)"
  fi
done <<< "$EXPECTED"

# ── c. ollama ps shows the model with CONTEXT = selected (AC-002-02) ─────────
PS_CTX="$(ollama ps 2>/dev/null | awk -v m="$MODEL" '
  /^NAME/ { ctx = index($0, "CONTEXT"); next }
  $1 == m {
    s = substr($0, ctx); gsub(/^[ \t]+|[ \t]+$/, "", s);
    split(s, a, /[ \t]+/); print a[1]; exit
  }' || true)"
if [ -z "$PS_CTX" ]; then
  fail "ollama ps shows no row for $MODEL (model not loaded — AC-002-02)"
elif [ "$PS_CTX" = "$SELECTED" ]; then
  pass "ollama ps: $MODEL CONTEXT=$PS_CTX (equals selected=$SELECTED)"
else
  fail "ollama ps: $MODEL CONTEXT=$PS_CTX, expected $SELECTED (AC-002-02)"
fi

# ── keepalive untouched (AC-002-08) ─────────────────────────────────────────
if [ -r "$KEEPALIVE" ]; then
  kvars="$(grep -oE 'OLLAMA_[A-Z_]+=[^" ]+' "$KEEPALIVE" || true)"
  if [ "$kvars" = "OLLAMA_KEEP_ALIVE=24h" ]; then
    pass "keepalive.conf carries OLLAMA_KEEP_ALIVE=24h and nothing else (untouched)"
  else
    fail "keepalive.conf was touched: found '$kvars' (AC-002-08 — must be exactly OLLAMA_KEEP_ALIVE=24h)"
  fi
else
  echo -e "${YELLOW}WARN${NC} keepalive.conf '$KEEPALIVE' not readable — skipping keepalive check"
fi

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ check-ollama-override: $VIOLATIONS violation(s).${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-ollama-override: override applied and verified.${NC}"
exit 0
