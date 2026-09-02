#!/usr/bin/env bats
# agent-env.selftest.bats — characterization test for scripts/agent-env.selftest.sh
#
# agent-env.selftest.sh is itself an assertion carrier: it builds fixtures and
# asserts each case's exit code. This test asserts the selftest's own contract
# (exit 0 plus its summary line) and that it reports a non-zero pass count —
# a selftest that silently asserts nothing would fail the second assertion.

load test_helper
bats_require_minimum_version 1.5.0

@test "agent-env.selftest: exits 0 and reports every case passing" {
  run bash "$REPO_ROOT/scripts/agent-env.selftest.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"agent-env.selftest: all cases pass"* ]]
}

@test "agent-env.selftest: reports a non-zero assertion count and zero failures" {
  run bash "$REPO_ROOT/scripts/agent-env.selftest.sh"
  [ "$status" -eq 0 ]
  n="$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '[0-9]+ (passed|assertions passed|cases passed)' | grep -oE '^[0-9]+' | head -1)"
  [ -n "$n" ]
  # Contract, not census: assert the selftest asserted something and reported
  # no failures. The exact count is incidental and would break on every
  # legitimate case added or removed.
  [ "$n" -gt 0 ]
  [[ "$output" == *"0 failed"* ]]
}

@test "agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path" {
  # Wiring assertion for the three-way distinction (git_ignore_status): on a
  # healthy repo the credential-file case must report the ok line and must not
  # emit the tooling-failure line. The three outcomes themselves are proven
  # against purpose-built repo fixtures in check-common.bats.
  run bash "$REPO_ROOT/scripts/agent-env.selftest.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"git check-ignore config/agent.local.env exits 0"* ]]
  [[ "$output" == *"example is NOT ignored (template stays trackable)"* ]]
  [[ "$output" != *"could not run the gitignore check"* ]]
  [[ "$output" != *"SECURITY: config/agent.local.env is not gitignored"* ]]
}
