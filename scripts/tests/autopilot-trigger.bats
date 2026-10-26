#!/usr/bin/env bats
# autopilot-trigger.bats — acceptance tests for spec 035 Task 1
# (specs/035-autopilot-mode/20-acceptance/AC-035-trigger.md).
# Contract: scripts/autopilot-trigger.sh prints exactly `autopilot` or `normal`
# and exits 0 in both cases.

load test_helper
bats_require_minimum_version 1.5.0

TRIGGER="$REPO_ROOT/scripts/autopilot-trigger.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-01 — literal token autopilot in any case triggers" {
  for token in autopilot AUTOPILOT AutoPilot aUtOpIlOt; do
    run env -u SPEC_AUTOPILOT bash "$TRIGGER" "$token"
    [ "$status" -eq 0 ]
    [ "$output" = "autopilot" ]
  done
}

@test "AC-035-02 — SPEC_AUTOPILOT=1 triggers without a token" {
  run env SPEC_AUTOPILOT=1 bash "$TRIGGER" 001-x
  [ "$status" -eq 0 ]
  [ "$output" = "autopilot" ]
}

@test "AC-035-03 — no token and unset env is not autopilot" {
  run env -u SPEC_AUTOPILOT bash "$TRIGGER" 001-x
  [ "$status" -eq 0 ]
  [ "$output" = "normal" ]
}

@test "AC-035-04 — any SPEC_AUTOPILOT value other than the literal 1 is not autopilot" {
  for value in 0 true yes 01 on ""; do
    run env SPEC_AUTOPILOT="$value" bash "$TRIGGER"
    [ "$status" -eq 0 ]
    [ "$output" = "normal" ]
  done
}

@test "AC-035-05 — the token inside a larger word is not a trigger" {
  for token in myautopilot autopilot-mode --autopilot autopilot.js mode-autopilot; do
    run env -u SPEC_AUTOPILOT bash "$TRIGGER" "$token"
    [ "$status" -eq 0 ]
    [ "$output" = "normal" ]
  done
}

@test "unit — the script is executable, bash 3.2 safe, and writes nothing" {
  [ -x "$TRIGGER" ]
  head -1 "$TRIGGER" | grep -qxF '#!/bin/bash'
  grep -qF 'set -euo pipefail' "$TRIGGER"
  # no writes: only printf of the two tokens appears in the script
  ! grep -qE '>>?[[:space:]]*[^&|]' "$TRIGGER"
}
