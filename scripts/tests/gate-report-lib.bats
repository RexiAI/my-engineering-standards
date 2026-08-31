#!/usr/bin/env bats
# gate-report-lib.bats — characterization tests for scripts/gate-report-lib.sh
# Sourced-only library: strip_dashes, json_escape, json_array, emit_json_report
# (atomic write, 1 on failure). Sourcing it must have no side effects.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "gate-report-lib: sources safely and exposes json_escape and json_array" {
  run bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/gate-report-lib.sh'; declare -F json_escape >/dev/null && declare -F json_array >/dev/null && echo BOTH"
  [ "$status" -eq 0 ]
  [ "$output" = "BOTH" ]
}

@test "gate-report-lib: strip_dashes normalizes single- and double-dash flag names" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; strip_dashes --ReportPath; echo; strip_dashes -ReportPath"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "ReportPath" ]
  [ "${lines[1]}" = "ReportPath" ]
}

@test "gate-report-lib: json_array emits a comma-separated list of quoted, escaped items" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; json_array a 'b\"c'"
  [ "$status" -eq 0 ]
  [ "$output" = '"a","b\"c"' ]
}

@test "gate-report-lib: json_array with no arguments emits nothing" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; json_array; echo END"
  [ "$status" -eq 0 ]
  [ "$output" = "END" ]
}

@test "gate-report-lib: emit_json_report writes atomically and leaves no .tmp sibling" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; emit_json_report '$TMPDIR_HELPER/r.json' '{\"k\":1}'"
  [ "$status" -eq 0 ]
  [ -f "$TMPDIR_HELPER/r.json" ]
  [ "$(cat "$TMPDIR_HELPER/r.json")" = '{"k":1}' ]
  run bash -c "ls '$TMPDIR_HELPER' | grep -c '\.tmp\.' || true"
  [ "$output" = "0" ]
}

@test "emit_json_report returns 1 and reports the path when the target is unwritable" {
  run --separate-stderr bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; emit_json_report '$TMPDIR_HELPER/no/such/dir/r.json' '{}'"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"could not write report to"* ]]
}
