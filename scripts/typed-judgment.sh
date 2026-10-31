#!/usr/bin/env bash
# typed-judgment.sh — curl+jq wrapper that sends a state payload plus typed
# questions to a judgment API and prints normalized per-question answers
# (spec 028; see docs/SPEC_PIPELINE.md §Typed-judgment layer, ADR 0004).
#
# Usage:
#   scripts/typed-judgment.sh --questions <json>
#       [--state-file <path>] [--max-state-bytes <N>] [--dry-run]
#
# Input:
#   --state-file <path>  State payload source. Without it, the state payload
#                        is read from stdin. A payload that parses as JSON is
#                        embedded as a JSON value; anything else as a string.
#   --max-state-bytes <N>  Payload cap in bytes for the serialized state
#                        (flag wins over the env var below; default 12288 =
#                        12 KB). A non-positive or non-numeric value is a
#                        usage error (exit 2). When the state exceeds the cap
#                        it is truncated deterministically to HEAD + MARKER +
#                        TAIL (both ends preserved, MARKER names the omitted
#                        byte count) and the truncated state is what the
#                        request embeds. Truncation is a degradation, not a
#                        fallback: the reason line below is emitted and the
#                        call proceeds.
#   --questions <json>   Map of question id -> {type, instructions, criteria}.
#                        Passed through verbatim in the request body, so the
#                        CALLER owns the per-type shape contract:
#                          type "choice" -> criteria is an OBJECT keyed by the
#                                           option names; each value describes
#                                           that option
#                          type "score"  -> criteria is an ARRAY (1..255 items)
#                          type "noul"   -> criteria is an OBJECT or null
#                        A string criteria is rejected by the API with HTTP 422,
#                        which this wrapper reports as exit 10 (fallback) — a
#                        silent wrong shape, not a loud failure. Extra keys (e.g.
#                        an "options" array) are accepted and ignored.
#
# Environment:
#   JUDGMENT_BACKEND            'local' | 'hosted' (spec 029). Unset/empty ->
#                               'hosted' (byte-identical to spec 028). 'local'
#                               makes JUDGMENT_API_KEY and JUDGMENT_MODEL
#                               optional: the request is sent without an
#                               Authorization header when no key is set, and
#                               the DEFAULT_LOCAL_MODEL alias below when no
#                               model is set. Any other value -> exit 2.
#   JUDGMENT_API_URL            Judgment API endpoint. Required in both modes;
#                               unset/empty -> fallback.
#   JUDGMENT_API_KEY            Bearer token. Required in hosted mode (unset/
#                               empty -> fallback); optional in local mode.
#                               Never printed in stdout, stderr, or logs.
#   JUDGMENT_MODEL              Model id. Required for a live hosted call;
#                               optional in local mode (default alias below).
#   JUDGMENT_MIN_CONFIDENCE     Usability threshold, default 0.6.
#   JUDGMENT_DAILY_CAP          Max calls per day. Unset -> no cap enforced
#                               and no counter written.
#   JUDGMENT_CAP_DIR            Directory for the daily counter file.
#                               Default: <repo root>/.cache — gitignored.
#   JUDGMENT_BACKOFF_SECONDS    Retry delays, default "1 2". Setting it to
#                               "0" (offline tests) removes the sleep.
#   JUDGMENT_TIMEOUT_SECONDS    Per-attempt curl timeout, default 30.
#   JUDGMENT_MAX_STATE_BYTES    Payload cap in bytes for the serialized state,
#                               default 12288 (12 KB). --max-state-bytes wins.
#                               The measured local-backend failure threshold
#                               on 2026-10-26 was 20548 bytes for a
#                               JSON-shaped state (and drifted lower after a
#                               failing request); 12288 leaves a wide margin.
#   JUDGMENT_DEBUG              Non-empty -> diagnostic lines on stderr.
#                               State payloads in diagnostics are truncated.
#
# Fallback reason line (spec 034):
#   On every exit-10 fallback the wrapper writes exactly one line to stderr:
#     typed-judgment: reason=<unconfigured|unreachable|error>
#   regardless of JUDGMENT_DEBUG. The reason line never carries the API key
#   or state content. Truncation (which does NOT exit 10) writes:
#     typed-judgment: reason=payload_overflow
#     typed-judgment: truncated original_bytes=<N> cap_bytes=<cap>
#   The second line lets consumers record truncated:true plus the original
#   size in telemetry while the call still returns a usable answer (exit 0).
#
# Daily counter file:
#   Path:   $JUDGMENT_CAP_DIR/judgment-cap-YYYY-MM-DD (default .cache/ under
#           the repo root), local date, created on demand.
#   Format: a single line holding the integer count of successful (HTTP 2xx)
#           API calls made today. Incremented after every 2xx response; when
#           the count is already >= JUDGMENT_DAILY_CAP the script falls back
#           (exit 10) before making any request.
#
# API response contract (what this wrapper parses):
#   {"answers": {"<question-id>": {<answer field>, "confidence": <0..1>?,
#     "probabilities": {...}?, "usage": <tokens | {total_tokens} | {input,
#     output}>?, "latency_ms": <ms>?}, ...}}
#     When an answer carries no "usage" but the response does — top-level
#     {"answers":{...},"usage":{input_tokens,output_tokens}}, the local
#     backend's shape — that top-level value falls back into every question.
#   <answer field> is per question type on the real wire — hosted and local
#   both answer under "choice", "noul" (which carries NO confidence field —
#   protocol-correct), or "score"; "answer" is the idealized shape. The
#   normalized "answer" aliases all four: first present of
#   answer|choice|noul|score (jq // chain — 0 and 0.0 are answers, not nulls).
#   Normalized stdout: one JSON object mapping each requested question id to
#   {answer (the alias above), confidence (null when the response carries
#   none), probabilities, usage (total tokens, number), latency_ms (response
#   value, else client-measured elapsed ms)}.
#
# Exit codes:
#   0  — usable answer: HTTP 200, parseable, every requested question
#        answered (under any answer alias), and every answer that carries a
#        confidence has it >= JUDGMENT_MIN_CONFIDENCE. Confidence is optional
#        per protocol: a confidence-less answer (noul) passes the gate — its
#        probability IS the signal and consumers threshold it themselves.
#   2  — usage error (missing --questions, unreadable state, no state, live
#        hosted call without JUDGMENT_MODEL, invalid JUDGMENT_BACKEND value,
#        unknown flag).
#   10 — fallback, covering exactly: credentials unset/empty (no network
#        call), network failure, HTTP 401/422/429/529 after at most 2
#        exponential-backoff retries (3 total attempts), other non-retryable
#        error statuses, daily cap exceeded (no network call), unparsable or
#        incomplete response (a requested id missing, answered under none of
#        the answer aliases, or carrying a non-numeric confidence), or
#        confidence below the threshold on an answer that carries one (the
#        parsed answer is still printed on stdout so consumers can record
#        telemetry). Every exit 10 writes one `typed-judgment: reason=<...>`
#        line to stderr: unconfigured (credentials), unreachable (transport/
#        HTTP), error (cap, unparsable, low confidence). Consumers must
#        preserve their stock procedure on 10.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
# shellcheck source=judgment-lib.sh
source "$SCRIPT_DIR/judgment-lib.sh"

MIN_CONFIDENCE_DEFAULT="0.6"
RETRYABLE_STATUSES="401 422 429 529"
MAX_ATTEMPTS=3

# Local-backend default model alias, used when JUDGMENT_BACKEND=local and
# JUDGMENT_MODEL is unset (spec 029, OQ-029-03 resolution). The alias is the
# winning backend's default model name recorded in the spec 029 spike report
# (35-spike-report.md §Serving recipe; archived to
# docs/changes/029-local-judgment-backend.md).
DEFAULT_LOCAL_MODEL="kev-latest"

usage_error() { echo "typed-judgment: $*" >&2; exit 2; }

log_debug() {
  # Diagnostic line to stderr — only when JUDGMENT_DEBUG is set. Never pass
  # the API key or an untruncated state payload through here.
  if [ -n "${JUDGMENT_DEBUG:-}" ]; then
    printf 'typed-judgment[debug]: %s\n' "$1" >&2
  fi
}

validate_positive_int() { # $1 = value, $2 = label
  judgment_positive_int "$1" || usage_error "$2 must be a positive integer, got: '$1'"
}

resolve_max_state_bytes() {
  if [ "$MAX_STATE_BYTES_SET" = true ]; then
    validate_positive_int "$MAX_STATE_BYTES" "--max-state-bytes"
  else
    MAX_STATE_BYTES="${JUDGMENT_MAX_STATE_BYTES:-$JUDGMENT_CAP_DEFAULT_BYTES}"
    validate_positive_int "$MAX_STATE_BYTES" "JUDGMENT_MAX_STATE_BYTES"
  fi
}

parse_args() {
  STATE_FILE=""
  QUESTIONS=""
  DRY_RUN=false
  MAX_STATE_BYTES=""
  MAX_STATE_BYTES_SET=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=true; shift ;;
      --state-file|--questions|--max-state-bytes) assign_option "$@"; shift 2 ;;
      *) usage_error "unknown argument: $1" ;;
    esac
  done
  resolve_max_state_bytes
  validate_questions
}

# assign_option <flag> <value> — every value-taking flag passes the same
# "flag needs <noun>" presence check; storing it is a lookup. The caller shifts
# the pair only after this returns, so a missing value exits 2 first.
assign_option() {
  [ "$#" -ge 2 ] || usage_error "$1 needs $(option_noun "$1")"
  case "$1" in
    --state-file) STATE_FILE="$2" ;;
    --questions) QUESTIONS="$2" ;;
    --max-state-bytes) MAX_STATE_BYTES="$2"; MAX_STATE_BYTES_SET=true ;;
  esac
}

# option_noun <flag> — the noun each value-taking flag's usage message names.
option_noun() {
  case "$1" in
    --state-file) printf '%s' 'a path' ;;
    --questions) printf '%s' 'JSON' ;;
    --max-state-bytes) printf '%s' 'a positive integer' ;;
  esac
}

validate_questions() {
  [ -n "$QUESTIONS" ] || usage_error "--questions <json> is required"
  jq -e . >/dev/null 2>&1 <<< "$QUESTIONS" || usage_error "--questions is not valid JSON"
}

load_state() {
  if [ -n "$STATE_FILE" ]; then
    [ -r "$STATE_FILE" ] || usage_error "cannot read state file: $STATE_FILE"
    STATE="$(cat "$STATE_FILE")"
  else
    STATE="$(cat)"
  fi
  [ -n "$STATE" ] || usage_error "empty state payload (use --state-file or pipe stdin)"
  log_debug "state excerpt: ${STATE:0:200}"
}

truncation_marker() { # $1 = omitted byte count
  printf '...[truncated: %s bytes omitted]...' "$1"
}

# converge_omitted <total bytes> — the marker names the omitted byte count, and
# the marker's own length feeds back into that count. A few iterations converge
# deterministically. Echoes "<omitted> <marker-bytes>".
converge_omitted() {
  local omitted=$(( $1 - MAX_STATE_BYTES )) marker mlen new_omitted i
  for i in 1 2 3 4; do
    marker="$(truncation_marker "$omitted")"
    mlen="$(judgment_byte_len "$marker")"
    new_omitted=$(( $1 - (MAX_STATE_BYTES - mlen) ))
    [ "$new_omitted" = "$omitted" ] && break
    omitted="$new_omitted"
  done
  printf '%s %s\n' "$omitted" "$mlen"
}

# apply_truncation <state> <omitted> <marker-bytes> — HEAD + MARKER + TAIL,
# never longer than the cap. Both slices are captured separately because each
# one strips its own trailing newlines, exactly as the pre-refactor single-line
# assignment did; emitting them as three printfs would keep those newlines.
apply_truncation() {
  local keep head_bytes tail_bytes head tail marker
  if [ "$3" -ge "$MAX_STATE_BYTES" ]; then
    # Degenerate cap: the marker alone does not fit. Keep a head slice only.
    printf '%s' "$1" | head -c "$MAX_STATE_BYTES"
    return 0
  fi
  keep=$(( MAX_STATE_BYTES - $3 ))
  head_bytes=$(( keep / 2 ))
  tail_bytes=$(( keep - head_bytes ))
  head="$(printf '%s' "$1" | head -c "$head_bytes")"
  tail="$(printf '%s' "$1" | tail -c "$tail_bytes")"
  marker="$(truncation_marker "$2")"
  printf '%s' "${head}${marker}${tail}"
}

# truncate_state — cap the serialized state deterministically before the
# request is built (spec 034). HEAD + MARKER + TAIL preserves both ends and
# names the omitted byte count; the result is never longer than the cap.
# Emits the payload_overflow reason line and continues (not an exit-10
# fallback: the truncated payload can still produce a usable answer).
truncate_state() {
  local total omitted mlen
  total="$(judgment_byte_len "$STATE")"
  [ "$total" -gt "$MAX_STATE_BYTES" ] || return 0
  read -r omitted mlen <<< "$(converge_omitted "$total")"
  STATE="$(apply_truncation "$STATE" "$omitted" "$mlen")"
  judgment_emit_reason payload_overflow
  printf 'typed-judgment: truncated original_bytes=%s cap_bytes=%s\n' "$total" "$MAX_STATE_BYTES" >&2
}

resolve_backend() {
  # spec 029 Task 2: unset or empty -> hosted (byte-identical 028 behavior);
  # local -> key-less, model-less local serving allowed; anything else -> 2.
  BACKEND="${JUDGMENT_BACKEND:-hosted}"
  case "$BACKEND" in
    local|hosted) ;;
    *) usage_error "JUDGMENT_BACKEND must be 'local' or 'hosted', got: $BACKEND" ;;
  esac
}

resolve_model() {
  if [ -n "${JUDGMENT_MODEL:-}" ]; then printf '%s' "$JUDGMENT_MODEL"
  elif [ "$BACKEND" = "local" ]; then printf '%s' "$DEFAULT_LOCAL_MODEL"
  else printf ''; fi
}

build_request() {
  local model; model="$(resolve_model)"
  if jq -e . >/dev/null 2>&1 <<< "$STATE"; then
    jq -n --arg model "$model" --argjson questions "$QUESTIONS" --argjson state "$STATE" \
      '{model: $model, state: $state, questions: $questions}'
  else
    jq -n --arg model "$model" --argjson questions "$QUESTIONS" --arg state "$STATE" \
      '{model: $model, state: $state, questions: $questions}'
  fi
}

configured_credentials() {
  # hosted: URL and key both required (spec 028). local: URL required, key
  # optional (the winner serves open by default; spec 029 Task 2).
  case "$BACKEND" in
    local) [ -n "${JUDGMENT_API_URL:-}" ] ;;
    *)     [ -n "${JUDGMENT_API_KEY:-}" ] && [ -n "${JUDGMENT_API_URL:-}" ] ;;
  esac
}

counter_file() {
  local dir="${JUDGMENT_CAP_DIR:-$REPO_ROOT/.cache}"
  printf '%s/judgment-cap-%s\n' "$dir" "$(date +%F)"
}

read_counter() { # today's counter value; 0 when the file does not exist yet
  cat "$(counter_file)" 2>/dev/null || echo 0
}

cap_reached() {
  # Fallback when a configured cap is already met. No cap set -> never reached.
  [ -z "${JUDGMENT_DAILY_CAP:-}" ] && return 1
  local count
  count="$(read_counter)"
  [ "$count" -ge "$JUDGMENT_DAILY_CAP" ]
}

cap_increment() {
  [ -z "${JUDGMENT_DAILY_CAP:-}" ] && return 0
  local f
  f="$(counter_file)"
  mkdir -p "$(dirname "$f")"
  printf '%s\n' "$(( $(read_counter) + 1 ))" > "$f"
}

backoff_delay() { # $1 = 1-based retry index
  local -a delays
  read -ra delays <<< "${JUDGMENT_BACKOFF_SECONDS:-1 2}"
  local i=$(( $1 - 1 ))
  [ "$i" -lt "${#delays[@]}" ] || i=$(( ${#delays[@]} - 1 ))
  printf '%s' "${delays[$i]}"
}

retryable_status() {
  case " $RETRYABLE_STATUSES " in *" $1 "*) return 0 ;; esac
  return 1
}

# api_attempt — one POST; sets HTTP_STATUS (from curl -w) and CURL_RC. The
# Authorization header is sent whenever a key is set (hosted always has one —
# configured_credentials gated it; spec 028 order preserved byte-for-byte);
# local mode with no key sends no auth header at all.
api_attempt() {
  CURL_RC=0
  local -a auth=()
  [ -n "${JUDGMENT_API_KEY:-}" ] && auth=(-H "Authorization: Bearer ${JUDGMENT_API_KEY}")
  # ${auth[@]+"${auth[@]}"}: bash 3.2 + `set -u` rejects an empty array expansion.
  HTTP_STATUS="$(curl -sS --max-time "${JUDGMENT_TIMEOUT_SECONDS:-30}" \
    -o "$RESP_FILE" -w '%{http_code}' \
    -X POST \
    -H 'Content-Type: application/json' \
    ${auth[@]+"${auth[@]}"} \
    --data-binary "@$REQ_FILE" \
    "$JUDGMENT_API_URL")" || CURL_RC=$?
  [ "$CURL_RC" -eq 0 ]
}

# call_api — up to MAX_ATTEMPTS attempts with exponential backoff on network
# failure or retryable statuses. Returns 0 on HTTP 200, 1 otherwise.
call_api() {
  local attempt=1
  while :; do
    log_debug "attempt $attempt/$MAX_ATTEMPTS"
    if api_attempt; then
      [ "$HTTP_STATUS" = "200" ] && return 0
      retryable_status "$HTTP_STATUS" || { log_debug "non-retryable HTTP $HTTP_STATUS"; return 1; }
    else
      log_debug "transport failure (curl exit $CURL_RC)"
    fi
    [ "$attempt" -ge "$MAX_ATTEMPTS" ] && return 1
    sleep "$(backoff_delay "$attempt")"
    attempt=$((attempt + 1))
  done
}

# response_valid — HTTP 200 body is JSON where every requested question id is
# answered under one of the wire aliases (answer|choice|noul|score), and any
# confidence that is present is numeric. Confidence itself is optional per
# protocol — noul answers carry none (spec 029 spike §Wire compatibility).
response_valid() {
  jq -e --argjson q "$QUESTIONS" '
    (.answers // {}) as $a |
    [ $q | keys[] | ($a[.] // empty)
      | select(((.answer // .choice // .noul // .score) != null)
          and (.confidence == null or (.confidence | type) == "number"))
    ]
    | length == ($q | keys | length) and length > 0
  ' "$RESP_FILE" >/dev/null 2>&1
}

normalize_output() { # $1 = client-measured elapsed ms (latency fallback)
  # usage: per-answer value wins; when the response carries usage only at the
  # top level ({"answers":{...},"usage":{input_tokens,output_tokens}} — the
  # local backend's shape) that value falls back into every question; with
  # neither, usage stays 0 (hosted shape without top-level usage is unchanged).
  jq -e --argjson q "$QUESTIONS" --argjson lat "$1" '
    (.answers // {}) as $a |
    (.usage // null) as $top_usage |
    reduce ($q | keys[]) as $k ({}; .[$k] = {
      answer: ($a[$k].answer // $a[$k].choice // $a[$k].noul // $a[$k].score // null),
      confidence: ($a[$k].confidence // null),
      probabilities: ($a[$k].probabilities // {}),
      usage: ($a[$k].usage // $top_usage // 0 |
        if type == "object" then (.total_tokens // ((.input_tokens // 0) + (.output_tokens // 0)))
        elif type == "number" then . else 0 end),
      latency_ms: ($a[$k].latency_ms // $lat)
    })
  ' "$RESP_FILE"
}

confidence_usable() { # $1 = normalized JSON — gates only answers that carry a
  # confidence; confidence-less ones (noul) pass, empty selection -> all() true.
  local min="${JUDGMENT_MIN_CONFIDENCE:-$MIN_CONFIDENCE_DEFAULT}"
  jq -e --argjson min "$min" '[ .[].confidence | select(. != null) ] | all(. >= $min)' <<< "$1" >/dev/null 2>&1
}

fallback() { # $1 = reason word, $2 = human-readable detail (debug only)
  log_debug "${2:-$1} — fallback"
  judgment_emit_reason "$1"
  exit 10
}

check_callable() { # guards before any HTTP: credentials, model, daily cap
  configured_credentials || fallback unconfigured "not configured (JUDGMENT_API_URL/JUDGMENT_API_KEY)"
  # hosted keeps spec 028's strict model requirement; local falls back to the
  # DEFAULT_LOCAL_MODEL alias (resolved in build_request) instead of erroring.
  if [ "$BACKEND" != "local" ]; then
    [ -n "${JUDGMENT_MODEL:-}" ] || usage_error "JUDGMENT_MODEL is required for a live call"
  fi
  cap_reached && fallback error "daily cap reached"
  return 0
}

finalize_response() { # $1 = client-measured elapsed ms; prints answer, exits 0/10
  response_valid || fallback error "response unparsable or incomplete"
  local normalized
  normalized="$(normalize_output "$1")"
  printf '%s\n' "$normalized"
  confidence_usable "$normalized" || fallback error "confidence below threshold"
  exit 0
}

# write_request_file — temp files for the request/response and the built body.
# The EXIT trap is what removes them, so it is installed before anything can
# fail on the way to a response.
write_request_file() {
  REQ_FILE="$(mktemp)"
  RESP_FILE="$(mktemp)"
  trap 'rm -f "$REQ_FILE" "$RESP_FILE"' EXIT
  build_request > "$REQ_FILE"
}

# live_call — everything from the pre-HTTP guards to the final answer; exits
# 0 (usable answer) or 10 (fallback).
live_call() {
  check_callable
  local start_ms elapsed_ms
  start_ms="$(date +%s%3N)"
  call_api || fallback unreachable "API call failed (HTTP ${HTTP_STATUS:-none})"
  cap_increment
  elapsed_ms=$(( $(date +%s%3N) - start_ms ))
  # Wall-clock delta can go negative if the clock steps (NTP) mid-call; latency
  # is never negative, so clamp.
  (( elapsed_ms < 0 )) && elapsed_ms=0
  finalize_response "$elapsed_ms"
}

main() {
  resolve_backend
  parse_args "$@"
  load_state
  truncate_state
  write_request_file
  if [ "$DRY_RUN" = true ]; then
    cat "$REQ_FILE"
    exit 0
  fi
  live_call
}

main "$@"
