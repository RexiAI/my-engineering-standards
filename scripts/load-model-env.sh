#!/bin/bash
# load-model-env.sh — Export the SPEC_*_MODEL vars opencode.json interpolates.
#
# opencode.json resolves every agent.*.model from an {env:SPEC_*_MODEL}
# reference. This loader exports all 8 vars so the interpolation always sees a
# non-empty value. Each var resolves from the first non-empty source:
#   1. the variable already exported in the process environment (never
#      clobbered — a machine-level override survives),
#   2. config/model.local.env         (gitignored per-machine override),
#   3. config/model.local.env.example (committed defaults).
#
# Default mechanism — source it from your shell profile once:
#   echo 'source <repo>/scripts/load-model-env.sh' >> ~/.bashrc   # or ~/.zshrc
# Every shell then exports the vars automatically before opencode launches.
# It is never intended to be sourced per-launch by hand.
#
# Usage:
#   source scripts/load-model-env.sh [PROJECT_ROOT]
#
# PROJECT_ROOT is the directory whose config/ holds the env files. It defaults
# to the repo root, derived from this script's own location (the parent of the
# scripts/ directory) — so it works from any cwd, and when sourced through a
# .standards/ submodule in a child repo it still resolves the standards repo's
# config/. Pass it explicitly to run against scratch fixtures (selftest, CI
# runtime check).
#
# Runs non-interactively: no prompts, no TTY requirement. Idempotent — running
# it twice yields the same exports as running once.
#
# Exit codes:
#   0 — all 8 vars resolved and exported
#   1 — at least one var resolved from no source (message names the var; only
#       reachable when the committed example is missing or broken)
#
# Self-contained by design: this profile-sourced runtime artifact defines its
# own roster inline rather than sourcing scripts/model-env.vars.sh — an added
# sourced dependency changes bash's errexit propagation for the exit-1 path,
# which the selftest pins. The shared vars file is the source of truth for the
# check/selftest/runtime-check consumers.
set -euo pipefail

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

# Read KEY=VALUE lines from an env file, skipping comments and blanks, with
# CRLF stripped. Prints nothing (and exits 0) when the file is absent.
_model_env_read_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$file" | tr -d '\r' || true
}

# Resolve one var from the first non-empty source: process env, local env
# file, example env file. Prints the resolved value, or nothing when every
# source is empty.
_model_env_resolve() {
  local var="$1" local_lines="$2" example_lines="$3"
  local value="${!var:-}"
  if [ -z "$value" ] && [ -n "$local_lines" ]; then
    value="$(printf '%s\n' "$local_lines" \
      | awk -F= -v key="$var" '$1==key { sub(/^[^=]*=/,""); print; exit }')"
  fi
  if [ -z "$value" ] && [ -n "$example_lines" ]; then
    value="$(printf '%s\n' "$example_lines" \
      | awk -F= -v key="$var" '$1==key { sub(/^[^=]*=/,""); print; exit }')"
  fi
  printf '%s' "$value"
}

model_env_main() {
  local root="${1:-}"
  local script_dir local_lines example_lines var value unresolved=0

  if [ -z "$root" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="$(dirname "$script_dir")"
  fi

  local_lines="$(_model_env_read_file "$root/config/model.local.env")"
  example_lines="$(_model_env_read_file "$root/config/model.local.env.example")"

  for var in "${MODEL_ENV_VARS[@]}"; do
    value="$(_model_env_resolve "$var" "$local_lines" "$example_lines")"
    if [ -z "$value" ]; then
      echo "ERROR: $var resolves from no source (process env, config/model.local.env, config/model.local.env.example). Export it or fix config/model.local.env.example." >&2
      unresolved=1
    else
      export "$var=$value"
    fi
  done

  # Leave no trace when sourced from a shell profile: drop every name this
  # file defines.
  unset MODEL_ENV_VARS _model_env_read_file _model_env_resolve model_env_main
  unset root script_dir local_lines example_lines var value
  if [ "$unresolved" -ne 0 ]; then
    unset unresolved
    return 1
  fi
  unset unresolved
}

model_env_main "$@"
