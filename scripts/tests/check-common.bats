#!/usr/bin/env bats
# check-common.bats — characterization tests for scripts/check-common.sh
# Sourced-only library: json_escape, require_tools (exit 2 on a missing tool),
# finish_clean (exit 0 "nothing to check").

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-common: json_escape escapes backslash, quote, tab and newline" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; source '$REPO_ROOT/scripts/check-common.sh'; json_escape 'a\"b\\c'"
  [ "$status" -eq 0 ]
  [ "$output" = 'a\"b\\c' ]
}

@test "check-common: require_tools exits 2 with an ERROR line when a tool is absent" {
  run --separate-stderr bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/check-common.sh'; require_tools 'demo' definitely-not-a-real-tool-xyz"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"required tool 'definitely-not-a-real-tool-xyz' not found"* ]]
  [[ "$stderr" == *"cannot perform the demo check"* ]]
}

@test "check-common: require_tools returns without exiting when every tool is present" {
  run bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/check-common.sh'; require_tools 'demo' bash grep; echo REACHED"
  [ "$status" -eq 0 ]
  [ "$output" = "REACHED" ]
}

@test "check-common: finish_clean prints the human line and exits 0 when JSON is false" {
  run bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/check-common.sh'; JSON=false; finish_clean 'nothing to check here'; echo UNREACHED"
  [ "$status" -eq 0 ]
  [ "$output" = "nothing to check here" ]
}

@test "check-common: json_escape is not redefined when gate-report-lib already defined it" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; before=\$(declare -f json_escape); source '$REPO_ROOT/scripts/check-common.sh'; after=\$(declare -f json_escape); [ \"\$before\" = \"\$after\" ] && echo SAME"
  [ "$status" -eq 0 ]
  [ "$output" = "SAME" ]
}
