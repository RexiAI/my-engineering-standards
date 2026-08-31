#!/usr/bin/env bats
# record-gate-run.bats — characterization tests for scripts/record-gate-run.sh
# Contract: 0 when the record validates and is appended; 1 with a stderr message
# naming the offending field and nothing appended.

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  RUNS="$TMPDIR_HELPER/runs.jsonl"
  VALID='{"specSlug":"001-x","gatesFailed":[],"warnings":[],"durationSec":1.0,"outcome":"pass"}'
}
teardown() { teardown_tmpdir; }

@test "record-gate-run: no record exits 1 and says the record must be a JSON object" {
  run --separate-stderr env GATE_RUNS_FILE="$RUNS" bash "$REPO_ROOT/scripts/record-gate-run.sh"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"invalid record"* ]]
  [[ "$stderr" == *"must be a JSON object starting with '{'"* ]]
  [ ! -s "$RUNS" ]
}

@test "record-gate-run: a valid record exits 0 and appends exactly one line" {
  run env GATE_RUNS_FILE="$RUNS" bash "$REPO_ROOT/scripts/record-gate-run.sh" -record "$VALID"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$RUNS")" -eq 1 ]
  grep -q '"outcome"' "$RUNS"
}

@test "record-gate-run: a missing required field exits 1 naming the field and appends nothing" {
  run --separate-stderr env GATE_RUNS_FILE="$RUNS" bash "$REPO_ROOT/scripts/record-gate-run.sh" -record \
    '{"specSlug":"001-x","gatesFailed":[],"warnings":[],"outcome":"pass"}'
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"missing required field 'durationSec'"* ]]
  [ ! -s "$RUNS" ]
}

@test "record-gate-run: an out-of-range outcome exits 1 naming the allowed values" {
  run --separate-stderr env GATE_RUNS_FILE="$RUNS" bash "$REPO_ROOT/scripts/record-gate-run.sh" -record \
    '{"specSlug":"001-x","gatesFailed":[],"warnings":[],"durationSec":1.0,"outcome":"maybe"}'
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"must be one of pass|fail|block"* ]]
  [ ! -s "$RUNS" ]
}
