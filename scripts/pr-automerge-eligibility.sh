#!/bin/bash
# pr-automerge-eligibility.sh — Decide whether a PR may arm native auto-merge.
#
# The rules are evaluated in a fixed order, first match wins:
#   1. size tier not `auto`          -> eligible=false, reason=size_<tier>
#   2. review verdict not `pass`     -> eligible=false, reason=review_not_pass
#   3. an excluded changed path      -> eligible=false, reason=excluded_path
#   4. mode `report`                 -> eligible=true, comment_only, report_only
#   5. otherwise                     -> eligible=true, action=merge, all_green
#
# Exclusion classes, checked against every changed path in this order:
#   gate_surface          .github/workflows/, agents/, scripts/check-*, opencode.json
#   auth_secret           auth/authn/authz/secrets/keys segments, secret-shaped
#                         basenames, .env and .env.*
#   db_migration          migrations/migrate/alembic/db/migrate segments, versioned
#                         and numbered .sql migrations
#   dependency_manifest   dependency manifests and lockfiles
#
# There is deliberately no repository name, slug, owner/repo, or per-repo
# allowlist input: identical inputs produce identical output in every repo.
#
# Usage:
#   scripts/pr-automerge-eligibility.sh --size-tier <auto|human|blocked|override>
#     --review-verdict <pass|findings|missing|malformed>
#     --changed-files <path|-> --mode <report|live>
#
# Output: exactly one line per key — eligible, action, reason, exclusions.
# Exit codes: 0 evaluated (including ineligible), 2 usage or input error.
#
# Standards reference:
#   specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-06-*.md
#   docs/CI_CD.md §PR Size Gate and Review-Gated Auto-Merge
set -euo pipefail

# shellcheck source=pr-gate-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-gate-lib.sh"

SIZE_TIER=""
REVIEW_VERDICT=""
CHANGED_FILES=""
MODE=""

die() { printf 'pr-automerge-eligibility: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --size-tier)     SIZE_TIER="${2:-}"; shift 2 ;;
    --review-verdict) REVIEW_VERDICT="${2:-}"; shift 2 ;;
    --changed-files) CHANGED_FILES="${2:-}"; shift 2 ;;
    --mode)          MODE="${2:-}"; shift 2 ;;
    --help)
      printf 'usage: scripts/pr-automerge-eligibility.sh --size-tier <auto|human|blocked|override> --review-verdict <pass|findings|missing|malformed> --changed-files <path|-> --mode <report|live>\n'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$SIZE_TIER" ] || die "--size-tier is required"
[ -n "$REVIEW_VERDICT" ] || die "--review-verdict is required"
[ -n "$CHANGED_FILES" ] || die "--changed-files is required"
[ -n "$MODE" ] || die "--mode is required"

case "$SIZE_TIER" in
  auto|human|blocked|override) ;;
  *) die "--size-tier must be auto, human, blocked, or override (got '$SIZE_TIER')" ;;
esac
case "$REVIEW_VERDICT" in
  pass|findings|missing|malformed) ;;
  *) die "--review-verdict must be pass, findings, missing, or malformed (got '$REVIEW_VERDICT')" ;;
esac
case "$MODE" in
  report|live) ;;
  *) die "--mode must be report or live (got '$MODE')" ;;
esac

if [ "$CHANGED_FILES" = "-" ]; then
  PATHS_TEXT="$(cat)"
else
  [ -r "$CHANGED_FILES" ] || die "cannot read changed-files list: $CHANGED_FILES"
  PATHS_TEXT="$(cat "$CHANGED_FILES")"
fi

is_gate_surface() { # is_gate_surface <path>
  case "$1" in
    .github/workflows/*|agents/*|scripts/check-*|opencode.json) return 0 ;;
  esac
  return 1
}

is_auth_secret() { # is_auth_secret <path> <basename>
  case "/$1/" in
    */auth/*|*/authn/*|*/authz/*|*/secrets/*|*/keys/*) return 0 ;;
  esac
  case "$2" in
    .env|.env.*) return 0 ;;
    *auth*|*secret*|*credential*|*password*|*apikey*|*api_key*|*token*) return 0 ;;
  esac
  return 1
}

is_db_migration() { # is_db_migration <path> <basename>
  case "/$1/" in
    */migrations/*|*/migrate/*|*/alembic/*) return 0 ;;
  esac
  if [[ "$2" =~ ^V[0-9]+__.*\.sql$ ]]; then return 0; fi
  if [[ "$2" =~ ^[0-9]{3,}[-_].*\.sql$ ]]; then return 0; fi
  return 1
}

is_dependency_manifest() { # is_dependency_manifest <basename>
  case "$1" in
    package.json|go.mod|pom.xml|build.gradle|build.gradle.kts|Cargo.toml|pyproject.toml|setup.py|setup.cfg|requirements.txt|requirements-*.txt|Gemfile|composer.json|*.csproj|mix.exs|pubspec.yaml) return 0 ;;
  esac
  if is_lockfile "$1"; then return 0; fi
  return 1
}

# exclusion_rule <path> — the first matching exclusion class, or empty.
exclusion_rule() {
  local path="$1" base
  base="$(basename_of "$path")"
  if is_gate_surface "$path"; then printf 'gate_surface'; return 0; fi
  if is_auth_secret "$path" "$base"; then printf 'auth_secret'; return 0; fi
  if is_db_migration "$path" "$base"; then printf 'db_migration'; return 0; fi
  if is_dependency_manifest "$base"; then printf 'dependency_manifest'; return 0; fi
  return 0
}

collect_exclusions() {
  local path rule
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rule="$(exclusion_rule "$path")"
    [ -n "$rule" ] || continue
    if [ -n "$EXCLUSIONS" ]; then EXCLUSIONS="$EXCLUSIONS $rule:$path"; else EXCLUSIONS="$rule:$path"; fi
  done <<< "$PATHS_TEXT"
}

EXCLUSIONS=""
collect_exclusions

# ── Rule order: size, verdict, exclusion, mode, all green ───────────────────
ELIGIBLE=false
ACTION=none
REASON=""

if [ "$SIZE_TIER" != auto ]; then
  REASON="size_$SIZE_TIER"
elif [ "$REVIEW_VERDICT" != pass ]; then
  REASON="review_not_pass"
elif [ -n "$EXCLUSIONS" ]; then
  REASON="excluded_path"
elif [ "$MODE" = report ]; then
  ELIGIBLE=true
  ACTION=comment_only
  REASON="report_only"
else
  ELIGIBLE=true
  ACTION=merge
  REASON="all_green"
fi

printf 'eligible=%s\naction=%s\nreason=%s\nexclusions=%s\n' \
  "$ELIGIBLE" "$ACTION" "$REASON" "${EXCLUSIONS:-none}"
exit 0
