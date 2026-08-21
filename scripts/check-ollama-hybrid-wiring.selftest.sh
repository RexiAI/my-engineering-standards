#!/bin/bash
# check-ollama-hybrid-wiring.selftest.sh — Hermetic regression net for
# scripts/check-ollama-hybrid-wiring.sh. No live direnv/opencode: the decision
# file and config/model.local.env are real temp fixtures the script parses.
#
# Scenario traceability: every AC-004-xx ID below is the test for the matching
# 20-acceptance scenario in specs/001-ollama-context/20-acceptance/AC-004-hybrid-fallback.md:
#   AC-004-01  LOCAL stages resolve to ollama/qwen3.8:27b
#   AC-004-02  CLOUD stages resolve to opencode-go/deepseek-v4-flash
#   AC-004-03  exactly 8 SPEC_*_MODEL vars, one per agent, each value local or cloud
#   AC-004-04  header documents mechanism, restart, spend-limit caveat
#   AC-004-05  check exits 0 when values match the decision
#   AC-004-06  mismatch -> exit 1, names the stage
#   AC-004-07  missing decision file or config -> exit 2
#
# Usage:
#   bash scripts/check-ollama-hybrid-wiring.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-ollama-hybrid-wiring.sh"

PASS_COUNT=0
FAIL_COUNT=0
ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── Fixtures ─────────────────────────────────────────────────────────────────
# Decision: spec-specifier -> CLOUD, the other 7 -> LOCAL.
DEC="$TMP/decision.txt"
cat > "$DEC" <<'DEC'
LOCAL_STAGES=spec-ux spec-verifier spec-mutation-runner spec-pr-opener spec-coder spec-refactorer spec-pipeline
CLOUD_FALLBACK_STAGES=spec-specifier
DEC

# Config matching the decision (AC-004-01/02/03/05).
CFG_OK="$TMP/model.local.env"
cat > "$CFG_OK" <<'CFG'
# (a) mechanism unchanged: opencode.json resolves agent.*.model from {env:SPEC_*_MODEL}
# (b) restart required: opencode reads config once at startup
# (c) opencode-go fallback may be unavailable until the monthly $25 spend limit resets
SPEC_UX_MODEL=ollama/qwen3.8:27b
SPEC_VERIFIER_MODEL=ollama/qwen3.8:27b
SPEC_MUTATION_RUNNER_MODEL=ollama/qwen3.8:27b
SPEC_PR_OPENER_MODEL=ollama/qwen3.8:27b
SPEC_CODER_MODEL=ollama/qwen3.8:27b
SPEC_REFACTORER_MODEL=ollama/qwen3.8:27b
SPEC_PIPELINE_MODEL=ollama/qwen3.8:27b
SPEC_SPECIFIER_MODEL=opencode-go/deepseek-v4-flash
CFG

# Config with a mismatching stage (AC-004-06): spec-verifier wrongly local... it IS
# local; instead point spec-coder (LOCAL) at the cloud model.
CFG_BAD="$TMP/model.bad.env"
sed 's/^SPEC_CODER_MODEL=ollama\/qwen3.8:27b/SPEC_CODER_MODEL=opencode-go\/deepseek-v4-flash/' "$CFG_OK" > "$CFG_BAD"

run_check() { # run_check <decision> <config>
  set +e
  bash "$CHECK" "$1" "$2" > "$TMP/out" 2> "$TMP/err"
  RUN_RC=$?
  set -e
}

echo "== AC-004-01 LOCAL stages resolve to the local model =="
if grep -q '^SPEC_UX_MODEL=ollama/qwen3.8:27b$' "$CFG_OK" \
   && grep -q '^SPEC_PIPELINE_MODEL=ollama/qwen3.8:27b$' "$CFG_OK" \
   && grep -q '^SPEC_CODER_MODEL=ollama/qwen3.8:27b$' "$CFG_OK"; then
  ok "AC-004-01 LOCAL stages (spec-ux, spec-coder, spec-pipeline, ...) -> ollama/qwen3.8:27b"
else
  bad "AC-004-01 LOCAL stages -> ollama/qwen3.8:27b (missing a LOCAL var in $CFG_OK)"
fi

echo "== AC-004-02 CLOUD stages resolve to the cloud model =="
if grep -q '^SPEC_SPECIFIER_MODEL=opencode-go/deepseek-v4-flash$' "$CFG_OK"; then
  ok "AC-004-02 CLOUD stage spec-specifier -> opencode-go/deepseek-v4-flash"
else
  bad "AC-004-02 CLOUD stage spec-specifier -> opencode-go/deepseek-v4-flash (missing in $CFG_OK)"
fi

echo "== AC-004-03 exactly eight SPEC_*_MODEL vars, one per agent, each local or cloud =="
set_vars="$(grep -E '^SPEC_[A-Z0-9_]+_MODEL=' "$CFG_OK" | sed -E 's/=.*//' | sort -u)"
count="$(printf '%s\n' "$set_vars" | grep -c 'SPEC_' || true)"
badval=0
for v in $set_vars; do
  val="$(grep "^$v=" "$CFG_OK" | sed 's/^[^=]*=//' || true)"
  case "$val" in
    ollama/qwen3.8:27b|opencode-go/deepseek-v4-flash) ;;
    *) badval=1 ;;
  esac
done
if [ "$count" -eq 8 ] && [ "$badval" -eq 0 ]; then
  ok "AC-004-03 exactly 8 SPEC_*_MODEL vars, each value local or cloud"
else
  bad "AC-004-03 exactly 8 vars, each local or cloud (count=$count, badval=$badval)"
fi

echo "== AC-004-04 header documents mechanism, restart, spend-limit =="
if grep -qi 'agent.*\.model.*{env:SPEC_' "$CFG_OK" \
   && grep -qi 'restart' "$CFG_OK" \
   && grep -qi '\$25 spend limit' "$CFG_OK"; then
  ok "AC-004-04 header documents mechanism, restart, and spend-limit caveat"
else
  bad "AC-004-04 header documents mechanism/restart/spend-limit (missing a clause in $CFG_OK)"
fi

echo "== AC-004-05 wiring check exits 0 when values match =="
run_check "$DEC" "$CFG_OK"
if [ "$RUN_RC" -eq 0 ] && grep -q 'every stage resolves' "$TMP/out"; then
  ok "AC-004-05 wiring check: exit 0 when every stage matches the decision"
else
  bad "AC-004-05 wiring check: exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-004-06 wiring check exits 1 and names the stage on mismatch =="
run_check "$DEC" "$CFG_BAD"
if [ "$RUN_RC" -eq 1 ] && grep -q 'spec-coder' "$TMP/out"; then
  ok "AC-004-06 mismatch: exit 1, names spec-coder"
else
  bad "AC-004-06 mismatch: exit 1 names the stage (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-004-07 missing input exits 2 =="
run_check "$TMP/does-not-exist.txt" "$CFG_OK"
if [ "$RUN_RC" -eq 2 ] && grep -q 'decision' "$TMP/err"; then
  ok "AC-004-07 missing decision file -> exit 2, message names the input"
else
  bad "AC-004-07 missing decision file -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi
run_check "$DEC" "$TMP/no-config.env"
if [ "$RUN_RC" -eq 2 ] && grep -q 'config' "$TMP/err"; then
  ok "AC-004-07 missing config -> exit 2, message names the input"
else
  bad "AC-004-07 missing config -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-ollama-hybrid-wiring.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-ollama-hybrid-wiring.selftest: all cases pass.${NC}"
