#!/bin/bash
# pr-gate-lib.sh — shared helpers for the spec-045 PR gate scripts.
#
# Sourced (never executed) by pr-size-gate.sh, pr-automerge-eligibility.sh, and
# pr-automerge-notify.sh. It holds the knowledge those scripts must agree on:
# which basenames are lockfiles, how a path's basename is taken, and how a
# CODEOWNERS file is tokenized. Nothing here writes a file or touches the
# network.
#
# Standards reference:
#   docs/CI_CD.md §PR Size Gate and Review-Gated Auto-Merge

basename_of() { printf '%s' "${1##*/}"; }

# Lockfile basenames, matched exactly. The size gate excludes them from the
# changed-line count; the auto-merge predicate treats them as dependency
# manifests. One list, so a new package manager cannot update one policy and
# silently miss the other.
is_lockfile() {
  case "$1" in
    package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|bun.lock|bun.lockb|go.sum|Cargo.lock|poetry.lock|Pipfile.lock|Gemfile.lock|composer.lock|mix.lock|pubspec.lock|pdm.lock|uv.lock|packages.lock.json|flake.lock) return 0 ;;
  esac
  return 1
}

# codeowners_tokens <file> — every @token in a CODEOWNERS file, one per line,
# with comments stripped. Team handles (@org/team) are printed too: each caller
# decides whether a team can stand in for an individual.
codeowners_tokens() {
  sed 's/#.*//' "$1" | tr -s ' \t' '\n' | grep '^@' || true
}
