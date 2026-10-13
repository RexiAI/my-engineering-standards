#!/usr/bin/env bash
# typed-judgment.sh — curl+jq wrapper that sends a state payload plus typed
# questions to a judgment API and prints normalized per-question answers
# (spec 028; see docs/SPEC_PIPELINE.md §Typed-judgment layer, ADR 0004).
#
# Usage:
#   scripts/typed-judgment.sh --questions <json>
#       [--state-file <path>] [--dry-run]
#
# Input:
#   --state-file <path>  State payload source. Without it, the state payload
#                        is read from stdin. A payload that parses as JSON is
#                        embedded as a JSON value; anything else as a string.
#   --questions <json>   Map of question id -> {type, instructions, criteria}.
#                        Passed through verbatim in the request body.
#
# Environment:
#   JUDGMENT_API_URL            Judgment API endpoint. Unset/empty -> fallback.
#   JUDGMENT_API_KEY            Bearer token. Unset/empty -> fallback. Never
#                               printed in stdout, stderr, or any log output.
#   JUDGMENT_MODEL              Model id. Required for a live call.
#   JUDGMENT_MIN_CONFIDENCE     Usability threshold, default 0.6.
#   JUDGMENT_DAILY_CAP          Max calls per day. Unset -> no cap enforced
#                               and no counter written.
#   JUDGMENT_CAP_DIR            Directory for the daily counter file.
#                               Default: <repo root>/.cache — gitignored.
#   JUDGMENT_BACKOFF_SECONDS    Retry delays, default "1 2". Setting it to
#                               "0" (offline tests) removes the sleep.
#   JUDGMENT_TIMEOUT_SECONDS    Per-attempt curl timeout, default 30.
#   JUDGMENT_DEBUG              Non-empty -> diagnostic lines on stderr.
#                               State payloads in diagnostics are truncated.
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
#   {"answers": {"<question-id>": {"answer": ..., "confidence": <0..1>,
#     "probabilities": {...}?, "usage": <tokens | {total_tokens} | {input,
#     output}>?, "latency_ms": <ms>?}, ...}}
#   Normalized stdout: one JSON object mapping each requested question id to
#   {answer, confidence, probabilities, usage (total tokens, number),
#   latency_ms (response value, else client-measured elapsed ms)}.
#
# Exit codes:
#   0  — usable answer: HTTP 200, parseable, every question answered, and
#        every confidence >= JUDGMENT_MIN_CONFIDENCE.
#   2  — usage error (missing --questions, unreadable state, no state, live
#        call without JUDGMENT_MODEL, unknown flag).
#   10 — fallback, covering exactly: credentials unset/empty (no network
#        call), network failure, HTTP 401/422/429/529 after at most 2
#        exponential-backoff retries (3 total attempts), other non-retryable
#        error statuses, daily cap exceeded (no network call), unparsable or
#        incomplete response, or confidence below the threshold (the parsed
#        answer is still printed on stdout so consumers can record
#        telemetry). Consumers must preserve their stock procedure on 10.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

MIN_CONFIDENCE_DEFAULT="0.6"
RETRYABLE_STATUSES="401 422 429 529"
MAX_ATTEMPTS=3

usage_error() { echo "typed-judgment: $*" >&2; exit 2; }

log_debug() {
  # Diagnostic line to stderr — only when JUDGMENT_DEBUG is set. Never pass
  # the API key or an untruncated state payload through here.
  if [ -n "${JUDGMENT_DEBUG:-}" ]; then
    printf 'typed-judgment[debug]: %s\n' "$1" >&2
  fi
}

need_value() { # $1 = argc, $2 = flag, $3 = noun completing "<flag> needs <noun>"
  [ "$1" -ge 2 ] || usage_error "$2 needs $3"
}

parse_args() {
  STATE_FILE=""
  QUESTIONS=""
  DRY_RUN=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --state-file) need_value "$#" "$1" "a path"; STATE_FILE="$2"; shift 2 ;;
      --questions)  need_value "$#" "$1" "JSON";   QUESTIONS="$2"; shift 2 ;;
      --dry-run)    DRY_RUN=true; shift ;;
      *) usage_error "unknown argument: $1" ;;
    esac
  done
  validate_questions
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

build_request() {
  local model="${JUDGMENT_MODEL:-}"
  if jq -e . >/dev/null 2>&1 <<< "$STATE"; then
    jq -n --arg model "$model" --argjson questions "$QUESTIONS" --argjson state "$STATE" \
      '{model: $model, state: $state, questions: $questions}'
  else
    jq -n --arg model "$model" --argjson questions "$QUESTIONS" --arg state "$STATE" \
      '{model: $model, state: $state, questions: $questions}'
  fi
}

configured_credentials() {
  [ -n "${JUDGMENT_API_KEY:-}" ] && [ -n "${JUDGMENT_API_URL:-}" ]
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

# api_attempt — one POST; sets HTTP_STATUS (from curl -w) and CURL_RC.
api_attempt() {
  CURL_RC=0
  HTTP_STATUS="$(curl -sS --max-time "${JUDGMENT_TIMEOUT_SECONDS:-30}" \
    -o "$RESP_FILE" -w '%{http_code}' \
    -X POST \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${JUDGMENT_API_KEY}" \
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

# response_valid — HTTP 200 body is JSON with a numeric confidence for every
# requested question id.
response_valid() {
  jq -e --argjson q "$QUESTIONS" '
    (.answers // {}) as $a |
    [ $q | keys[] | ($a[.] // empty) | (.confidence | type) == "number" ]
    | length == ($q | keys | length) and length > 0
  ' "$RESP_FILE" >/dev/null 2>&1
}

normalize_output() { # $1 = client-measured elapsed ms (latency fallback)
  jq -e --argjson q "$QUESTIONS" --argjson lat "$1" '
    (.answers // {}) as $a |
    reduce ($q | keys[]) as $k ({}; .[$k] = {
      answer: ($a[$k].answer // null),
      confidence: ($a[$k].confidence // null),
      probabilities: ($a[$k].probabilities // {}),
      usage: ($a[$k].usage // 0 |
        if type == "object" then (.total_tokens // ((.input_tokens // 0) + (.output_tokens // 0)))
        elif type == "number" then . else 0 end),
      latency_ms: ($a[$k].latency_ms // $lat)
    })
  ' "$RESP_FILE"
}

confidence_usable() { # $1 = normalized JSON
  local min="${JUDGMENT_MIN_CONFIDENCE:-$MIN_CONFIDENCE_DEFAULT}"
  jq -e --argjson min "$min" '[ .[].confidence ] | all(. >= $min)' <<< "$1" >/dev/null 2>&1
}

fallback() { # $1 = reason — debug line then the documented exit 10
  log_debug "$1 — fallback"
  exit 10
}

check_callable() { # guards before any HTTP: credentials, model, daily cap
  configured_credentials || fallback "not configured (JUDGMENT_API_URL/JUDGMENT_API_KEY)"
  [ -n "${JUDGMENT_MODEL:-}" ] || usage_error "JUDGMENT_MODEL is required for a live call"
  cap_reached && fallback "daily cap reached"
  return 0
}

finalize_response() { # $1 = client-measured elapsed ms; prints answer, exits 0/10
  response_valid || fallback "response unparsable or incomplete"
  local normalized
  normalized="$(normalize_output "$1")"
  printf '%s\n' "$normalized"
  confidence_usable "$normalized" || fallback "confidence below threshold"
  exit 0
}

main() {
  parse_args "$@"
  load_state
  REQ_FILE="$(mktemp)"
  RESP_FILE="$(mktemp)"
  trap 'rm -f "$REQ_FILE" "$RESP_FILE"' EXIT
  build_request > "$REQ_FILE"
  if [ "$DRY_RUN" = true ]; then
    cat "$REQ_FILE"
    exit 0
  fi
  check_callable
  local start_ms elapsed_ms
  start_ms="$(date +%s%3N)"
  call_api || fallback "API call failed (HTTP ${HTTP_STATUS:-none})"
  cap_increment
  elapsed_ms=$(( $(date +%s%3N) - start_ms ))
  finalize_response "$elapsed_ms"
}

main "$@"
