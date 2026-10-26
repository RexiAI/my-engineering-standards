#!/usr/bin/env bats
# judgment-preflight.bats — acceptance tests for spec 034 tasks 3–10:
# the fail-open preflight (AC-034-12…16), the consumer/wiring content contracts
# (AC-034-17…25), the judgment-status operator surface (AC-034-26…28), the docs
# and ADR contracts (AC-034-29…31), the static no-BLOCK assertion (AC-034-32),
# and the offline-hermeticity invariant (AC-034-33).
#
# All tests run offline. The only transport is the fake curl stub below, which
# stands in for the judgment HTTP API; no test needs the live local backend.

load test_helper
bats_require_minimum_version 1.5.0

PREFLIGHT="$REPO_ROOT/scripts/judgment-preflight.sh"
STATUS="$REPO_ROOT/scripts/judgment-status.sh"
PIPE_AGENT="$REPO_ROOT/agents/spec-pipeline.md"
SPEC_UX="$REPO_ROOT/agents/spec-ux.md"
CI_TRIAGE="$REPO_ROOT/skills/ci-triage/SKILL.md"
PIPE_DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"
ADR_INDEX="$REPO_ROOT/docs/adr/README.md"
ADR_034="$REPO_ROOT/docs/adr/0012-judgment-consumer-contract-fail-open-preflight.md"

setup() {
  setup_tmpdir
  BIN="$TMPDIR_HELPER/bin"
  FIX="$TMPDIR_HELPER/fixtures"
  mkdir -p "$BIN" "$FIX" "$TMPDIR_HELPER/cache" "$TMPDIR_HELPER/run"

  # fake curl stub — the injected mock transport (never touches the network)
  cat > "$BIN/curl" <<'STUB'
#!/usr/bin/env bash
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

  # A usable answer to the synthetic "fitness" choice question.
  cat > "$FIX/healthy.json" <<'JSON'
{"answers":{"fitness":{"choice":"yes","confidence":0.9,
"probabilities":{"yes":0.9,"no":0.1}}},"usage":{"total_tokens":6},"latency_ms":4}
JSON

  export ATTEMPTS="$TMPDIR_HELPER/attempts"
  export BODIES="$TMPDIR_HELPER/bodies"
  export SEQUENCE="$TMPDIR_HELPER/sequence"
  export MOCK_CURL_ATTEMPTS="$ATTEMPTS"
  export MOCK_CURL_BODIES="$BODIES"
  export MOCK_CURL_SEQUENCE="$SEQUENCE"

  export JUDGMENT_BACKEND=local
  export JUDGMENT_API_URL="http://judgment.invalid/v1/judge"
  export JUDGMENT_CAP_DIR="$TMPDIR_HELPER/cache"
  export JUDGMENT_LOCAL_RUN_DIR="$TMPDIR_HELPER/run"
  export JUDGMENT_LOCAL_PORT=18009
  export PATH="$BIN:$PATH"
  unset JUDGMENT_API_KEY JUDGMENT_MODEL JUDGMENT_DEBUG JUDGMENT_REQUIRED \
        JUDGMENT_MAX_STATE_BYTES JUDGMENT_PREFLIGHT_TTL_SECONDS \
        JUDGMENT_TIMEOUT_SECONDS JUDGMENT_BACKOFF_SECONDS

  seq_ok
}

teardown() { teardown_tmpdir; }

seq_ok() { printf '0\t200\t%s/healthy.json\n' "$FIX" > "$SEQUENCE"; }
seq_dead() { printf '7\t0\t%s/healthy.json\n' "$FIX" > "$SEQUENCE"; }

attempts_count() {
  if [ -f "$ATTEMPTS" ]; then grep -c . "$ATTEMPTS"; else echo 0; fi
}

# run_preflight [ENV=VAL...] -- [flags...]
run_preflight() {
  local envargs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do envargs+=("$1"); shift; done
  [ "$#" -gt 0 ] && shift
  run --separate-stderr env "${envargs[@]}" bash "$PREFLIGHT" "$@"
}

# run_status — invoke the operator surface with the current fixture env
run_status() {
  run --separate-stderr env bash "$STATUS"
}

nonempty_lines() { printf '%s\n' "$1" | grep -c . || true; }

grep_file() {
  local file="$1"; shift
  local pat
  for pat in "$@"; do
    grep -qE -- "$pat" "$file" || { echo "missing pattern: $pat (in $file)" >&2; return 1; }
  done
}

# pid_file <pid> — register a tracked local-backend PID (liveness signal)
pid_file() {
  mkdir -p "$JUDGMENT_LOCAL_RUN_DIR"
  printf '%s\n' "$1" > "$JUDGMENT_LOCAL_RUN_DIR/kev.pid"
}

# ── Task 3: fail-open preflight ──────────────────────────────────────────────

@test "AC-034-12: healthy local backend is recorded, exit 0, one probe request" {
  run_preflight -- --force
  assert_exit_code 0 "$status"
  [ "$(nonempty_lines "$output")" -eq 1 ]
  [[ "$output" == *healthy* ]]
  [ "$(attempts_count)" -eq 1 ]
  grep -q ' healthy' "$JUDGMENT_CAP_DIR/judgment-preflight"
}

@test "AC-034-13: backend down prints exactly one warning and exits 0" {
  seq_dead
  run_preflight -- --force
  assert_exit_code 0 "$status"
  [ "$(nonempty_lines "$stderr")" -eq 1 ]
  [[ "$stderr" == *"make judgment-up"* ]]
  [[ "$stderr" == *"continuing without"* ]]
  [[ "$stderr" == *unreachable* ]]
  [ "$(attempts_count)" -eq 3 ]
}

@test "AC-034-14: unset backend or hosted-unconfigured is silent" {
  run_preflight -u JUDGMENT_BACKEND -u JUDGMENT_API_URL -- --force
  assert_exit_code 0 "$status"
  [ -z "$output" ]
  [ -z "$stderr" ]
  [ "$(attempts_count)" -eq 0 ]

  run_preflight -u JUDGMENT_API_URL JUDGMENT_BACKEND=hosted -- --force
  assert_exit_code 0 "$status"
  [ -z "$output" ]
  [ -z "$stderr" ]
  [ "$(attempts_count)" -eq 0 ]
}

@test "AC-034-15: --require-judgment or JUDGMENT_REQUIRED=1 turns a failed probe hard" {
  seq_dead
  run_preflight -- --force --require-judgment
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"make judgment-up"* ]]

  run_preflight JUDGMENT_REQUIRED=1 -- --force
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"make judgment-up"* ]]
}

@test "AC-034-16: probe result is cached; a second run within TTL does not re-probe" {
  run_preflight -- --force
  assert_exit_code 0 "$status"
  [ "$(attempts_count)" -eq 1 ]
  [ -f "$JUDGMENT_CAP_DIR/judgment-preflight" ]

  run_preflight --
  assert_exit_code 0 "$status"
  [[ "$output" == *healthy* ]]
  [ "$(attempts_count)" -eq 1 ]

  # --force ignores the cached outcome and probes again
  run_preflight -- --force
  assert_exit_code 0 "$status"
  [ "$(attempts_count)" -eq 2 ]
}

# ── Task 4: /spec and /build wiring ─────────────────────────────────────────

@test "AC-034-17: spec-pipeline runs the preflight first for /spec" {
  grep_file "$PIPE_AGENT" 'scripts/judgment-preflight\.sh' 'before any delegation' '/spec'
  awk '/judgment preflight|Judgment preflight/{f=1} f{print}' "$PIPE_AGENT" | grep -q '/spec'
}

@test "AC-034-18: spec-pipeline runs the preflight first for /build" {
  grep_file "$PIPE_AGENT" 'scripts/judgment-preflight\.sh' 'before any delegation' '/build'
  awk '/judgment preflight|Judgment preflight/{f=1} f{print}' "$PIPE_AGENT" | grep -q '/build'
}

@test "AC-034-19: a preflight warning never halts stage delegation" {
  grep_file "$PIPE_AGENT" \
    'never block' \
    'continuing without' \
    'JUDGMENT_REQUIRED=1' \
    'non-zero'
  # exit 0 is explicitly the continue path; only a non-zero exit stops the run
  ! grep -qE 'preflight.*(exit 0|warning).*(stop|halt)' "$PIPE_AGENT"
}

# ── Task 5: spec-ux exit-10 contract ────────────────────────────────────────

@test "AC-034-20: exit 10 runs the stock applicability check, never BLOCKED" {
  grep_file "$SPEC_UX" '\*\*exit 10\*\*' 'Applicability check \(first action, always\)'
  local branch
  branch="$(awk '/\*\*exit 10\*\*/{f=1} f{print; n++} n>=8{exit}' "$SPEC_UX")"
  [[ "$branch" == *"Applicability check"* ]]
  [[ "$branch" != *"BLOCKED"* ]]
}

@test "AC-034-21: an ambiguous answer still blocks" {
  grep_file "$SPEC_UX" '"ambiguous"' 'BLOCKED —'
  # BLOCKED is scoped to the ambiguous outcome
  grep -E '"ambiguous"' "$SPEC_UX" | grep -q 'BLOCKED —'
}

@test "AC-034-22: run and skip answers are unchanged" {
  grep_file "$SPEC_UX" '"run"' 'design-taste-frontend'
  grep_file "$SPEC_UX" '"skip"' '^ *`?SKIPPED|SKIPPED —'
}

@test "AC-034-23: spec-ux telemetry records fallback plus a reason and admits truncation" {
  grep_file "$SPEC_UX" \
    '"fallback":<false\|true>|"fallback":true' \
    '"reason"' \
    'unconfigured' 'unreachable' 'payload_overflow' 'error' \
    'truncated' 'original_bytes'
  # the stale "sent untruncated" claim must be gone
  ! grep -qi 'no truncation of the payload itself' "$SPEC_UX"
}

# ── Task 6: ci-triage exit-10 contract ──────────────────────────────────────

@test "AC-034-24: ci-triage exit 10 runs the stock classification unchanged" {
  grep_file "$CI_TRIAGE" '\*\*exit 10\*\*' 'unchanged'
  ! grep -qiE 'exit 10.*(block|escalat)' "$CI_TRIAGE"
}

@test "AC-034-25: ci-triage exit-10 telemetry records a reason" {
  grep_file "$CI_TRIAGE" '"judgment_fallback":true' '"reason"'
  grep -E '"judgment_fallback":true' "$CI_TRIAGE" | grep -q '"reason"'
}

# ── Task 7: judgment-status operator surface ────────────────────────────────

@test "AC-034-26: reports liveness with pid and port, or stopped" {
  pid_file "$$"
  run_status
  assert_exit_code 0 "$status"
  [[ "$output" == *"running (pid $$, port 18009)"* ]]

  rm -f "$JUDGMENT_LOCAL_RUN_DIR/kev.pid"
  run_status
  [ "$status" -ne 0 ]
  [[ "$output" == *stopped* ]]
}

@test "AC-034-27: reports payload fitness for small and cap-sized probes" {
  pid_file "$$"
  run_status
  assert_exit_code 0 "$status"
  [[ "$output" == *"small probe"*pass* ]]
  [[ "$output" == *"max probe"*pass* ]]
  [ "$(attempts_count)" -eq 2 ]
}

@test "AC-034-28: a failing max-size probe is reported, not a crash" {
  pid_file "$$"
  printf '0\t200\t%s/healthy.json\n0\t500\t%s/healthy.json\n' "$FIX" "$FIX" > "$SEQUENCE"
  run_status
  assert_exit_code 1 "$status"
  [[ "$output" == *"small probe"*pass* ]]
  [[ "$output" == *"max probe"*fail* ]]
  [[ "$output" != *"command not found"* ]]
}

# ── Task 8: docs ────────────────────────────────────────────────────────────

@test "AC-034-29: setup lists make judgment-up as step 0, optional-but-recommended" {
  grep_file "$PIPE_DOC" 'make judgment-up' 'step 0|Step 0' 'optional' 'recommended'
  grep_file "$PIPE_DOC" '95%' 'cache-read'
  awk '/^### One-time setup/{f=1} /^## /{if (f && !/One-time setup/) exit} f' "$PIPE_DOC" \
    | grep -q 'make judgment-up'
}

@test "AC-034-30: typed-judgment layer documents the contract and the new surface" {
  local section
  section="$(awk '/^## Typed-judgment layer/{f=1;next} /^## /{f=0} f' "$PIPE_DOC")"
  printf '%s\n' "$section" | grep -q 'scripts/judgment-preflight\.sh'
  printf '%s\n' "$section" | grep -q -- '--max-state-bytes'
  printf '%s\n' "$section" | grep -q '12 KB'
  printf '%s\n' "$section" | grep -q 'unconfigured'
  printf '%s\n' "$section" | grep -q 'unreachable'
  printf '%s\n' "$section" | grep -q 'payload_overflow'
  printf '%s\n' "$section" | grep -q 'error'
  printf '%s\n' "$section" | grep -q 'make judgment-status'
  printf '%s\n' "$section" | grep -q 'stock procedure'
  printf '%s\n' "$section" | grep -qE 'never .{0,40}(halt|BLOCKED)'
}

# ── Task 9: ADR ─────────────────────────────────────────────────────────────

@test "AC-034-31: ADR records the contract change and the index is updated" {
  [ -f "$ADR_034" ]
  local heading
  while IFS= read -r heading; do
    grep -qF -- "$heading" "$ADR_034" || { echo "missing ADR section: $heading" >&2; return 1; }
  done < <(grep '^## ' "$REPO_ROOT/templates/ADR.md")
  grep_file "$ADR_034" \
    'exit[ `]*10' 'stock procedure|stock applicability' \
    'fail-open' 'judgment-preflight' \
    'max-state-bytes|payload cap' 'truncat' \
    'unconfigured' 'unreachable' 'payload_overflow' 'error'
  grep -qE '\| 0012 \|.*0012-judgment-consumer-contract-fail-open-preflight\.md' "$ADR_INDEX"
}

# ── Task 10: static assertion + hermeticity ────────────────────────────────

@test "AC-034-32: no consumer maps exit 10 to BLOCKED" {
  local violations="" f e b d exits blocks
  for f in "$REPO_ROOT"/agents/*.md "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$f" ] || continue
    exits="$(grep -nE 'exit[ `]*10' "$f" | cut -d: -f1 || true)"
    blocks="$(grep -n 'BLOCKED' "$f" | cut -d: -f1 || true)"
    for e in $exits; do
      for b in $blocks; do
        d=$((e - b)); [ "$d" -lt 0 ] && d=$((-d))
        [ "$d" -le 3 ] && violations="$violations $(basename "$f"):$e/$b"
      done
    done
  done
  [ -z "$violations" ] || { echo "exit-10 -> BLOCKED mapping: $violations" >&2; return 1; }

  # positive contract: spec-ux routes exit 10 to the stock applicability check
  local branch
  branch="$(awk '/\*\*exit 10\*\*/{f=1} f{print; n++} n>=8{exit}' "$SPEC_UX")"
  [[ "$branch" == *"Applicability check"* ]]
}

@test "AC-034-33: new tests run offline with no live backend required" {
  # the fake transport is the only "network" this suite has
  grep -q 'BIN/curl' "$BATS_TEST_FILENAME"
  ! grep -qE 'localhost:8009|127\.0\.0\.1:8009' "$BATS_TEST_FILENAME"
  # test_helper enforces the hermetic JUDGMENT_* baseline
  grep -q 'JUDGMENT_PREFLIGHT_TTL_SECONDS' "$REPO_ROOT/scripts/tests/test_helper.bash"

  # a full probe cycle still succeeds with no live backend anywhere
  seq_ok
  run_preflight -- --force
  assert_exit_code 0 "$status"
  [ "$(attempts_count)" -eq 1 ]
}
