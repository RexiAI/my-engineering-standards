#!/usr/bin/env bats
# check-scenario-traceability.selftest.bats — characterization test for scripts/check-scenario-traceability.selftest.sh
#
# check-scenario-traceability.selftest.sh is itself an assertion carrier: it builds fixtures and
# asserts each case's exit code. This test asserts the selftest's own contract
# (exit 0 plus its summary line) and that it reports a non-zero pass count —
# a selftest that silently asserts nothing would fail the second assertion.

load test_helper
bats_require_minimum_version 1.5.0

@test "check-scenario-traceability.selftest: exits 0 and reports every case passing" {
  run bash "$REPO_ROOT/scripts/check-scenario-traceability.selftest.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"check-scenario-traceability selftest: 3 cases passed"* ]]
}

@test "check-scenario-traceability.selftest: reports at least 3 assertions and zero failures" {
  run bash "$REPO_ROOT/scripts/check-scenario-traceability.selftest.sh"
  [ "$status" -eq 0 ]
  n="$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '[0-9]+ (passed|assertions passed|cases passed)' | grep -oE '^[0-9]+' | head -1)"
  [ -n "$n" ]
  [ "$n" -ge 3 ]
  [[ "$output" != *"1 failed"* ]]
}
