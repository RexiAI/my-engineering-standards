#!/bin/bash
# load-env.sh — Export per-machine credentials for pipeline agents.
#
# Sources config/agent.local.env (relative to the caller's repo root, resolved
# from this script's own location — works from any cwd) and exports every
# KEY=value it defines. Plain KEY=value lines only; comments and blanks are
# skipped; CRLF is tolerated. Pre-existing exported variables are NEVER
# clobbered — a value already in the environment wins, so a machine-level
# override survives sourcing.
#
# Fails loudly when the real file is missing but the committed example
# (config/agent.local.env.example) exists: prints the missing path and the
# copy-fill step to stderr and exits 1. When both files are missing, no-ops
# (exit 0) — a repo with nothing configured runs fine.
#
# Usage:
#   source scripts/load-env.sh [PROJECT_ROOT]    # export in-place (profile-era)
#   eval "$(scripts/load-env.sh --emit [PROJECT_ROOT])"   # direnv .envrc
#
# --emit prints `export KEY=value` lines to stdout instead of exporting
# in-place, so a direnv .envrc can run the loader in a clean subshell (command
# substitution) and eval the output. Sourcing inside direnv is unsafe (the
# loader's unsets collide with direnv's shell state). PROJECT_ROOT is the
# directory whose config/ holds the env files. It defaults to the repo root
# (parent of scripts/). Pass it explicitly to run against scratch fixtures
# (selftest).
#
#
# Exit codes:
#   0 — loaded (or nothing to load)
#   1 — real file missing while the example exists (loud error names the path)
set -euo pipefail

# Export every KEY=value line from an env file: comments and blanks skipped,
# CRLF stripped, only valid var names exported, and pre-existing exported
# variables never clobbered. Always returns 0 — the caller decides how to treat
# presence/absence.
_load_env_export() {
  local file="$1" emit="$2" line var
  while IFS= read -r line; do
    case "$line" in
      '' | \#*) continue ;;
    esac
    line="${line%$'\r'}"
    case "$line" in
      [A-Za-z_]*=*)
        var="${line%%=*}"
        case "$var" in
          [A-Za-z_][A-Za-z0-9_]*)
            if [ "$emit" -eq 1 ]; then
              printf 'export %q\n' "$line"
            elif [ -z "${!var:-}" ]; then
              # No-clobber: only export when not already set (non-empty).
              export "$line"
            fi
            ;;
        esac
        ;;
    esac
  done < "$file"
}

load_env_main() {
  local emit=0 root script_dir real example rc=0
  if [ "$#" -gt 0 ] && [ "$1" = "--emit" ]; then
    emit=1
    shift
  fi
  root="${1:-}"
  if [ -z "$root" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="$(dirname "$script_dir")"
  fi
  real="$root/config/agent.local.env"
  example="$root/config/agent.local.env.example"

  if [ -f "$real" ]; then
    _load_env_export "$real" "$emit"
  elif [ -f "$example" ]; then
    echo "ERROR: $real not found, but $example exists. Copy it and fill in real values:" >&2
    echo "  cp config/agent.local.env.example config/agent.local.env" >&2
    rc=1
  fi

  # Leave no trace when sourced (mirrors load-model-env.sh): drop the names
  # this file defines. Done before returning so the source status survives.
  unset load_env_main _load_env_export
  return "$rc"
}

load_env_main "$@"
