#!/bin/bash
# benchmark-ollama-context.selftest.sh — Hermetic regression net for
# scripts/benchmark-ollama-context.sh. No live ollama server: the ollama API
# (curl) and the ollama service environment (systemctl) are mocked via a PATH
# shim; python3, awk, and the coreutils are real.
#
# The benchmark probes /v1/chat/completions (AC-001-02). The mock serves both
# shapes the benchmark uses: a NON-STREAMING turn-1 response (usage.prompt_tokens
# for the fill check) and a STREAMING turn-2 response (data: deltas then [DONE],
# from which the benchmark counts completion tokens and measures wall-clock
# generation time). tokens_per_sec is made deterministic by a mock per-delta
# delay (FAKE_GEN_DELAY_S): tok_s ~= 1/delay for large delta counts.
#
# Scenario traceability: every AC-001-xx ID below is the test for the matching
# 20-acceptance scenario in specs/001-ollama-context/20-acceptance/AC-001-benchmark-harness.md:
#   AC-001-01  full sweep over the default context values
#   AC-001-02  report columns are complete (VRAM in GiB, tok/s via /v1/chat/completions)
#   AC-001-03  probe PASS when the follow-up contains the marker
#   AC-001-04  probe FAIL when the marker was dropped by truncation
#   AC-001-05  under-filled probe is INVALID, excluded from selection
#   AC-001-06  requested context not honored is INVALID, excluded from selection
#   AC-001-07  selection picks the largest fully viable context
#   AC-001-08  no viable context records selected=NONE, still exits 0
#   AC-001-09  probe-only mode reports pass or fail
#   AC-001-10  tooling failure exits 2 (--out missing / server unreachable /
#              model not present)
#
# Usage:
#   bash scripts/benchmark-ollama-context.selftest.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/scripts/benchmark-ollama-context.sh"

PASS_COUNT=0
FAIL_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ── Mock surface ─────────────────────────────────────────────────────────────
# FAKE_BIN provides curl + systemctl; FAKE_STATE carries the last num_ctx the
# fake chat call saw (the /api/ps mock reports it as the loaded context).
# Behavior knobs (env):
#   FAKE_DROP_MARKER=1    turn-2 completion omits the marker  -> FAIL
#   FAKE_LOW_PROMPT=1     usage.prompt_tokens = 0.5 x num_ctx -> INVALID
#   FAKE_CTX_MISMATCH=1   /api/ps context = num_ctx - 1024   -> INVALID
#   FAKE_SIZE_VRAM_BYTES  /api/ps size_vram (default 12 GiB)
#   FAKE_UNREACHABLE=1    /api/version fails                 -> exit 2
#   FAKE_NO_MODEL=1       /api/tags lists no models          -> exit 2
#   FAKE_SVC_ENV          systemctl Environment line (default: 16384 only)
#   FAKE_GEN_DELAY_S     per-delta sleep (seconds) in the streaming mock (default 0.03)
#   FAKE_CT                completion-token count per streamed turn-2 (default 40)
mkdir -p "$TMP/fakebin" "$TMP/state"
FAKE_BIN="$TMP/fakebin"
FAKE_STATE="$TMP/state/num_ctx"
export FAKE_STATE FAKE_BIN
cat > "$FAKE_BIN/curl" <<'FAKECURL'
#!/bin/bash
url=""
body_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    -sf|-s|-f) ;;
    --max-time) ;;
    -H) ;;
    -d) body_file="${2#@}" ;;
    -d@*) body_file="${1#-d@}" ;;
    http://*|https://*) url="$1" ;;
    *) ;;
  esac
  shift
done
case "$url" in
  */api/version)
    if [ "${FAKE_UNREACHABLE:-0}" = 1 ]; then exit 7; fi
    printf '%s\n' '{"version":"0.32.13-mock"}'
    ;;
  */api/tags)
    if [ "${FAKE_NO_MODEL:-0}" = 1 ]; then printf '%s\n' '{"models":[]}'; exit 0; fi
    printf '%s\n' '{"models":[{"name":"qwen3.8:27b"}]}'
    ;;
  */v1/chat/completions)
    body="$(cat "$body_file")"
    num_ctx="$(printf '%s' "$body" | grep -oE '"num_ctx": ?[0-9]+' | grep -oE '[0-9]+')"
    printf '%s' "$num_ctx" > "$FAKE_STATE"
    marker="$(printf '%s' "$body" | grep -oE 'MKT_[A-Za-z0-9_]+' | head -1)"
    stream="$(printf '%s' "$body" | grep -oE '"stream": ?true' | head -1)"
    if [ "${FAKE_LOW_PROMPT:-0}" = 1 ]; then
      pe=$(( num_ctx / 2 ))
    else
      pe=$(( num_ctx * 85 / 100 ))
    fi
    ec="${FAKE_CT:-40}"
    if [ -n "$stream" ]; then
      # Streaming turn-2: ec content deltas (one per token), then [DONE].
      # Each delta is a single char so the benchmark counts ec completion tokens;
      # a per-delta sleep makes tok_s deterministic (~1/delay).
      delay_s="${FAKE_GEN_DELAY_S:-0.03}"
      resp="$marker"
      [ "${FAKE_DROP_MARKER:-0}" = 1 ] && resp="sorry I do not recall"
      i=0
      while [ "$i" -lt "$ec" ]; do
        ch="${resp:$i:1}"
        [ -z "$ch" ] && ch="x"
        printf 'data: {"choices":[{"delta":{"content":"%s"},"finish_reason":null}]}\n' "$ch"
        sleep "$delay_s"
        i=$((i + 1))
      done
      printf 'data: {"choices":[{"delta":{},"finish_reason":"stop"}]}\n'
      printf 'data: [DONE]\n'
    else
      # Non-streaming turn-1: usage.prompt_tokens drives the fill check.
      resp="$marker"
      printf '{"choices":[{"message":{"role":"assistant","content":"%s"},"finish_reason":"stop"}],"usage":{"prompt_tokens":%d,"completion_tokens":%d,"total_tokens":%d}}\n' "$resp" "$pe" "$ec" $((pe+ec))
    fi
    ;;
  */api/ps)
    ctx="$(cat "$FAKE_STATE" 2>/dev/null || echo 16384)"
    [ "${FAKE_CTX_MISMATCH:-0}" = 1 ] && ctx=$(( ctx - 1024 ))
    printf '{"models":[{"name":"qwen3.8:27b","size_vram":%s,"context_length":%s}]}\n' "${FAKE_SIZE_VRAM_BYTES:-12884901888}" "$ctx"
    ;;
  *)
    echo "unexpected url: $url" >&2
    exit 1
    ;;
esac
exit 0
FAKECURL
chmod +x "$FAKE_BIN/curl"

cat > "$FAKE_BIN/systemctl" <<'FAKESVC'
#!/bin/bash
if [ "${FAKE_SVC_ENV_UNSET:-0}" = 1 ]; then exit 1; fi
printf 'Environment="PATH=/usr/bin" %s\n' "${FAKE_SVC_ENV:-OLLAMA_CONTEXT_LENGTH=16384}"
exit 0
FAKESVC
chmod +x "$FAKE_BIN/systemctl"

# run_bench <args...> — run the benchmark under the mock PATH; captures stdout,
# sets RUN_RC. A mock state reset per invocation keeps rows independent.
run_bench() {
  rm -f "$FAKE_STATE"
  set +e
  PATH="$FAKE_BIN:$PATH" bash "$BENCH" "$@" > "$TMP/out" 2> "$TMP/err"
  RUN_RC=$?
  set -e
}

echo "== AC-001-01 full sweep over the default context values =="

# 01: default sweep -> exit 0, CSV = 1 header row + 4 data rows + summary.
run_bench --out "$TMP/sweep.csv"
if [ "$RUN_RC" -eq 0 ] \
   && [ "$(grep -c '^num_ctx,' "$TMP/sweep.csv")" -eq 1 ] \
   && [ "$(grep -c '^16384,\|^32768,\|^49152,\|^65536,' "$TMP/sweep.csv")" -eq 4 ] \
   && [ "$(grep -c '^summary,' "$TMP/sweep.csv")" -eq 1 ]; then
  ok "AC-001-01 default sweep: exit 0, one header row, four data rows (16384/32768/49152/65536), one summary line"
else
  bad "AC-001-01 default sweep: exit 0, one header row, four data rows, one summary line (rc=$RUN_RC: $(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-001-02 report columns are complete =="

# 02: columns present; size_vram_gib = bytes/2^30 (12 GiB default); tok/s from
# completion tokens / wall-clock generation time measured on /v1/chat/completions.
# With FAKE_GEN_DELAY_MS=30 and ec=40, tok_s = 40/(39*0.03) ~= 34; assert a
# positive, deterministic-in-range value (20..50) proving the formula, not the
# old fixed eval_duration.
row_16384="$(grep '^16384,' "$TMP/sweep.csv" | head -1)"
if printf '%s\n' "$row_16384" | grep -qE '^16384,12\.00,[0-9]+\.[0-9],[0-9]+,16384,PASS$'; then
  tok="$(printf '%s\n' "$row_16384" | cut -d, -f3)"
  if awk -v t="$tok" 'BEGIN { exit !(t >= 20 && t <= 50) }'; then
    ok "AC-001-02 row columns: num_ctx,size_vram_gib(12.00),tokens_per_sec($tok from completion/gen_time on /v1/chat/completions),prompt_tokens,context_loaded,probe_result"
  else
    bad "AC-001-02 tokens_per_sec out of expected range (got $tok, expected 20..50)"
  fi
else
  bad "AC-001-02 row columns: num_ctx,size_vram_gib,tokens_per_sec,prompt_tokens,context_loaded,probe_result (row='$row_16384')"
fi

echo "== AC-001-03 probe PASS when the follow-up contains the marker =="

# 03: default mock retains the marker -> every row PASS.
if [ "$(grep -c ',PASS$' "$TMP/sweep.csv")" -eq 4 ]; then
  ok "AC-001-03 probe PASS: turn-2 completion contains the marker (4/4 rows PASS)"
else
  bad "AC-001-03 probe PASS: turn-2 completion contains the marker (got $(grep -c ',PASS$' "$TMP/sweep.csv" || true)/4)"
fi

echo "== AC-001-04 probe FAIL when the marker was dropped by truncation =="

FAKE_DROP_MARKER=1 run_bench --out "$TMP/fail.csv" --num-ctx "16384"
if [ "$(grep -c ',FAIL$' "$TMP/fail.csv")" -eq 1 ] && grep -q '^16384,12\.00,[0-9.]*,[0-9]*,16384,FAIL$' "$TMP/fail.csv"; then
  ok "AC-001-04 probe FAIL: marker dropped -> probe_result=FAIL"
else
  bad "AC-001-04 probe FAIL: marker dropped -> probe_result=FAIL (out=$(tr '\n' ' ' < "$TMP/fail.csv"))"
fi

echo "== AC-001-05 under-filled probe is INVALID =="

# 05: usage.prompt_tokens stays at 0.5 x num_ctx across the grow retries -> the
# row is INVALID and excluded from selection (selected=NONE).
FAKE_LOW_PROMPT=1 run_bench --out "$TMP/low.csv" --num-ctx "16384"
if [ "$(grep -c ',INVALID$' "$TMP/low.csv")" -eq 1 ] && grep -q '^summary,selected=NONE' "$TMP/low.csv"; then
  ok "AC-001-05 under-filled probe: INVALID row, excluded from selection (selected=NONE)"
else
  bad "AC-001-05 under-filled probe: INVALID row, excluded from selection (out=$(tr '\n' ' ' < "$TMP/low.csv"))"
fi

echo "== AC-001-06 requested context not honored is INVALID =="

FAKE_CTX_MISMATCH=1 run_bench --out "$TMP/mismatch.csv" --num-ctx "16384"
if [ "$(grep -c ',INVALID$' "$TMP/mismatch.csv")" -eq 1 ] && grep -q '^summary,selected=NONE' "$TMP/mismatch.csv"; then
  ok "AC-001-06 context mismatch: context_loaded != num_ctx -> INVALID, excluded from selection"
else
  bad "AC-001-06 context mismatch: context_loaded != num_ctx -> INVALID (out=$(tr '\n' ' ' < "$TMP/mismatch.csv"))"
fi

echo "== AC-001-07 selection picks the largest fully viable context =="

# 07: all rows PASS, VRAM 12.00 <= 16.0 (16.3 - 0.3 headroom), tok_s ~34 >= 15
# -> selected = 65536; summary records the thresholds.
if grep -q '^summary,selected=65536,min_tok_s=15,vram_headroom_gib=0.3$' "$TMP/sweep.csv"; then
  ok "AC-001-07 selection: largest PASS row within VRAM headroom and tok/s floor -> selected=65536, thresholds recorded"
else
  bad "AC-001-07 selection: largest PASS row within thresholds -> selected=65536 (summary=$(grep '^summary,' "$TMP/sweep.csv" || true))"
fi

echo "== AC-001-08 no viable context records selected=NONE =="

# 08: PASS rows but VRAM 20 GiB > 16.0 -> no candidate -> selected=NONE, exit 0.
FAKE_SIZE_VRAM_BYTES=21474836480 run_bench --out "$TMP/none.csv" --num-ctx "16384"
if [ "$RUN_RC" -eq 0 ] && grep -q '^summary,selected=NONE' "$TMP/none.csv"; then
  ok "AC-001-08 no viable context: selected=NONE, script still exits 0"
else
  bad "AC-001-08 no viable context: selected=NONE, exit 0 (rc=$RUN_RC, summary=$(grep '^summary,' "$TMP/none.csv" || true))"
fi

echo "== AC-001-09 probe-only mode reports pass or fail =="

run_bench --probe-only 49152
if [ "$RUN_RC" -eq 0 ] && grep -q 'probe_only,num_ctx=49152,probe_result=PASS' "$TMP/out"; then
  ok "AC-001-09 probe-only: PASS -> exit 0"
else
  bad "AC-001-09 probe-only: PASS -> exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi
FAKE_DROP_MARKER=1 run_bench --probe-only 49152
if [ "$RUN_RC" -eq 1 ] && grep -q 'probe_only,num_ctx=49152,probe_result=FAIL' "$TMP/out"; then
  ok "AC-001-09 probe-only: FAIL -> exit 1"
else
  bad "AC-001-09 probe-only: FAIL -> exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$TMP/out"))"
fi

echo "== AC-001-10 tooling failure exits 2 =="

# 10a: no --out argument.
run_bench
if [ "$RUN_RC" -eq 2 ] && grep -q -- '--out' "$TMP/err"; then
  ok "AC-001-10 missing --out: exit 2, message names --out"
else
  bad "AC-001-10 missing --out: exit 2, message names --out (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi
# 10b: unreachable ollama server.
FAKE_UNREACHABLE=1 run_bench --out "$TMP/u.csv"
if [ "$RUN_RC" -eq 2 ] && grep -qi 'unreachable' "$TMP/err"; then
  ok "AC-001-10 unreachable server: exit 2, message names the failure"
else
  bad "AC-001-10 unreachable server: exit 2, message names the failure (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi
# 10c: model not present.
FAKE_NO_MODEL=1 run_bench --out "$TMP/nm.csv"
if [ "$RUN_RC" -eq 2 ] && grep -qi "model 'qwen3.8:27b' not present" "$TMP/err"; then
  ok "AC-001-10 model not present: exit 2, message names the model"
else
  bad "AC-001-10 model not present: exit 2, message names the model (rc=$RUN_RC, err=$(tr '\n' ' ' < "$TMP/err"))"
fi

# Report header: flash attention / KV cache type recorded from the (mocked)
# service env — the AC-002-06 shape is exercised here too.
if grep -q '^# flash_attention=off$' "$TMP/sweep.csv" && grep -q '^# kv_cache_type=f16$' "$TMP/sweep.csv" \
   && grep -q '^# ollama_version=0.32.13-mock$' "$TMP/sweep.csv" && grep -q '^# model=qwen3.8:27b$' "$TMP/sweep.csv"; then
  ok "report header records the server environment (version, flash attention, KV type, model)"
else
  bad "report header records the server environment (header: $(grep '^#' "$TMP/sweep.csv" | tr '\n' ' '))"
fi
FAKE_SVC_ENV='OLLAMA_CONTEXT_LENGTH=49152 OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0' run_bench --out "$TMP/env2.csv" --num-ctx "16384"
if grep -q '^# flash_attention=1$' "$TMP/env2.csv" && grep -q '^# kv_cache_type=q8_0$' "$TMP/env2.csv"; then
  ok "AC-002-06 header shape: probe run records flash attention on and KV cache type q8_0 when the service env carries them"
else
  bad "AC-002-06 header shape: flash attention + KV type from service env (header: $(grep '^#' "$TMP/env2.csv" | tr '\n' ' '))"
fi

echo ""
echo "selftest: $PASS_COUNT passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ benchmark-ollama-context.selftest: $FAIL_COUNT case(s) failed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ benchmark-ollama-context.selftest: all cases pass.${NC}"
