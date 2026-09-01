#!/usr/bin/env bats
# check-orchestration.bats — characterization tests for scripts/check-orchestration.sh
# Contract: 0 when every orchestration reference resolves; 1 with a
# `[BROKEN] <citing-file> -> <ref>` line per dangling reference.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-orchestration: dangling scripts/ reference exits 1 with a [BROKEN] line" {
  mkdir -p "$TMPDIR_HELPER/agents" "$TMPDIR_HELPER/scripts"
  printf 'Run `scripts/does-not-exist.sh` first.\n' > "$TMPDIR_HELPER/agents/a.md"
  run bash "$REPO_ROOT/scripts/check-orchestration.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[BROKEN] agents/a.md -> scripts/does-not-exist.sh"* ]]
  [[ "$output" == *"broken reference(s)!"* ]]
}

@test "check-orchestration: resolvable scripts/ reference exits 0" {
  mkdir -p "$TMPDIR_HELPER/agents" "$TMPDIR_HELPER/scripts"
  printf 'exit 0\n' > "$TMPDIR_HELPER/scripts/real.sh"
  printf 'Run `scripts/real.sh` first.\n' > "$TMPDIR_HELPER/agents/a.md"
  run bash "$REPO_ROOT/scripts/check-orchestration.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All orchestration references valid."* ]]
}

@test "check-orchestration: the real repo has no dangling orchestration references" {
  run bash "$REPO_ROOT/scripts/check-orchestration.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All orchestration references valid."* ]]
}
