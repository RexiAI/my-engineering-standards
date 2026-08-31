#!/usr/bin/env bats
# gate-stats.bats — characterization tests for scripts/gate-stats.sh
# Contract: 0 when the runs file is read and a report printed (including empty);
# 1 with a stderr message when the file is missing or unreadable.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "gate-stats: missing runs file exits 1 with a stderr message naming the path" {
  run --separate-stderr env GATE_RUNS_FILE="$TMPDIR_HELPER/absent.jsonl" bash "$REPO_ROOT/scripts/gate-stats.sh"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"cannot read $TMPDIR_HELPER/absent.jsonl"* ]]
  [[ "$stderr" == *"missing or unreadable"* ]]
}

@test "gate-stats: empty runs file exits 0 and still prints the header" {
  : > "$TMPDIR_HELPER/runs.jsonl"
  run env GATE_RUNS_FILE="$TMPDIR_HELPER/runs.jsonl" bash "$REPO_ROOT/scripts/gate-stats.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Gate run stats from $TMPDIR_HELPER/runs.jsonl"* ]]
  [[ "$output" == *"Total runs: 0"* ]]
}

@test "gate-stats: counts recorded runs and reports the outcome breakdown" {
  {
    printf '{"gate":"a","outcome":"pass"}\n'
    printf '{"gate":"b","outcome":"fail"}\n'
  } > "$TMPDIR_HELPER/runs.jsonl"
  run env GATE_RUNS_FILE="$TMPDIR_HELPER/runs.jsonl" bash "$REPO_ROOT/scripts/gate-stats.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Total runs: 2"* ]]
  [[ "$output" == *"Outcome breakdown"* ]]
}

@test "gate-stats: unknown option exits 1 with a usage error on stderr" {
  run --separate-stderr bash "$REPO_ROOT/scripts/gate-stats.sh" --zzz-bogus
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"unknown option"* ]]
}
