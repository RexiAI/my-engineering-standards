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
#   source scripts/load-env.sh [PROJECT_ROOT]    # or run: bash scripts/load-env.sh [PROJECT_ROOT]
# PROJECT_ROOT is the directory whose config/ holds the env files. It defaults
# to the repo root (parent of scripts/). Pass it explicitly to run against
# scratch fixtures (selftest).
#
# PowerShell twin: scripts/load-env.ps1 — same behavior contract (see its
# header; not executed in CI, kept in sync by hand).
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
  local file="$1" line var
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
            # No-clobber: only export when not already set (non-empty).
            if [ -z "${!var:-}" ]; then
              export "$line"
            fi
            ;;
        esac
        ;;
    esac
  done < "$file"
}

load_env_main() {
  local root="${1:-}"
  local script_dir real example rc=0
  if [ -z "$root" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    root="$(dirname "$script_dir")"
  fi
  real="$root/config/agent.local.env"
  example="$root/config/agent.local.env.example"

  if [ -f "$real" ]; then
    _load_env_export "$real"
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
