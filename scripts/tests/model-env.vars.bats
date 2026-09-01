#!/usr/bin/env bats
# model-env.vars.bats — characterization tests for scripts/model-env.vars.sh
# Sourced-only roster: MODEL_ENV_VARS / MODEL_ENV_AGENTS must stay the same
# length and order; model_env_var_for_agent maps agent -> var, "" otherwise.

load test_helper
bats_require_minimum_version 1.5.0

SRC() { printf "source '%s/scripts/model-env.vars.sh'" "$REPO_ROOT"; }

@test "model-env.vars: the var roster and the agent roster are the same length" {
  run bash -c "$(SRC); [ \${#MODEL_ENV_VARS[@]} -eq \${#MODEL_ENV_AGENTS[@]} ] && echo \${#MODEL_ENV_VARS[@]}"
  [ "$status" -eq 0 ]
  [ "$output" -ge 9 ]
}

@test "model-env.vars: every agent in the roster maps to its own SPEC_*_MODEL var, in order" {
  run bash -c "$(SRC); for i in \"\${!MODEL_ENV_AGENTS[@]}\"; do [ \"\$(model_env_var_for_agent \"\${MODEL_ENV_AGENTS[\$i]}\")\" = \"\${MODEL_ENV_VARS[\$i]}\" ] || { echo \"MISMATCH \${MODEL_ENV_AGENTS[\$i]}\"; exit 1; }; done; echo ALIGNED"
  [ "$status" -eq 0 ]
  [ "$output" = "ALIGNED" ]
}

@test "model-env.vars: an unknown agent maps to the empty string" {
  run bash -c "$(SRC); printf '[%s]' \"\$(model_env_var_for_agent not-a-spec-agent)\""
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "model-env.vars: spec-coder maps to SPEC_CODER_MODEL" {
  run bash -c "$(SRC); model_env_var_for_agent spec-coder"
  [ "$status" -eq 0 ]
  [ "$output" = "SPEC_CODER_MODEL" ]
}

@test "model-env.vars: every plus-tier agent is also a member of the agent roster" {
  run bash -c "$(SRC); for a in \"\${MODEL_ENV_PLUS_AGENTS[@]}\"; do printf '%s\n' \"\${MODEL_ENV_AGENTS[@]}\" | grep -qx \"\$a\" || { echo \"ORPHAN \$a\"; exit 1; }; done; echo ALL_KNOWN"
  [ "$status" -eq 0 ]
  [ "$output" = "ALL_KNOWN" ]
}
