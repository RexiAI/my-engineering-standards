#!/bin/bash
# model-env.vars.sh — Single source of truth for the spec-pipeline model roster.
#
# Sourced-only (never executed directly): defines the 8 SPEC_*_MODEL var names,
# the 8 spec-agent names, the agent→var mapping, and which agents default to the
# "plus" model tier. Every consumer sources this file — check-model-env.sh,
# model-env.selftest.sh, model-env.runtime-check.sh — so the roster lives in one
# place. Adding or renaming an agent means editing this file, not four scripts.
# (load-model-env.sh keeps its own inline copy: see its header for why.)
#
# Sourced files do not set shell flags; the sourcing script's own
# `set -euo pipefail` governs. Defines only names, no exported state.

# The 8 SPEC_*_MODEL vars opencode.json interpolates, in agent-table order.
MODEL_ENV_VARS=(
  SPEC_SPECIFIER_MODEL
  SPEC_UX_MODEL
  SPEC_VERIFIER_MODEL
  SPEC_MUTATION_RUNNER_MODEL
  SPEC_PR_OPENER_MODEL
  SPEC_CODER_MODEL
  SPEC_REFACTORER_MODEL
  SPEC_PIPELINE_MODEL
)

# The 8 spec agents that carry a model, in the same order as MODEL_ENV_VARS.
MODEL_ENV_AGENTS=(
  spec-specifier
  spec-ux
  spec-verifier
  spec-mutation-runner
  spec-pr-opener
  spec-coder
  spec-refactorer
  spec-pipeline
)

# Agents whose committed default is the "plus" model tier; every other agent
# defaults to the "fast" tier (see config/model.local.env.example).
MODEL_ENV_PLUS_AGENTS=(
  spec-verifier
  spec-mutation-runner
  spec-pr-opener
)

# agent -> expected env var, one per modelable spec agent; "" for anything else.
model_env_var_for_agent() {
  case "$1" in
    spec-specifier)       echo SPEC_SPECIFIER_MODEL ;;
    spec-ux)              echo SPEC_UX_MODEL ;;
    spec-verifier)        echo SPEC_VERIFIER_MODEL ;;
    spec-mutation-runner) echo SPEC_MUTATION_RUNNER_MODEL ;;
    spec-pr-opener)       echo SPEC_PR_OPENER_MODEL ;;
    spec-coder)           echo SPEC_CODER_MODEL ;;
    spec-refactorer)      echo SPEC_REFACTORER_MODEL ;;
    spec-pipeline)        echo SPEC_PIPELINE_MODEL ;;
    *) echo "" ;;
  esac
}
