#!/usr/bin/env bats
# check-saga-tests.bats — characterization tests for scripts/check-saga-tests.sh
# Contract: 0 when required tests are found or nothing is detected; 1 when saga
# or outbox code is detected without the corresponding integration tests.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-saga-tests: neither saga nor outbox detected warns and exits 0" {
  export SAGA_DETECTED=false OUTBOX_DETECTED=false
  run bash "$REPO_ROOT/scripts/check-saga-tests.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAGA_DETECTED=false"* ]]
  [[ "$output" == *"nothing to check"* ]]
}

@test "check-saga-tests: saga detected without an integration test exits 1 and names the required pattern" {
  mkdir -p "$TMPDIR_HELPER/sg"
  printf 'package sg\n\nfunc OrderSagaHandler() error { return nil }\n' > "$TMPDIR_HELPER/sg/order_saga.go"
  export SAGA_DETECTED=true OUTBOX_DETECTED=false
  run bash "$REPO_ROOT/scripts/check-saga-tests.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Saga code detected but no saga integration test file found"* ]]
  [[ "$output" == *"violation(s)"* ]]
}

@test "check-saga-tests: saga detected with a compensation integration test exits 0" {
  mkdir -p "$TMPDIR_HELPER/sg"
  printf 'package sg\n\nfunc OrderSagaHandler() error { return nil }\n' > "$TMPDIR_HELPER/sg/order_saga.go"
  printf 'package sg\n\nfunc TestOrderSagaCompensation(t *testing.T) { /* compensate rollback */ }\n' > "$TMPDIR_HELPER/sg/order_saga_test.go"
  export SAGA_DETECTED=true OUTBOX_DETECTED=false
  run bash "$REPO_ROOT/scripts/check-saga-tests.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SAGA_DETECTED=true"* ]]
  [[ "$output" == *"all required tests found"* ]]
}

# ── ADR 0006 D3: Python (pytest) and Rust (tests/) integration-test discovery ───
# pytest `test_*saga*.py` and Rust `tests/*saga*.rs` are HOUSE CONVENTIONS; the
# docs fix the requirement (an integration test proving compensation), not the
# filename. Without these globs a detected Python/Rust saga would FALSE-FAIL —
# the exact ordering hazard ADR 0006 defect 3 warns about.

@test "check-saga-tests: Python saga with a pytest compensation test exits 0" {
  mkdir -p "$TMPDIR_HELPER/app" "$TMPDIR_HELPER/tests"
  printf 'async def reserve_inventory_saga_handler(ctx): ...\n' > "$TMPDIR_HELPER/app/order_saga.py"
  printf 'def test_saga_compensation_triggers_rollback():\n    assert True\n' > "$TMPDIR_HELPER/tests/test_order_saga.py"
  export SAGA_DETECTED=true OUTBOX_DETECTED=false
  run bash "$REPO_ROOT/scripts/check-saga-tests.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"compensation/failure test scenario found"* ]]
  [[ "$output" == *"all required tests found"* ]]
}

@test "check-saga-tests: Rust saga with a tests/ integration test exits 0" {
  mkdir -p "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/tests"
  printf 'pub struct OrderSagaHandler;\n' > "$TMPDIR_HELPER/src/order_saga.rs"
  printf '#[tokio::test]\nasync fn saga_compensation_triggers_rollback() {}\n' > "$TMPDIR_HELPER/tests/saga_integration.rs"
  export SAGA_DETECTED=true OUTBOX_DETECTED=false
  run bash "$REPO_ROOT/scripts/check-saga-tests.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"compensation/failure test scenario found"* ]]
  [[ "$output" == *"all required tests found"* ]]
}

@test "check-saga-tests: Python saga without an integration test exits 1" {
  mkdir -p "$TMPDIR_HELPER/app"
  printf 'async def reserve_inventory_saga_handler(ctx): ...\n' > "$TMPDIR_HELPER/app/order_saga.py"
  export SAGA_DETECTED=true OUTBOX_DETECTED=false
  run bash "$REPO_ROOT/scripts/check-saga-tests.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no saga integration test file found"* ]]
}
