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
  [[ "$output" == *"opencode.json: literal provider/model id found"* ]]
  [[ "$output" == *"must be an {env:SPEC_*_MODEL} reference"* ]]
}

scratch_root_with_good_files() {
  cp "$REPO_ROOT/opencode.json" "$TMPDIR_HELPER/opencode.json"
  mkdir -p "$TMPDIR_HELPER/config"
  cp "$REPO_ROOT/config/model.local.env.example" "$TMPDIR_HELPER/config/model.local.env.example"
  mkdir -p "$TMPDIR_HELPER/templates"
}

@test "check-model-env: a bridge template missing an agent exits 1 and names it" {
  scratch_root_with_good_files
  grep -v '"spec-ux"' "$REPO_ROOT/templates/opencode.json.bridge" > "$TMPDIR_HELPER/templates/opencode.json.bridge"
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"templates/opencode.json.bridge: agent spec-ux missing"* ]]
}

@test "check-model-env: a bridge template with a literal model id exits 1" {
  scratch_root_with_good_files
  sed 's|{env:SPEC_CODER_MODEL}|opencode-go/deepseek-v4-flash|' \
    "$REPO_ROOT/templates/opencode.json.bridge" > "$TMPDIR_HELPER/templates/opencode.json.bridge"
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"templates/opencode.json.bridge: agent spec-coder: model value 'opencode-go/deepseek-v4-flash' is not an {env:SPEC_CODER_MODEL} reference"* ]]
}

@test "check-model-env: a root without a bridge template skips check 4 and exits 0" {
  scratch_root_with_good_files
  rmdir "$TMPDIR_HELPER/templates"
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
}

@test "check-model-env: the real repo has no literal model ids and exits 0" {
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"{env:SPEC_*_MODEL} references"* ]]
}
