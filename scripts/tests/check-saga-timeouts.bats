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

# ── ADR 0006 D3: Python and Rust timeout coverage ──────────────────────────────
# The accepted Python/Rust timeout idioms are HOUSE CONVENTIONS chosen by ADR 0006
# D3 (docs/SAGA_PATTERN.md §Saga Timeout mandates a per-step timeout but names no
# Python/Rust API). These tests pin the with-timeout PASS and without-timeout FAIL
# in both languages.

@test "check-saga-timeouts: Python saga handler with asyncio.wait_for exits 0" {
  mkdir -p "$TMPDIR_HELPER/pygood"
  cat > "$TMPDIR_HELPER/pygood/order_saga.py" <<'PY'
import asyncio

async def reserve_inventory_saga_handler(ctx):
    await asyncio.wait_for(ctx.reserve(), timeout=30)
PY
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER/pygood"
  [ "$status" -eq 0 ]
  [[ "$output" == *"all checks passed"* ]]
}

@test "check-saga-timeouts: Python saga handler without a timeout exits 1" {
  mkdir -p "$TMPDIR_HELPER/pybad"
  cat > "$TMPDIR_HELPER/pybad/order_saga.py" <<'PY'
async def reserve_inventory_saga_handler(ctx):
    await ctx.reserve()
PY
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER/pybad"
  [ "$status" -eq 1 ]
  [[ "$output" == *"violation(s)"* ]]
  [[ "$output" == *"docs/SAGA_PATTERN.md"* ]]
}

@test "check-saga-timeouts: Rust saga handler with tokio::time::timeout exits 0" {
  mkdir -p "$TMPDIR_HELPER/rsgood"
  cat > "$TMPDIR_HELPER/rsgood/order_saga.rs" <<'RS'
use tokio::time::{timeout, Duration};
pub struct OrderSagaHandler;
impl OrderSagaHandler {
    pub async fn run(&self) {
        let _ = timeout(Duration::from_secs(30), self.step()).await;
    }
    async fn step(&self) {}
}
RS
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER/rsgood"
  [ "$status" -eq 0 ]
  [[ "$output" == *"all checks passed"* ]]
}

@test "check-saga-timeouts: Rust saga handler without a timeout exits 1" {
  mkdir -p "$TMPDIR_HELPER/rsbad"
  cat > "$TMPDIR_HELPER/rsbad/order_saga.rs" <<'RS'
pub struct OrderSagaHandler;
impl OrderSagaHandler {
    pub async fn run(&self) { self.step().await; }
    async fn step(&self) {}
}
RS
  run bash "$REPO_ROOT/scripts/check-saga-timeouts.sh" "$TMPDIR_HELPER/rsbad"
  [ "$status" -eq 1 ]
  [[ "$output" == *"violation(s)"* ]]
  [[ "$output" == *"docs/SAGA_PATTERN.md"* ]]
}
