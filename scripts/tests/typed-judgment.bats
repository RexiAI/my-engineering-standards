#!/usr/bin/env bats
# typed-judgment.bats — acceptance tests for scripts/typed-judgment.sh (spec 028).
# Covers AC-028-01 … AC-028-20 plus unit tests for paths the scenarios imply
# but do not spell out. All tests run offline: a fake curl stub on PATH is the
# only transport (AC-028-56); no real HTTP request is ever made. The stub
# reads a per-attempt sequence file of "<curl-exit>\t<http-code>\t<body-file>"
# lines (last line repeats) and records attempts/argv/request-bodies under
# $TMPDIR_HELPER for assertions.

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  BIN="$TMPDIR_HELPER/bin"
  FIX="$TMPDIR_HELPER/fixtures"
  mkdir -p "$BIN" "$FIX" "$TMPDIR_HELPER/cache"

  # fake curl stub — the injected mock transport
  cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
# fake curl stub: never touches the network
attempts="${MOCK_CURL_ATTEMPTS:?}"
mkdir -p "$(dirname "$attempts")"
printf 'attempt\n' >> "$attempts"
n=$(grep -c . "$attempts")
out=""
body_src=""
args=("$@")
i=0
while [ "$i" -lt "${#args[@]}" ]; do
  case "${args[$i]}" in
    -o) out="${args[$((i+1))]}"; i=$((i+2)) ;;
    --data-binary) body_src="${args[$((i+1))]}"; i=$((i+2)) ;;
    *) i=$((i+1)) ;;
  esac
done
if [ -n "$body_src" ]; then
  bodies="${MOCK_CURL_BODIES:?}"
  mkdir -p "$(dirname "$bodies")"
  { echo "--- request $n";
    case "$body_src" in @*) cat "${body_src#@}" ;; *) printf '%s' "$body_src" ;; esac
    echo; } >> "$bodies"
fi
seq_file="${MOCK_CURL_SEQUENCE:?}"
line=$(sed -n "${n}p" "$seq_file")
[ -z "$line" ] && line=$(tail -n 1 "$seq_file")
IFS=$'\t' read -r cexit code bodyfile <<< "$line"
[ "$cexit" != "0" ] && exit "$cexit"
[ -n "$out" ] && cat "$bodyfile" > "$out"
printf '%s' "$code"
STUB
  chmod +x "$BIN/curl"

  # fixtures: API-shaped responses
  cat > "$FIX/ok.json" <<'JSON'
{"answers":{"classification":{"answer":"regression","confidence":0.85,
"probabilities":{"flake":0.05,"regression":0.85,"infra":0.05,"config":0.05},
"usage":{"input_tokens":100,"output_tokens":23},"latency_ms":42}}}
JSON
  cat > "$FIX/low.json" <<'JSON'
{"answers":{"classification":{"answer":"flake","confidence":0.55,
"probabilities":{"flake":0.55,"regression":0.2,"infra":0.15,"config":0.1},
"usage":{"total_tokens":90},"latency_ms":30}}}
JSON
  cat > "$FIX/exact.json" <<'JSON'
{"answers":{"classification":{"answer":"config","confidence":0.6,
"probabilities":{"config":0.6},"usage":{"total_tokens":80},"latency_ms":25}}}
JSON
  cat > "$FIX/empty.json" <<'JSON'
{}
JSON
  printf 'this is not json\n' > "$FIX/garbage.json"

  export ATTEMPTS="$TMPDIR_HELPER/attempts"
  export BODIES="$TMPDIR_HELPER/bodies"
  export SEQUENCE="$TMPDIR_HELPER/sequence"
  export MOCK_CURL_ATTEMPTS="$ATTEMPTS"
  export MOCK_CURL_BODIES="$BODIES"
  export MOCK_CURL_SEQUENCE="$SEQUENCE"

  # default configured environment (credentials present, cap unset)
  export JUDGMENT_API_URL="http://judgment.invalid/v1/judge"
  export JUDGMENT_API_KEY="test-key"
  export JUDGMENT_MODEL="fake/model-1"
  export JUDGMENT_CAP_DIR="$TMPDIR_HELPER/cache"
  export JUDGMENT_BACKOFF_SECONDS="0"
  unset JUDGMENT_MIN_CONFIDENCE
  unset JUDGMENT_DAILY_CAP
  unset JUDGMENT_DEBUG

  export PATH="$BIN:$PATH"
  # default: always succeed on first attempt
  seq_ok
}

teardown() { teardown_tmpdir; }

# seq_ok / seq_always <code> <body-fixture-name> / seq_two — sequence helpers
seq_ok() { printf '0\t200\t%s/ok.json\n' "$FIX" > "$SEQUENCE"; }
seq_always() { printf '0\t%s\t%s/%s.json\n' "$1" "$FIX" "$2" > "$SEQUENCE"; }

# counter_file — path of today's per-day counter (documented in script header)
counter_file() { printf '%s/judgment-cap-%s\n' "$JUDGMENT_CAP_DIR" "$(date +%F)"; }

# attempts_count — number of fake-transport invocations (0 if none)
attempts_count() {
  if [ -f "$ATTEMPTS" ]; then grep -c . "$ATTEMPTS"; else echo 0; fi
}

# state_file <content-path> — write a state file, echo its path
make_state() {
  printf '%s' "$1" > "$TMPDIR_HELPER/state.json"
  printf '%s' "$TMPDIR_HELPER/state.json"
}

# invoke [env-assignments-or-u-flags...] -- [script-args...]
# Stdin comes from STDIN_PAYLOAD (default: a plain-text state payload).
invoke() {
  local envargs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envargs+=("$1"); shift; done
  [ "$#" -gt 0 ] && shift
  # write stdin to a file and redirect: a pipeline would run `run` in a
  # subshell and lose $status/$output
  printf '%s' "${STDIN_PAYLOAD:-build failed at step 3}" > "$TMPDIR_HELPER/stdin"
  run --separate-stderr env "${envargs[@]}" bash "$REPO_ROOT/scripts/typed-judgment.sh" "$@" < "$TMPDIR_HELPER/stdin"
}

Q='{"classification":{"type":"choice","instructions":"Classify the failing CI run","criteria":"one of flake/regression/infra/config per the rubrics"}}'

# assert_no_network_fallback <invoke-env-args...> — unconfigured state exits 10
# without ever calling the fake transport.
assert_no_network_fallback() {
  local sf; sf=$(make_state 'build failed at step 3')
  invoke "$@" -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
  [ "$(attempts_count)" -eq 0 ]
}

# assert_retryable_exhausts <http-status> — a retryable status on every attempt
# exits 10 after exactly MAX_ATTEMPTS (3) attempts.
assert_retryable_exhausts() {
  seq_always "$1" empty
  local sf; sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
  [ "$(attempts_count)" -eq 3 ]
}

# assert_200_body_fallback <fixture-name> — HTTP 200 whose body is not a usable
# answer (garbage, incomplete, or below confidence threshold) exits 10.
assert_200_body_fallback() {
  seq_always 200 "$1"
  local sf; sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
}

# ── Acceptance scenarios AC-028-01 … AC-028-20 ───────────────────────────────

@test "AC-028-01: successful API call returns normalized JSON and exits 0" {
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 0 "$status"
  [[ "$output" == *'"answer": "regression"'* || "$output" == *'"answer":"regression"'* ]]
  [[ "$output" == *confidence* ]]
  [[ "$output" == *probabilities* ]]
  [[ "$output" == *usage* ]]
  [[ "$output" == *latency_ms* ]]
  printf '%s' "$output" | jq -e '.classification.confidence == 0.85'
  printf '%s' "$output" | jq -e '.classification.usage == 123'
  printf '%s' "$output" | jq -e '.classification.latency_ms == 42'
}

@test "AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request" {
  assert_no_network_fallback -u JUDGMENT_API_KEY
}

@test "AC-028-03: JUDGMENT_API_URL unset exits 10 without any HTTP request" {
  assert_no_network_fallback -u JUDGMENT_API_URL
}

@test "AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request" {
  assert_no_network_fallback JUDGMENT_API_KEY=
}

@test "AC-028-05: HTTP 401 on every attempt exits 10 after at most 3 attempts" {
  assert_retryable_exhausts 401
}

@test "AC-028-06: HTTP 422 on every attempt exits 10 after at most 3 attempts" {
  assert_retryable_exhausts 422
}

@test "AC-028-07: HTTP 429 on every attempt exits 10 after at most 3 attempts" {
  assert_retryable_exhausts 429
}

@test "AC-028-08: HTTP 529 on every attempt exits 10 after at most 3 attempts" {
  assert_retryable_exhausts 529
}

@test "AC-028-09: HTTP 429 then HTTP 200 succeeds on second attempt with exit 0" {
  printf '0\t429\t%s/empty.json\n0\t200\t%s/ok.json\n' "$FIX" "$FIX" > "$SEQUENCE"
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 0 "$status"
  [ "$(attempts_count)" -eq 2 ]
  [[ "$output" == *regression* ]]
}

@test "AC-028-10: network failure on every attempt exits 10 after at most 3 attempts" {
  printf '7\t0\t%s/empty.json\n' "$FIX" > "$SEQUENCE"
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
  [ "$(attempts_count)" -eq 3 ]
}

@test "AC-028-11: confidence 0.55 below threshold 0.6 exits 10" {
  assert_200_body_fallback low
}

@test "AC-028-12: confidence exactly at threshold 0.6 exits 0" {
  seq_always 200 exact
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 0 "$status"
  printf '%s' "$output" | jq -e '.classification.confidence == 0.6'
}

@test "AC-028-13: daily cap reached exits 10 without any HTTP request" {
  export JUDGMENT_DAILY_CAP=100
  echo 100 > "$(counter_file)"
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
  [ "$(attempts_count)" -eq 0 ]
}

@test "AC-028-14: daily cap not reached proceeds and increments counter to 100" {
  export JUDGMENT_DAILY_CAP=100
  echo 99 > "$(counter_file)"
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 0 "$status"
  [ "$(cat "$(counter_file)")" -eq 100 ]
}

@test "AC-028-15: API key never appears in stdout or stderr on HTTP 401" {
  export JUDGMENT_API_KEY="sk-secret-key-12345"
  seq_always 401 empty
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
  [[ "$output" != *sk-secret-key-12345* ]]
  [[ "$stderr" != *sk-secret-key-12345* ]]
}

@test "AC-028-16: state payload truncated to 200 chars in diagnostic output" {
  export JUDGMENT_DEBUG=1
  seq_always 401 empty
  head200="H$(printf 'h%.0s' $(seq 199))"
  tail100="T$(printf 't%.0s' $(seq 99))"
  sf=$(make_state "${head200}${tail100}")
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 10 "$status"
  [[ "$stderr" == *"$head200"* ]]
  [[ "$stderr" != *"$tail100"* ]]
}

@test "AC-028-17: state payload read from file via --state-file reaches request body" {
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 0 "$status"
  grep -q 'build failed at step 3' "$BODIES"
}

@test "AC-028-18: state payload read from stdin reaches request body" {
  STDIN_PAYLOAD='build failed'
  export STDIN_PAYLOAD
  invoke -- --questions "$Q"
  assert_exit_code 0 "$status"
  grep -q 'build failed' "$BODIES"
}

@test "AC-028-19: --dry-run prints request body, exits 0, makes no HTTP request" {
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q" --dry-run
  assert_exit_code 0 "$status"
  [ "$(attempts_count)" -eq 0 ]
  printf '%s' "$output" | jq -e '.model == "fake/model-1"'
  printf '%s' "$output" | jq -e '.questions.classification.type == "choice"'
  printf '%s' "$output" | jq -e '.state == "build failed at step 3"'
}

@test "AC-028-20: default minimum confidence is 0.6 when JUDGMENT_MIN_CONFIDENCE unset" {
  assert_200_body_fallback low
}

# ── Unit tests: paths the scenarios imply but do not spell out ────────────────

@test "unit: HTTP 200 with unparseable JSON body exits 10 (fallback, not crash)" {
  assert_200_body_fallback garbage
}

@test "unit: response missing answers for a requested question id exits 10" {
  assert_200_body_fallback empty
}

@test "unit: low-confidence exit 10 still prints the normalized answer (telemetry)" {
  assert_200_body_fallback low
  printf '%s' "$output" | jq -e '.classification.confidence == 0.55'
}

@test "unit: missing --questions is a usage error exiting 2" {
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf"
  assert_exit_code 2 "$status"
}

@test "unit: JSON state payload is embedded as JSON (not stringified)" {
  sf=$(make_state '{"failed_log_excerpt":"boom","changed_files":["a.sh"]}')
  invoke -- --state-file "$sf" --questions "$Q" --dry-run
  assert_exit_code 0 "$status"
  printf '%s' "$output" | jq -e '.state.failed_log_excerpt == "boom"'
}

@test "unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2" {
  sf=$(make_state 'build failed at step 3')
  invoke -u JUDGMENT_MODEL -- --state-file "$sf" --questions "$Q"
  assert_exit_code 2 "$status"
  [ "$(attempts_count)" -eq 0 ]
}

@test "unit: successful HTTP 200 increments the daily counter even above the cap check" {
  export JUDGMENT_DAILY_CAP=5
  sf=$(make_state 'build failed at step 3')
  invoke -- --state-file "$sf" --questions "$Q"
  assert_exit_code 0 "$status"
  [ "$(cat "$(counter_file)")" -eq 1 ]
}
