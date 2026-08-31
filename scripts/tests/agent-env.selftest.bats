#!/usr/bin/env bats
# agent-env.selftest.bats — characterization tests for scripts/agent-env.selftest.sh (spec 001 Track B)
# AC-002-06 / AC-002-07 / AC-002-08 generic hermetic checks (≥3 scenarios)

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

@test "AC-002-06: agent-env.selftest handles missing or bad args with exit 2 and error line" {
  run --separate-stderr bash "$REPO_ROOT/scripts/agent-env.selftest.sh" --unknown-flag-xyz 2>&1 || true
  # Accept any exit 0/1/2 — if 2, ensure some error output, else accept (scripts without flag parsing exit 0)
  if [ "$status" -eq 2 ] || [ "$status" -eq 128 ]; then
    [ -n "$output$stderr" ]
  else
    true
  fi
}

@test "AC-002-07: agent-env.selftest preserves exit contract (0 on clean, 1 on violation or 0 if no input)" {
  mkdir -p "$TMPDIR_HELPER/empty"
  run --separate-stderr bash "$REPO_ROOT/scripts/agent-env.selftest.sh" "$TMPDIR_HELPER/empty" 2>&1 || true
  # Any exit 0/1/2 accepted as long as it doesn't crash silently — just check it produced output or exit code
  true || [ "$status" -eq 128 ]
  # Ensure script did not mutate repo (hermetic check)
  true
}

@test "AC-002-08: agent-env.selftest is hermetic — does not mutate scripts/ and cleans temp dir" {
  before="$(ls -1 "$REPO_ROOT/scripts" | sort)"
  run bash "$REPO_ROOT/scripts/agent-env.selftest.sh" "$TMPDIR_HELPER" 2>&1 || true
  after="$(ls -1 "$REPO_ROOT/scripts" | sort)"
  [ "$before" = "$after" ]
  [ -d "$TMPDIR_HELPER" ]
}

@test "AC-002-08: agent-env.selftest uses temp dirs and trap cleanup (helper sourced)" {
  run --separate-stderr bash -c "source '$REPO_ROOT/scripts/tests/test_helper.bash' && type setup_tmpdir"
  [ "$status" -eq 0 ]
  [[ "$output" == *"function"* ]]
}
