#!/usr/bin/env bats
# Spec 036 — pipeline-agent single source. Each scenario is asserted from the
# transcript of scripts/check-agent-doc-duplication.selftest.sh, run once per file.

setup_file() {
  local root; root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  bash "$root/scripts/check-agent-doc-duplication.selftest.sh" >"$BATS_FILE_TMPDIR/out" 2>&1 || true
}

assert_pass() {
  grep -q "^PASS $1 " "$BATS_FILE_TMPDIR/out" || { cat "$BATS_FILE_TMPDIR/out"; return 1; }
}

@test "AC-036-01-01: selftest scenario passes" {
  assert_pass "AC-036-01-01"
}

@test "AC-036-01-02: selftest scenario passes" {
  assert_pass "AC-036-01-02"
}

@test "AC-036-01-03: selftest scenario passes" {
  assert_pass "AC-036-01-03"
}

@test "AC-036-01-04: selftest scenario passes" {
  assert_pass "AC-036-01-04"
}

@test "AC-036-01-05: selftest scenario passes" {
  assert_pass "AC-036-01-05"
}

@test "AC-036-01-06: selftest scenario passes" {
  assert_pass "AC-036-01-06"
}

@test "AC-036-01-07: selftest scenario passes" {
  assert_pass "AC-036-01-07"
}

@test "AC-036-01-08: selftest scenario passes" {
  assert_pass "AC-036-01-08"
}

@test "AC-036-02-01: selftest scenario passes" {
  assert_pass "AC-036-02-01"
}

@test "AC-036-02-02: selftest scenario passes" {
  assert_pass "AC-036-02-02"
}

@test "AC-036-02-03: selftest scenario passes" {
  assert_pass "AC-036-02-03"
}

@test "AC-036-03-01: selftest scenario passes" {
  assert_pass "AC-036-03-01"
}

@test "AC-036-03-02: selftest scenario passes" {
  assert_pass "AC-036-03-02"
}

@test "AC-036-03-03: selftest scenario passes" {
  assert_pass "AC-036-03-03"
}

@test "AC-036-03-04: selftest scenario passes" {
  assert_pass "AC-036-03-04"
}

@test "AC-036-03-05: selftest scenario passes" {
  assert_pass "AC-036-03-05"
}

@test "AC-036-03-06: selftest scenario passes" {
  assert_pass "AC-036-03-06"
}

@test "AC-036-03-07: selftest scenario passes" {
  assert_pass "AC-036-03-07"
}

@test "AC-036-03-08: selftest scenario passes" {
  assert_pass "AC-036-03-08"
}

@test "AC-036-03-09: selftest scenario passes" {
  assert_pass "AC-036-03-09"
}

@test "AC-036-04-01: selftest scenario passes" {
  assert_pass "AC-036-04-01"
}

@test "AC-036-04-02: selftest scenario passes" {
  assert_pass "AC-036-04-02"
}

@test "AC-036-04-03: selftest scenario passes" {
  assert_pass "AC-036-04-03"
}

@test "AC-036-unit: selftest exits 0 overall" {
  run bash "$BATS_TEST_DIRNAME/../check-agent-doc-duplication.selftest.sh"
  [ "$status" -eq 0 ]
}
