#!/bin/bash
# guard-env.sh — Refuse to commit the real per-machine env file.
#
# The per-machine credentials file (config/agent.local.env) must never reach
# git: it holds real token values. The committed example
# (config/agent.local.env.example) carries placeholders only and is always
# trackable. This guard is the enforcement point of record:
#   - default mode (CI): refuses when the real file is TRACKED — a forced-add
#     or a previously-committed real file. Runs in self-ci on every push/PR.
#   - --staged mode (pre-commit hook): refuses when the real file is STAGED.
#     Child repos wire it into .githooks/pre-commit per docs/GIT_WORKFLOW.md
#     §Git Hooks (git config core.hooksPath .githooks).
#
# Usage:
#   scripts/guard-env.sh [--staged] [REPO_ROOT]
# REPO_ROOT defaults to the current directory (git resolves the enclosing repo;
# CI and pre-commit hooks both run from the repo root). Pass a scratch repo's
# root to check it in isolation without touching the caller's repo (selftest).
#
# Exit codes:
#   0 — no real env file in the scanned set (brief PASS line)
#   1 — real file present in the scanned set (message names the path)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

REAL_ENV_FILE="config/agent.local.env"

guard_env_main() {
  local MODE=tracked ROOT="" arg files hint mode_word
  for arg in "$@"; do
    case "$arg" in
      --staged)
        MODE=staged
        ;;
      *)
        if [ -z "$ROOT" ]; then
          ROOT="$arg"
        else
          echo "usage: guard-env.sh [--staged] [REPO_ROOT]" >&2
          exit 2
        fi
        ;;
    esac
  done
  ROOT="${ROOT:-$(pwd)}"

  if [ "$MODE" = staged ]; then
    files="$(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMRT)"
    mode_word=staged
    hint="Unstage it (git reset $REAL_ENV_FILE) before committing."
  else
    files="$(git -C "$ROOT" ls-files)"
    mode_word=tracked
    hint="Remove it from tracking (git rm --cached $REAL_ENV_FILE); the .gitignore rule keeps it out from then on."
  fi

  if printf '%s\n' "$files" | grep -qx "$REAL_ENV_FILE"; then
    echo -e "${RED}FAIL${NC} guard-env: $REAL_ENV_FILE is $mode_word — the real env file must never be committed. $hint"
    exit 1
  fi

  echo -e "${GREEN}PASS${NC} guard-env: no $REAL_ENV_FILE in the scanned set ($MODE mode)."
  exit 0
}

guard_env_main "$@"
