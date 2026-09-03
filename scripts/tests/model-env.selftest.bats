#!/usr/bin/env bats
# model-env.selftest.bats — characterization test for scripts/model-env.selftest.sh
#
# model-env.selftest.sh is itself an assertion carrier: it builds fixtures and
# asserts each case's exit code. This test asserts the selftest's own contract
# (exit 0 plus its summary line) and that it reports a non-zero pass count —
# a selftest that silently asserts nothing would fail the second assertion.

load test_helper
bats_require_minimum_version 1.5.0

@test "model-env.selftest: exits 0 and reports every case passing" {
  run bash "$REPO_ROOT/scripts/model-env.selftest.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"model-env.selftest: all cases pass"* ]]
}

@test "model-env.selftest: reports a non-zero assertion count and zero failures" {
  run bash "$REPO_ROOT/scripts/model-env.selftest.sh"
  [ "$status" -eq 0 ]
  n="$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g' | grep -oE '[0-9]+ (passed|assertions passed|cases passed)' | grep -oE '^[0-9]+' | head -1)"
  [ -n "$n" ]
  # Contract, not census: the selftest must have actually asserted something
  # (guards a silently-empty run) and must report no failures. The exact case
  # count is deliberately not asserted — it varies with the environment
  # (direnv-conditional cases are skipped when the binary is absent) and would
  # otherwise break on every legitimate case added or removed.
  [ "$n" -gt 0 ]
  [[ "$output" == *"0 failed"* ]]
}

@test "model-env.selftest: gitignore check takes the ignored path, not the could-not-run path" {
  # Wiring assertion for the three-way distinction (git_ignore_status): on a
  # healthy repo the env-file case must report the ok line and must not emit
  # the tooling-failure line. The three outcomes themselves are proven against
  # purpose-built repo fixtures in check-common.bats.
  run bash "$REPO_ROOT/scripts/model-env.selftest.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AC-025-01-05 git check-ignore exits 0 for both real env files"* ]]
  [[ "$output" != *"could not run the gitignore check"* ]]
  [[ "$output" != *"SECURITY: a real env file is not gitignored"* ]]
}
