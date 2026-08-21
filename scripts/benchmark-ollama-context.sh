#!/bin/bash
# benchmark-ollama-context.sh — Empirically measure qwen3.8:27b at four context
# sizes (16384 / 32768 / 49152 / 65536) with a synthetic long-prompt +
# thread-retention probe, and select the largest fully viable context.
#
# The harness sets num_ctx per request via the ollama API (options.num_ctx),
# which works independently of the server's OLLAMA_CONTEXT_LENGTH default — so
# it measures all four values against the server as-is. The selection uses the
# pre-flash-attention, pre-q8_0 baseline, which is conservative: flash attention
# + q8_0 KV cache only reduce KV VRAM, so any context that fits the baseline
# also fits the target configuration.
#
# Probe semantics (per 20-acceptance/AC-001-benchmark-harness.md):
#   - Turn 1 is a synthetic user message whose first tokens embed a unique
#     marker token, padded to ~0.85 x num_ctx tokens.
#   - Turn 2 is a follow-up asking for that marker (the full turn-1 content is
#     re-sent, simulating a continuing thread).
#   - probe_result=PASS iff the turn-2 completion contains the marker (the
#     thread survived), FAIL iff it does not (the oldest message — and its
#     marker — was dropped, the observed truncation failure mode).
#   - A row is INVALID (excluded from selection) when prompt_tokens < 0.8 x
#     num_ctx (under-filled probe — vacuous) or when the loaded context
#     reported by /api/ps differs from num_ctx (requested context not honored).
#
# Measurement endpoint (AC-001-02): the probe and tokens_per_sec are measured
# via the OpenAI-compatible /v1/chat/completions endpoint — the one opencode
# actually uses to call the model — not /api/generate. /v1/chat/completions
# returns no eval_duration, so tokens_per_sec is measured as completion tokens
# divided by wall-clock generation time: the probe's turn-2 completion is
# streamed, and gen_time is the wall-clock span from the first streamed delta
# to [DONE] (excluding the prompt prefill). completion_tokens is the number of
# streamed deltas, which tracks ollama's usage.completion_tokens (calibrated
# within ~1%).
#
# Selection: the largest num_ctx among rows with probe_result=PASS,
# size_vram_gib <= 16.3 - <vram-headroom-gib>, and
# tokens_per_sec >= <min-tok-s>. When no row qualifies the summary records
# selected=NONE and the script still exits 0.
#
# Exit codes:
#   0 — benchmark completed (report written; selected may be NONE)
#   1 — probe-only mode: the retention probe at the given context failed
#   2 — tooling failure: missing --out, unreachable ollama, model not found,
#       missing required tool, or an unparseable API response
#
# Scenario traceability: this script is exercised by
# scripts/benchmark-ollama-context.selftest.sh which cites every AC-001-xx ID.
#
# Usage:
#   scripts/benchmark-ollama-context.sh --out <file> [--num-ctx "16384 32768 49152 65536"]
#       [--min-tok-s 15] [--vram-headroom-gib 0.3] [--model qwen3.8:27b]
#       [--ollama-host http://localhost:11434]
#   scripts/benchmark-ollama-context.sh --probe-only <num_ctx> [--model ...] [--ollama-host ...]
set -euo pipefail

# Shared helpers (require_tools). Sourced after flags so the script's own
# set -euo pipefail governs.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/check-common.sh"

DEFAULT_NUM_CTX="16384 32768 49152 65536"
NUM_CTX_LIST="$DEFAULT_NUM_CTX"
OUT_FILE=""
MIN_TOK_S=15
VRAM_HEADROOM_GIB=0.3
VRAM_TOTAL_GIB=16.3
MODEL="qwen3.8:27b"
OLLAMA_HOST="http://localhost:11434"
PROBE_ONLY=""

# Minimum fill ratio for a valid probe (AC-001-05): prompt_tokens >= 0.8 x num_ctx.
MIN_FILL_RATIO=0.8
# Padding target: ~0.85 x num_ctx tokens (safely above the 0.8 floor, small
# enough that turn 1 + the short turn-2 follow-up still fit the window).
FILL_RATIO=0.85
# Approximate characters per token for the filler prose (qwen3 tokenizer).
CHARS_PER_TOKEN=4.5
FILLER='The quick brown fox jumps over the lazy dog near the river bank while the moon rises slowly above the silent forest. '

usage() {
  sed -n 's/^#   \(.*\)$/\1/p' "$0" | sed -n '/Usage:/,$p'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_FILE="${2:-}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --num-ctx) NUM_CTX_LIST="${2:-$DEFAULT_NUM_CTX}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --min-tok-s) MIN_TOK_S="${2:-15}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --vram-headroom-gib) VRAM_HEADROOM_GIB="${2:-0.3}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --model) MODEL="${2:-qwen3.8:27b}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --ollama-host) OLLAMA_HOST="${2:-http://localhost:11434}"; [ $# -gt 1 ] && shift 2 || shift ;;
    --probe-only) PROBE_ONLY="${2:-}"; [ $# -gt 1 ] && shift 2 || shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; exit 2 ;;
  esac
done

# ── Tooling preflight (AC-001-10): missing tool = exit 2, never a clean run ──
require_tools benchmark-ollama-context curl python3 grep sed awk head wc tr sort yes cut cat cp mv seq sleep date

# Scratch space for probe bodies/responses; one trap, cleaned on any exit path.
TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# ── Argument validation ──────────────────────────────────────────────────────
if [ -n "$PROBE_ONLY" ]; then
  case "$PROBE_ONLY" in
    *[!0-9]*) echo "ERROR: --probe-only requires a numeric num_ctx, got '$PROBE_ONLY'" >&2; exit 2 ;;
  esac
else
  if [ -z "$OUT_FILE" ]; then
    echo "ERROR: --out <file> is required (AC-001-10 tooling failure)" >&2
    exit 2
  fi
  for n in $NUM_CTX_LIST; do
    case "$n" in
      *[!0-9]*) echo "ERROR: --num-ctx values must be numeric, got '$n'" >&2; exit 2 ;;
    esac
  done
fi

# ── Server preflight (AC-001-10): unreachable ollama / model not found ───────
VERSION_JSON="$(curl -sf --max-time 15 "$OLLAMA_HOST/api/version" 2>/dev/null || true)"
if [ -z "$VERSION_JSON" ]; then
  echo "ERROR: ollama server unreachable at $OLLAMA_HOST (AC-001-10 tooling failure)" >&2
  exit 2
fi
OLLAMA_VERSION="$(printf '%s' "$VERSION_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("version",""))' 2>/dev/null || true)"
[ -n "$OLLAMA_VERSION" ] || { echo "ERROR: unparseable /api/version response from $OLLAMA_HOST" >&2; exit 2; }

TAGS_JSON="$(curl -sf --max-time 15 "$OLLAMA_HOST/api/tags" 2>/dev/null || true)"
if [ -z "$TAGS_JSON" ]; then
  echo "ERROR: cannot list models at $OLLAMA_HOST (AC-001-10 tooling failure)" >&2
  exit 2
fi
MODEL_PRESENT="$(printf '%s' "$TAGS_JSON" | MODEL="$MODEL" python3 -c '
import json,sys,os
m=os.environ["MODEL"]
d=json.load(sys.stdin)
print("yes" if any(t.get("name")==m or t.get("name","").startswith(m.split(":")[0]+":") for t in d.get("models",[])) else "no")
' 2>/dev/null || true)"
if [ "$MODEL_PRESENT" != "yes" ]; then
  echo "ERROR: model '$MODEL' not present on the ollama server (AC-001-10 tooling failure)" >&2
  exit 2
fi

# ── Server environment for the report header ─────────────────────────────────
# Flash attention / KV cache type come from the ollama service environment
# (systemctl show works read-only, no sudo). Absent values are the ollama
# defaults (flash attention off, KV cache f16).
SVC_ENV="$(systemctl show ollama.service -p Environment 2>/dev/null || true)"
env_get() { # env_get <name> — value of an OLLAMA_ var in the service env, "" if absent
  printf '%s\n' "$SVC_ENV" | grep -oE "$1=[^ \"']+" | head -1 | cut -d= -f2- || true
}
FLASH_ATTENTION="$(env_get 'OLLAMA_FLASH_ATTENTION')"
KV_CACHE_TYPE="$(env_get 'OLLAMA_KV_CACHE_TYPE')"
FLASH_ATTENTION="${FLASH_ATTENTION:-off}"
KV_CACHE_TYPE="${KV_CACHE_TYPE:-f16}"

# ── JSON body / response helpers (python3, stdlib — no jq dependency) ────────
# chat_body <prompt_file> <num_ctx> <turn2|""> <stream> — write a
# /v1/chat/completions request body to stdout. With turn2 empty: single turn-1
# message. Else: turn-1 content followed by the short turn-2 follow-up.
chat_body() {
  local prompt_file="$1" n="$2" turn2="${3:-}" stream="$4"
  if [ -n "$turn2" ]; then
    python3 - "$MODEL" "$n" "$prompt_file" "$turn2" "$stream" <<'PY'
import json,sys
model,n,pf,t2,stream=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4],sys.argv[5]
turn1=open(pf).read()
body={"model":model,"messages":[{"role":"user","content":turn1},{"role":"user","content":t2}],"options":{"num_ctx":n},"stream":stream=="true"}
print(json.dumps(body))
PY
  else
    python3 - "$MODEL" "$n" "$prompt_file" "$stream" <<'PY'
import json,sys
model,n,pf,stream=sys.argv[1],int(sys.argv[2]),sys.argv[3],sys.argv[4]
body={"model":model,"messages":[{"role":"user","content":open(pf).read()}],"options":{"num_ctx":n},"stream":stream=="true"}
print(json.dumps(body))
PY
  fi
}

# chat_fields <resp_file> — print "prompt_tokens completion_tokens finish_reason
# response" from a NON-STREAMING /v1/chat/completions response. Numeric fields
# default to 0 so `read` never collapses leading empty fields; non-zero on
# parse failure.
chat_fields() {
  python3 - "$1" <<'PY'
import json,sys
try:
    d=json.load(open(sys.argv[1]))
    usage=d.get("usage",{})
    choices=d.get("choices",[{}])
    fr=choices[0].get("finish_reason","") if choices else ""
    msg=choices[0].get("message",{}) if choices else {}
    print(usage.get("prompt_tokens",0), usage.get("completion_tokens",0), fr, msg.get("content",""))
except Exception:
    sys.exit(1)
PY
}

# chat_stream <content_file> — read a /v1/chat/completions SSE stream from stdin
# (a live pipe from curl), count the streamed content deltas (completion tokens)
# and measure the wall-clock generation time from the first content delta to the
# [DONE] marker (excludes the prompt prefill). Writes the concatenated visible
# content to <content_file> and prints "completion_tokens gen_time_ns" to stdout.
# The program is python3 -c (not a heredoc) so stdin stays free for the SSE
# stream; all parsing happens in one process so gen_time measures the model's
# generation, not subprocess spawn. Non-zero when the stream yielded no content
# delta or no [DONE].
chat_stream() {
  local content_file="$1"
  python3 -c '
import sys,json,time
out_file=sys.argv[1]
t_first=None; t_last=None; n=0; content=""
for raw in sys.stdin:
    line=raw.strip()
    if not line.startswith("data:"): continue
    payload=line[5:].lstrip()
    if payload=="[DONE]":
        t_last=time.monotonic_ns(); break
    try:
        ch=json.loads(payload)
    except Exception:
        continue
    delta=ch.get("choices",[{}])[0].get("delta",{})
    text=delta.get("content","")
    if text:
        if t_first is None: t_first=time.monotonic_ns()
        content+=text
        n+=1
if t_first is None or t_last is None:
    sys.stderr.write("chat stream returned no deltas / no [DONE]\n")
    sys.exit(1)
with open(out_file,"w") as f:
    f.write(content)
print(n, t_last-t_first)
' "$content_file"
}

# ps_fields <resp_file> — print "size_vram context_length" for the model from an
# /api/ps response (field is context_length, the actual loaded context); empty
# output when the model is not loaded.
ps_fields() {
  MODEL="$MODEL" python3 - "$1" <<'PY'
import json,sys,os
m=os.environ["MODEL"]
d=json.load(open(sys.argv[1]))
for x in d.get("models",[]):
    if x.get("name")==m or x.get("name","").startswith(m.split(":")[0]+":"):
        print(x.get("size_vram",""), x.get("context_length",""))
        break
PY
}

# build_prompt <num_ctx> <marker> <prompt_file> — write the turn-1 content
# (marker first, then filler padding targeting 0.85 x num_ctx tokens).
build_prompt() {
  local n="$1" marker="$2" pf="$3" chars
  chars=$(awk -v t="$n" -v r="$FILL_RATIO" -v c="$CHARS_PER_TOKEN" 'BEGIN { printf "%d", t*r*c }')
  {
    printf '%s ' "$marker"
    printf 'This is filler prose used to fill the context window for the retention probe. '
    yes "$FILLER" | head -c "$chars" | tr -d '\n' || true
  } > "$pf"
}

# generate_nonstream <body_file> <resp_file> — POST /v1/chat/completions
# (stream:false) to <resp_file>. The OpenAI-compatible endpoint blocks while the
# model loads (no `load` done_reason), so a bounded retry covers transient
# curl/connection failures; a persistent failure or unparseable response is a
# tooling failure (exit 2). Prints the chat_fields line on success.
generate_nonstream() {
  local body="$1" resp="$2" attempt
  for attempt in $(seq 1 20); do
    curl -sf --max-time 900 -H 'Content-Type: application/json' -d @"$body" \
      "$OLLAMA_HOST/v1/chat/completions" > "$resp" 2>/dev/null || true
    local pt ct fr text
    read -r pt ct fr text < <(chat_fields "$resp" || true) || true
    if [ -n "$fr" ] || [ -n "$text" ] || [ "$pt" -gt 0 ] || [ "$ct" -gt 0 ]; then
      printf '%s %s %s %s\n' "$pt" "$ct" "$fr" "$text"
      return 0
    fi
    sleep 5
  done
  echo "ERROR: unparseable / no response from /v1/chat/completions at $OLLAMA_HOST" >&2
  exit 2
}

# generate_stream <body_file> <content_file> — POST /v1/chat/completions
# (stream:true), piping the live SSE stream into chat_stream, which prints
# "completion_tokens gen_time_ns" to stdout and writes the visible content to
# <content_file>. A bounded retry covers transient connection failures.
generate_stream() {
  local body="$1" content_file="$2" attempt out
  for attempt in $(seq 1 20); do
    out="$(curl -sf --max-time 1800 -H 'Content-Type: application/json' -d @"$body" \
      "$OLLAMA_HOST/v1/chat/completions" 2>/dev/null | chat_stream "$content_file")" && break || true
    out=""
    sleep 5
  done
  if [ -z "$out" ]; then
    echo "ERROR: chat stream never produced a completion from $OLLAMA_HOST" >&2
    exit 2
  fi
  printf '%s\n' "$out"
}

# turn1_fill_check <prompt_file> <num_ctx> — retry loop for turn 1: measure
# the actual prompt fill and grow the padding if under-filled (AC-001-05).
# Prints "prompt_tokens completion_tokens resp_text" to stdout.
turn1_fill_check() {
  local pf="$1" n="$2"
  local b1="$TMPDIR_ROOT/b1.$n" r1="$TMPDIR_ROOT/r1.$n"
  local attempt prompt_tokens completion_tokens resp_text
  prompt_tokens=0
  for attempt in 1 2 3; do
    chat_body "$pf" "$n" "" false > "$b1"
    read -r prompt_tokens completion_tokens _ resp_text < <(generate_nonstream "$b1" "$r1") || true
    if [ -z "$prompt_tokens" ]; then
      echo "ERROR: unparseable /v1/chat/completions response (turn 1) from $OLLAMA_HOST" >&2
      exit 2
    fi
    if under_filled "$prompt_tokens" "$n" && [ "$attempt" -lt 3 ]; then
      grow_padding "$pf" "$prompt_tokens" "$n"
      continue
    fi
    break
  done
  printf '%s %s %s\n' "$prompt_tokens" "$completion_tokens" "$resp_text"
}

# under_filled <prompt_tokens> <num_ctx> — returns 0 when prompt_tokens < 0.8 x num_ctx.
under_filled() {
  local pt="$1" n="$2"
  local min_fill
  min_fill=$(awk -v n="$n" -v r="$MIN_FILL_RATIO" 'BEGIN { printf "%d", n*r }')
  [ "$pt" -lt "$min_fill" ]
}

# grow_padding <prompt_file> <current_tokens> <num_ctx> — append filler to the
# prompt file to reach the fill target.
grow_padding() {
  local pf="$1" have="$2" n="$3"
  local more_chars
  more_chars=$(awk -v n="$n" -v have="$have" -v r="$FILL_RATIO" -v c="$CHARS_PER_TOKEN" \
    'BEGIN { need=n*r-have; if (need<0) need=0; printf "%d", need*c }')
  cp "$pf" "$pf.grow"
  yes "$FILLER" | head -c "$more_chars" | tr -d '\n' >> "$pf.grow" || true
  mv "$pf.grow" "$pf"
}

# determine_probe_result <prompt_tokens> <context_loaded> <resp_text> <marker>
# <num_ctx> — classify the probe as INVALID, PASS, or FAIL (AC-001-05/06).
determine_probe_result() {
  local pt="$1" cl="$2" resp="$3" marker="$4" n="$5"
  local min_fill
  min_fill=$(awk -v n="$n" -v r="$MIN_FILL_RATIO" 'BEGIN { printf "%d", n*r }')
  if [ "$pt" -lt "$min_fill" ] || [ "$cl" -ne "$n" ]; then
    echo "INVALID"
  elif printf '%s' "$resp" | grep -qF "$marker"; then
    echo "PASS"
  else
    echo "FAIL"
  fi
}

# probe <num_ctx> <marker> — run the two-turn retention probe at a context via
# /v1/chat/completions (AC-001-02); prints
# "prompt_tokens tok_s context_loaded probe_result vram_gib" to stdout.
probe() {
  local n="$1" marker="$2"
  local p1="$TMPDIR_ROOT/p.$n.$marker" b2="$TMPDIR_ROOT/b2.$n.$marker"
  local c2="$TMPDIR_ROOT/c2.$n.$marker" ps="$TMPDIR_ROOT/ps.$n.$marker"
  build_prompt "$n" "$marker" "$p1"

  # Turn 1 (non-streaming): measure the actual prompt fill from usage.prompt_tokens;
  # grow the padding if under-filled (bounded retries keep INVALID rows rare,
  # AC-001-05).
  local prompt_tokens completion_tokens resp_text
  read -r prompt_tokens completion_tokens resp_text < <(turn1_fill_check "$p1" "$n") || true

  # Turn 2 (streaming): the follow-up asking for the marker (full turn-1 content
  # re-sent). completion_tokens = streamed delta count; gen_ns = wall-clock from
  # first delta to [DONE] (excludes prefill). Content goes to c2 for the marker
  # check.
  local turn2 gen_ns
  turn2="What was the marker token in my first message? Reply with exactly the marker token and nothing else."
  chat_body "$p1" "$n" "$turn2" true > "$b2"
  read -r completion_tokens gen_ns < <(generate_stream "$b2" "$c2") || true
  if [ -z "$completion_tokens" ]; then
    echo "ERROR: unparseable /v1/chat/completions stream (turn 2) from $OLLAMA_HOST" >&2
    exit 2
  fi
  resp_text="$(cat "$c2" 2>/dev/null || true)"

  # /api/ps: the loaded context + VRAM for the model under test.
  curl -sf --max-time 30 "$OLLAMA_HOST/api/ps" > "$ps" 2>/dev/null || true
  local psout size_vram context_loaded tok_s vram_gib probe_result
  psout="$(ps_fields "$ps" || true)"
  size_vram="$(printf '%s' "$psout" | awk '{print $1}')"
  context_loaded="$(printf '%s' "$psout" | awk '{print $2}')"
  size_vram="${size_vram:-0}"
  context_loaded="${context_loaded:-0}"

  vram_gib=$(awk -v b="$size_vram" 'BEGIN { if (b>0) printf "%.2f", b/1073741824; else print "0.00" }')
  tok_s=$(awk -v c="$completion_tokens" -v d="$gen_ns" \
    'BEGIN { if (d>0) printf "%.1f", c/(d/1000000000); else print "0.0" }')

  probe_result="$(determine_probe_result "$prompt_tokens" "$context_loaded" "$resp_text" "$marker" "$n")"
  printf '%s %s %s %s %s\n' "$prompt_tokens" "$tok_s" "$context_loaded" "$probe_result" "$vram_gib"
}

# emit_header <out> — the report header block (server env the numbers were
# measured under, per AC-001-01/AC-002-06).
emit_header() {
  {
    printf '# ollama_version=%s\n' "$OLLAMA_VERSION"
    printf '# flash_attention=%s\n' "$FLASH_ATTENTION"
    printf '# kv_cache_type=%s\n' "$KV_CACHE_TYPE"
    printf '# model=%s\n' "$MODEL"
    printf '# min_tok_s=%s\n' "$MIN_TOK_S"
    printf '# vram_headroom_gib=%s\n' "$VRAM_HEADROOM_GIB"
    printf '# vram_total_gib=%s\n' "$VRAM_TOTAL_GIB"
  } > "$1"
}

# ── Probe-only mode (AC-001-09 / AC-002-06) ─────────────────────────────────
if [ -n "$PROBE_ONLY" ]; then
  marker="MKT_PO_$(date +%s)_$RANDOM"
  emit_header /dev/stdout
  read -r _ _ _ probe_result _ < <(probe "$PROBE_ONLY" "$marker") || true
  printf 'probe_only,num_ctx=%s,probe_result=%s\n' "$PROBE_ONLY" "$probe_result"
  if [ "$probe_result" = "PASS" ]; then exit 0; fi
  exit 1
fi

# ── Full sweep (AC-001-01) ───────────────────────────────────────────────────
emit_header "$OUT_FILE"
printf 'num_ctx,size_vram_gib,tokens_per_sec,prompt_tokens,context_loaded,probe_result\n' >> "$OUT_FILE"

selected="NONE"
selected_order=-1
for n in $NUM_CTX_LIST; do
  marker="MKT_$(date +%s)_$RANDOM"
  read -r prompt_tokens tok_s context_loaded probe_result vram_gib < <(probe "$n" "$marker") || true
  if [ -z "${prompt_tokens:-}" ]; then
    echo "ERROR: benchmark probe at num_ctx=$n produced no result (see earlier error)" >&2
    exit 2
  fi
  printf '%s,%s,%s,%s,%s,%s\n' "$n" "$vram_gib" "$tok_s" "$prompt_tokens" "$context_loaded" "$probe_result" >> "$OUT_FILE"

  # Selection (AC-001-07 / AC-001-08): PASS + VRAM headroom + tokens/sec floor.
  vram_limit=$(awk -v t="$VRAM_TOTAL_GIB" -v h="$VRAM_HEADROOM_GIB" 'BEGIN { printf "%.2f", t-h }')
  if [ "$probe_result" = "PASS" ] \
     && awk -v v="$vram_gib" -v l="$vram_limit" 'BEGIN { exit !(v <= l) }' \
     && awk -v t="$tok_s" -v m="$MIN_TOK_S" 'BEGIN { exit !(t >= m) }' \
     && [ "$n" -gt "$selected_order" ]; then
    selected="$n"
    selected_order="$n"
  fi
done

printf 'summary,selected=%s,min_tok_s=%s,vram_headroom_gib=%s\n' \
  "$selected" "$MIN_TOK_S" "$VRAM_HEADROOM_GIB" >> "$OUT_FILE"

echo "Benchmark complete: $OUT_FILE"
echo "Selected context: $selected"
exit 0