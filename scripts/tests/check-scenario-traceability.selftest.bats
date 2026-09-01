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
  [[ "$output" == *"check-scenario-traceability selftest: "*" cases passed"* ]]
}

@test "check-scenario-traceability.selftest: reports a non-zero case count and zero failures" {
  run bash "$REPO_ROOT/scripts/check-scenario-traceability.selftest.sh"
  [ "$status" -eq 0 ]
  n="$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '[0-9]+ (passed|assertions passed|cases passed)' | grep -oE '^[0-9]+' | head -1)"
  [ -n "$n" ]
  # Contract, not census: assert the selftest asserted something and reported
  # no failures. The exact count is incidental and would break on every
  # legitimate case added or removed. This selftest prints its failure tally
  # only on the failing path, so absence of "failed" is the zero-failure signal.
  [ "$n" -gt 0 ]
  [[ "$output" != *"failed"* ]]
}
