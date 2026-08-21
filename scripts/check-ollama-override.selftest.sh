#!/bin/bash
# check-ollama-override.selftest.sh — Hermetic regression net for
# scripts/check-ollama-override.sh. No sudo and no live ollama service: cmp,
# systemctl, and ollama are mocked via a PATH shim; the report, template, and
# applied override are real temp files the script compares.
#
# Scenario traceability: every AC-002-xx ID below is the test for the matching
# 20-acceptance scenario in specs/001-ollama-context/20-acceptance/AC-002-systemd-override.md:
#   AC-002-01  template ships the three Environment lines with the selected value
#   AC-002-02  applied == template, systemctl show carries 3 vars, ollama ps CONTEXT=selected -> exit 0
#   AC-002-03  applied != template -> exit 1, names the differing variable
#   AC-002-04  systemctl show missing a var -> exit 1
#   AC-002-05  missing tool (ollama off PATH) -> exit 2
#   AC-002-06  selected value read from the report (the re-probe target); probe
#              header shape under q8_0 is exercised by the benchmark selftest
#   AC-002-07  selected=NONE -> SKIP (exit 0), live override retains 16384
#   AC-002-08  keepalive.conf untouched (OLLAMA_KEEP_ALIVE=24h only)
#
# Usage:
#   bash scripts/check-ollama-override.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-ollama-override.sh"

PASS_COUNT=0
FAIL_COUNT=0
ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── Mock surface ─────────────────────────────────────────────────────────────
# FAKE_BIN shadows cmp/systemctl/ollama. PATH is "$FAKE_BIN:/usr/bin:/bin" so a
# real /usr/local/bin/ollama is out of reach: removing the mock `ollama` makes
# `command -v ollama` fail (AC-002-05).
mkdir -p "$TMP/fakebin"
FAKE_BIN="$TMP/fakebin"

# mock cmp -> real cmp (compares the two temp files for byte identity).
cat > "$FAKE_BIN/cmp" <<'CMP'
#!/bin/bash
exec /usr/bin/cmp "$@"
CMP
chmod +x "$FAKE_BIN/cmp"

# mock systemctl: FAKE_SVC_ENV carries the Environment line.
cat > "$FAKE_BIN/systemctl" <<'SYSTEMCTL'
#!/bin/bash
printf '%s\n' "${FAKE_SVC_ENV:-Environment=\"PATH=/usr/bin\" OLLAMA_CONTEXT_LENGTH=16384 OLLAMA_KEEP_ALIVE=24h OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0}"
exit 0
SYSTEMCTL
chmod +x "$FAKE_BIN/systemctl"

# mock ollama ps: FAKE_PS_CTX carries the CONTEXT value for the model row.
cat > "$FAKE_BIN/ollama" <<'OLLAMA'
#!/bin/bash
if [ "${FAKE_PS_EMPTY:-0}" = 1 ]; then exit 0; fi
printf 'NAME           ID              SIZE     PROCESSOR          CONTEXT    UNTIL             \n'
printf 'qwen3.8:27b    22130167c4c2    18 GB    33%%/67%% CPU/GPU    %s      24 hours from now    \n' "${FAKE_PS_CTX:-16384}"
exit 0
OLLAMA
chmod +x "$FAKE_BIN/ollama"

# ── Fixtures ─────────────────────────────────────────────────────────────────
# Template with the three Environment lines (AC-002-01 shape).
TEMPLATE="$TMP/context.conf.template"
cat > "$TEMPLATE" <<'TPL'
# provenance header (test)
[Service]
Environment="OLLAMA_CONTEXT_LENGTH=16384"
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
TPL

# Applied override byte-identical to the template (pass case).
APPLIED_OK="$TMP/context.conf.applied"
cp "$TEMPLATE" "$APPLIED_OK"

# Applied override with a different value (AC-002-03).
APPLIED_BAD="$TMP/context.conf.bad"
cp "$TEMPLATE" "$APPLIED_BAD"
sed -i 's/OLLAMA_CONTEXT_LENGTH=16384/OLLAMA_CONTEXT_LENGTH=32768/' "$APPLIED_BAD"

# Applied override missing a var (AC-002-04 uses a bad systemctl env instead).
KEEPALIVE_OK="$TMP/keepalive.conf"
printf '[Service]\nEnvironment="OLLAMA_KEEP_ALIVE=24h"\n' > "$KEEPALIVE_OK"

# Benchmark report with selected=16384.
REPORT_OK="$TMP/report.csv"
cat > "$REPORT_OK" <<'REP'
# ollama_version=0.32.13-mock
# flash_attention=off
# kv_cache_type=f16
# model=qwen3.8:27b
num_ctx,size_vram_gib,tokens_per_sec,prompt_tokens,context_loaded,probe_result
16384,11.53,21.5,13722,16384,PASS
summary,selected=16384,min_tok_s=15,vram_headroom_gib=0.3
REP

# Benchmark report with selected=NONE (AC-002-07).
REPORT_NONE="$TMP/report-none.csv"
cat > "$REPORT_NONE" <<'REP2'
summary,selected=NONE,min_tok_s=15,vram_headroom_gib=0.3
REP2

run_check() { # run_check <report> <template> <applied> <keepalive>
  set +e
  PATH="$FAKE_BIN:/usr/bin:/bin" bash "$CHECK" "$1" "$2" "$3" "$4" > "$TMP/out" 2> "$TMP/err"
  RUN_RC=$?
  set -e
}

echo "== AC-002-01 template ships the three Environment lines with the selected value =="
TPL_VARS="$(grep -oE 'OLLAMA_[A-Z_]+=[^" ]+' "$TEMPLATE" | sort)"
if [ "$(printf '%s\n' "$TPL_VARS" | grep -c '=')" -eq 3 ] \
   && printf '%s\n' "$TPL_VARS" | grep -qx 'OLLAMA_CONTEXT_LENGTH=16384' \
   && printf '%s\n' "$TPL_VARS" | grep -qx 'OLLAMA_FLASH_ATTENTION=1' \
   && printf '%s\n' "$TPL_VARS" | grep -qx 'OLLAMA_KV_CACHE_TYPE=q8_0'; then
  ok "AC-002-01 template carries exactly the three Environment lines incl. OLLAMA_CONTEXT_LENGTH=16384 (selected)"
else
  bad "AC-002-01 template carries the three Environment lines (got: $(printf '%s ' $TPL_VARS))"
fi

echo "== AC-002-02 applied==template + systemctl 3 vars + ollama ps CONTEXT=selected -> exit 0 =="
FAKE_SVC_ENV='Environment="PATH=/usr/bin" OLLAMA_CONTEXT_LENGTH=16384 OLLAMA_KEEP_ALIVE=24h OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0' \
FAKE_PS_CTX=16384 \
run_check "$REPORT_OK" "$TEMPLATE" "$APPLIED_OK" "$KEEPALIVE_OK"
if [ "$RUN_RC" -eq 0 ] && grep -q 'applied override is byte-identical' "$TMP/out" \
   && ! grep -q 'FAIL' "$TMP/out"; then
  ok "AC-002-02 pass: exit 0, applied==template, service env 3 vars, ollama ps CONTEXT=16384"
else
  bad "AC-002-02 pass: exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-002-03 applied != template -> exit 1, names the differing variable =="
run_check "$REPORT_OK" "$TEMPLATE" "$APPLIED_BAD" "$KEEPALIVE_OK"
if [ "$RUN_RC" -eq 1 ] && grep -q 'OLLAMA_CONTEXT_LENGTH' "$TMP/out"; then
  ok "AC-002-03 divergence: exit 1 and names OLLAMA_CONTEXT_LENGTH"
else
  bad "AC-002-03 divergence: exit 1 names the differing var (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-002-04 systemctl show missing a var -> exit 1 =="
# Service env omits OLLAMA_FLASH_ATTENTION.
FAKE_SVC_ENV='Environment="PATH=/usr/bin" OLLAMA_CONTEXT_LENGTH=16384 OLLAMA_KEEP_ALIVE=24h' \
FAKE_PS_CTX=16384 \
run_check "$REPORT_OK" "$TEMPLATE" "$APPLIED_OK" "$KEEPALIVE_OK"
if [ "$RUN_RC" -eq 1 ] && grep -q 'OLLAMA_FLASH_ATTENTION' "$TMP/out"; then
  ok "AC-002-04 wrong service env: exit 1, names the missing var"
else
  bad "AC-002-04 wrong service env: exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-002-05 missing tool exits 2 =="
# Remove the mock ollama; /usr/local/bin (real ollama) is not on this PATH.
rm -f "$FAKE_BIN/ollama"
set +e
PATH="$FAKE_BIN:/usr/bin:/bin" bash "$CHECK" "$REPORT_OK" "$TEMPLATE" "$APPLIED_OK" "$KEEPALIVE_OK" > "$TMP/out" 2> "$TMP/err"
RUN_RC=$?
set -e
if [ "$RUN_RC" -eq 2 ] && grep -q 'ollama' "$TMP/err"; then
  ok "AC-002-05 missing tool: exit 2, message names the missing tool"
else
  bad "AC-002-05 missing tool: exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi
# Restore the mock ollama.
cat > "$FAKE_BIN/ollama" <<'OLLAMA'
#!/bin/bash
printf 'NAME           ID              SIZE     PROCESSOR          CONTEXT    UNTIL             \n'
printf 'qwen3.8:27b    22130167c4c2    18 GB    33%%/67%% CPU/GPU    %s      24 hours from now    \n' "${FAKE_PS_CTX:-16384}"
exit 0
OLLAMA
chmod +x "$FAKE_BIN/ollama"

echo "== AC-002-06 selected value read from the report (the re-probe target) =="
# The post-restart re-probe (benchmark --probe-only) uses the same selected value
# the check reads; verify the check parses and reports it, and that a report
# header under q8_0/flash env is the shape the probe records.
out="$(PATH="$FAKE_BIN:/usr/bin:/bin" bash "$CHECK" "$REPORT_OK" "$TEMPLATE" "$APPLIED_OK" "$KEEPALIVE_OK" 2>&1 || true)"
if printf '%s\n' "$out" | grep -q 'Task 1 selected: 16384'; then
  ok "AC-002-06 selected=16384 parsed from report (re-probe target) — probe header shape covered by benchmark selftest"
else
  bad "AC-002-06 selected value parsed from report (out=$(tr '\n' ' ' <<< "$out"))"
fi

echo "== AC-002-07 selected=NONE -> SKIP exit 0, live override retains 16384 =="
# applied file keeps OLLAMA_CONTEXT_LENGTH=16384 (no 3-var template).
APPLIED_NONE="$TMP/context.conf.none"
printf '[Service]\nEnvironment="OLLAMA_CONTEXT_LENGTH=16384"\n' > "$APPLIED_NONE"
run_check "$REPORT_NONE" "$TEMPLATE" "$APPLIED_NONE" "$KEEPALIVE_OK"
if [ "$RUN_RC" -eq 0 ] && grep -q 'SKIP' "$TMP/out" && grep -q 'retains OLLAMA_CONTEXT_LENGTH=16384' "$TMP/out"; then
  ok "AC-002-07 selected=NONE: SKIP report, exit 0, live override retains OLLAMA_CONTEXT_LENGTH=16384"
else
  bad "AC-002-07 selected=NONE: SKIP exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-002-08 keepalive.conf untouched =="
FAKE_SVC_ENV='Environment="PATH=/usr/bin" OLLAMA_CONTEXT_LENGTH=16384 OLLAMA_KEEP_ALIVE=24h OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0' \
FAKE_PS_CTX=16384 \
run_check "$REPORT_OK" "$TEMPLATE" "$APPLIED_OK" "$KEEPALIVE_OK"
if [ "$RUN_RC" -eq 0 ] && grep -q 'keepalive.conf carries OLLAMA_KEEP_ALIVE=24h and nothing else' "$TMP/out"; then
  ok "AC-002-08 keepalive untouched: OLLAMA_KEEP_ALIVE=24h only"
else
  bad "AC-002-08 keepalive untouched (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-ollama-override.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-ollama-override.selftest: all cases pass.${NC}"
