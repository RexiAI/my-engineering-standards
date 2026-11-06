#!/usr/bin/env bats
# ac-041-agent-test-summary.bats — acceptance tests for spec 041 Task 2
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-agent-test-summary.md).
#
# Every log path is inside $TMPDIR_HELPER; no scenario writes into specs/.

load test_helper
bats_require_minimum_version 1.5.0

HELPER="$REPO_ROOT/scripts/agent-test-summary.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-041-09 — --run captures the full log and prints only the summary" {
  local log="$TMPDIR_HELPER/run.log"
  run bash "$HELPER" --run "$log" -- bash -c 'printf "one\ntwo\nthree\n"'
  [ "$status" -eq 0 ]
  [ "$(cat "$log")" = "$(printf 'one\ntwo\nthree')" ]
  [ "$output" = "SUMMARY: mode=run exit=0 signal=0 log_lines=3 log=$log" ]
}

@test "AC-041-10 — a command with no output yields a zero-valued summary" {
  local log="$TMPDIR_HELPER/empty.log"
  run bash "$HELPER" --run "$log" -- true
  [ "$status" -eq 0 ]
  [ -f "$log" ]
  [ ! -s "$log" ]
  [[ "$output" == "SUMMARY: mode=run exit=0 signal=0 log_lines=0 log=$log" ]]
}

@test "AC-041-11 — a failing command keeps its signal lines and its exit status" {
  local log="$TMPDIR_HELPER/fail.log"
  run bash "$HELPER" --run "$log" -- bash -c 'printf "FAIL TestA\nFAIL TestB\n"; exit 1'
  [ "$status" -eq 1 ]
  [ "$(sed -n '1p' <<< "$output")" = "FAIL TestA" ]
  [ "$(sed -n '2p' <<< "$output")" = "FAIL TestB" ]
  [ "$(tail -n1 <<< "$output")" = "SUMMARY: mode=run exit=1 signal=2 log_lines=2 log=$log" ]
  [ "$(grep -c '^FAIL ' "$log")" -eq 2 ]
}

@test "AC-041-12 — exit status other than 1 passes through unchanged" {
  local log="$TMPDIR_HELPER/xc.log"
  run bash "$HELPER" --run "$log" -- bash -c 'exit 42'
  [ "$status" -eq 42 ]
  [[ "$output" == *"exit=42"* ]]
}

@test "AC-041-13 — a missing command exits 127" {
  local log="$TMPDIR_HELPER/missing.log"
  run -127 bash "$HELPER" --run "$log" -- no-such-command-041
  [ "$status" -eq 127 ]
  [[ "$output" == *"SUMMARY: mode=run exit=127 "* ]]
  [ -f "$log" ]
}

@test "AC-041-14 — at most 50 signal lines are printed" {
  local log="$TMPDIR_HELPER/many.log"
  seq 1 500 | sed 's/^/FAIL case /' > "$log"
  run bash "$HELPER" --read "$log"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^FAIL ' <<< "$output")" -eq 50 ]
  [ "$(sed -n '51p' <<< "$output")" = "TRUNCATED: 450 more signal lines omitted; full log: $log" ]
  [[ "$(tail -n1 <<< "$output")" == *"signal=500"* ]]
}

@test "AC-041-15 — the 8,192-byte cap stops the signal block" {
  local log="$TMPDIR_HELPER/long.log" i
  for i in 1 2 3 4 5; do
    printf 'FAIL %s\n' "$(head -c 2043 /dev/zero | tr '\0' 'x')"
  done > "$log"
  run bash "$HELPER" --read "$log"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^FAIL ' <<< "$output")" -eq 3 ]
  [ "$(sed -n '4p' <<< "$output")" = "TRUNCATED: 2 more signal lines omitted; full log: $log" ]
  [ "$(head -n3 <<< "$output" | wc -c | tr -d ' ')" -le 8192 ]
}

@test "AC-041-16 — zero-count lines are not signals" {
  local log="$TMPDIR_HELPER/zero.log"
  printf 'failures=0\nOK 12 tests\n' > "$log"
  run bash "$HELPER" --read "$log"
  [ "$status" -eq 0 ]
  [ "$output" = "SUMMARY: mode=read exit=- signal=0 log_lines=2 log=$log" ]
}

@test "AC-041-17 — a log path inside specs/ is refused before the command runs" {
  mkdir -p "$TMPDIR_HELPER/specs/041-pipeline-token-savings"
  cd "$TMPDIR_HELPER" || return 1
  run --separate-stderr bash "$HELPER" --run \
    specs/041-pipeline-token-savings/evidence.log -- touch "$TMPDIR_HELPER/marker"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"refusing to write a log inside specs/"* ]]
  [ ! -e "$TMPDIR_HELPER/marker" ]
  [ ! -e "$TMPDIR_HELPER/specs/041-pipeline-token-savings/evidence.log" ]
}

@test "AC-041-18 — --read formats an existing failing log and exits 0" {
  local log="$TMPDIR_HELPER/three.log"
  printf 'FAIL a\nFAIL b\nFAIL c\n' > "$log"
  run bash "$HELPER" --read "$log"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^FAIL ' <<< "$output")" -eq 3 ]
  [ "$(tail -n1 <<< "$output")" = "SUMMARY: mode=read exit=- signal=3 log_lines=3 log=$log" ]
}

@test "AC-041-19 — --read on a missing file is a tooling error" {
  local missing="$TMPDIR_HELPER/absent.log"
  run --separate-stderr bash "$HELPER" --read "$missing"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"$missing"* ]]
}

@test "AC-041-20 — no mode is a usage error" {
  run --separate-stderr bash "$HELPER"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage:"* ]]
  [[ "$stderr" == *"--run"* ]]
}

@test "unit — unknown option and --run without -- are usage errors" {
  run --separate-stderr bash "$HELPER" --frobnicate
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage:"* ]]
  run --separate-stderr bash "$HELPER" --run "$TMPDIR_HELPER/x.log" true
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage:"* ]]
}

@test "unit — -h prints the header and exits 0" {
  run bash "$HELPER" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"--run"* ]]
  [[ "$output" == *"--read"* ]]
}

@test "unit — a green TAP stream with adversarial titles prints zero signals" {
  local log="$TMPDIR_HELPER/green-tap.log"
  cat > "$log" <<'EOF'
1..9
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 unit — a title containing FAIL and FAILED words
ok 4 unit — a title containing WARN and warning words
ok 5 unit — a title containing error: and AssertionError
ok 6 unit — a title containing panic: and Traceback
ok 7 unit — a title containing ✗ and ✘ glyphs
ok 8 AC-030-01-07: version pin and pre-1.0 instability warning present
ok 9 unit — an ending marker (not ok) and a zero count failures=0
EOF
  run bash "$HELPER" --read "$log"
  [ "$status" -eq 0 ]
  [ "$output" = "SUMMARY: mode=read exit=- signal=0 log_lines=10 log=$log" ]
}

@test "unit — a real TAP failure is a signal" {
  local log="$TMPDIR_HELPER/tap-fail.log"
  cat > "$log" <<'EOF'
1..4
ok 1 AC-X-01: passes
not ok 2 AC-X-02: expected (not ok) marker in the title
# see the failure above
ok 3 AC-X-03: passes
not ok 4 AC-X-04: also fails
EOF
  run bash "$HELPER" --read "$log"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^not ok' <<< "$output")" -eq 2 ]
  [ "$(tail -n1 <<< "$output")" = "SUMMARY: mode=read exit=- signal=2 log_lines=6 log=$log" ]
}

@test "unit — the four interface constants are fixed" {
  grep -q '^MAX_SIGNAL_LINES=50$' "$HELPER"
  grep -q '^MAX_OUTPUT_BYTES=8192$' "$HELPER"
  grep -q '^SIGNAL_RE=' "$HELPER"
  grep -q '^ZERO_RE=' "$HELPER"
}
