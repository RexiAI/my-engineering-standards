#!/usr/bin/env bats
# check-model-env.bats — characterization tests for scripts/check-model-env.sh
# Contract: 0 when every agent model is an {env:SPEC_*_MODEL} reference and no
# real env file is tracked; 1 naming the offending agent/path/var.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-model-env: missing opencode.json exits 1 and names the expected path" {
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"opencode.json not found at $TMPDIR_HELPER/opencode.json"* ]]
}

@test "check-model-env: a literal provider/model id in an agent block exits 1" {
  printf '{"agent":{"spec-coder":{"model":"anthropic/claude-x"}}}' > "$TMPDIR_HELPER/opencode.json"
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"literal provider/model id found in opencode.json"* ]]
  [[ "$output" == *"must be an {env:SPEC_*_MODEL} reference"* ]]
}

@test "check-model-env: the real repo has no literal model ids and exits 0" {
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"{env:SPEC_*_MODEL} references"* ]]
}
