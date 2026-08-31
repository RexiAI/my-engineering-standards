#!/usr/bin/env bats
# check-saga-timeouts.bats — characterization tests for scripts/check-saga-timeouts.sh
# Contract: 0 when no saga code or every handler has a timeout; 1 when saga code
# is present without timeout enforcement.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-saga-timeouts: tree with no saga code exits 0" {
  mkdir -p "$TMPDIR_HELPER/src"
  printf 'package src\nfunc Add(a, b int) int { return a + b }\n' > "$TMPDIR_HELPER/src/math.go"
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
}

@test "check-saga-timeouts: saga handler without a timeout exits 1 and counts violations" {
  mkdir -p "$TMPDIR_HELPER/sg"
  printf 'package sg\nfunc OrderSagaHandler() error { return nil }\n' > "$TMPDIR_HELPER/sg/order_saga.go"
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER/sg"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Saga timeout check"* ]]
  [[ "$output" == *"violation(s)"* ]]
  [[ "$output" == *"docs/SAGA_PATTERN.md"* ]]
}

@test "check-saga-timeouts: saga handler with WithTimeout exits 0" {
  mkdir -p "$TMPDIR_HELPER/sg2"
  printf 'package sg\nfunc OrderSagaHandler() error {\n\tctx, cancel := context.WithTimeout(ctx, d)\n\tdefer cancel()\n\treturn nil\n}\n' > "$TMPDIR_HELPER/sg2/order_saga.go"
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER/sg2"
  [ "$status" -eq 0 ]
}
