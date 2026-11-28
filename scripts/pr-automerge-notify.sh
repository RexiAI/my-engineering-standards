#!/bin/bash
# pr-automerge-notify.sh — Render the human notification comment body for the
# auto-merge decision. Prints to stdout and exits 0; it never posts, never
# merges, and never reads a secret.
#
# Usage:
#   scripts/pr-automerge-notify.sh --outcome <armed|would-merge|blocked-exclusion>
#     [--size-tier <auto|human|blocked|override>]
#     [--review-verdict <pass|findings|missing|malformed>]
#     [--exclusions <none|rule:path ...>] [--codeowners-file <path|none>]
#     [--repo-owner <login>] [--head-sha <sha>]
#
# Mentions: every distinct individual @user handle in the CODEOWNERS file is
# mentioned; with no file or no individual handle, the body mentions
# @<repo-owner> instead. Team handles (@org/team) are neither invented nor
# expanded.
#
# Every body ends with the idempotency marker
#   <!-- pr-automerge: <outcome>:<head-sha> -->
# so the workflow can suppress a duplicate comment for the same head.
#
# Exit codes: 0 rendered, 2 usage error.
#
# Standards reference:
#   specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-09-*.md
#   docs/CI_CD.md §PR Size Gate and Review-Gated Auto-Merge
set -euo pipefail

# shellcheck source=pr-gate-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pr-gate-lib.sh"

OUTCOME=""
SIZE_TIER="unknown"
REVIEW_VERDICT="unknown"
EXCLUSIONS="none"
CODEOWNERS_FILE="none"
REPO_OWNER=""
HEAD_SHA=""

die() { printf 'pr-automerge-notify: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --outcome)        OUTCOME="${2:-}"; shift 2 ;;
    --size-tier)      SIZE_TIER="${2:-}"; shift 2 ;;
    --review-verdict) REVIEW_VERDICT="${2:-}"; shift 2 ;;
    --exclusions)     EXCLUSIONS="${2:-}"; shift 2 ;;
    --codeowners-file) CODEOWNERS_FILE="${2:-}"; shift 2 ;;
    --repo-owner)     REPO_OWNER="${2:-}"; shift 2 ;;
    --head-sha)       HEAD_SHA="${2:-}"; shift 2 ;;
    --help)
      printf 'usage: scripts/pr-automerge-notify.sh --outcome <armed|would-merge|blocked-exclusion> [--size-tier <tier>] [--review-verdict <verdict>] [--exclusions <none|list>] [--codeowners-file <path|none>] [--repo-owner <login>] [--head-sha <sha>]\n'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

case "$OUTCOME" in
  armed|would-merge|blocked-exclusion) ;;
  *) die "--outcome must be armed, would-merge, or blocked-exclusion (got '$OUTCOME')" ;;
esac

# ── Mentions: distinct individual handles, first appearance wins ─────────────
individual_handles() {
  local file="$1" token
  [ "$file" != none ] || return 0
  [ -f "$file" ] || return 0
  while IFS= read -r token; do
    case "$token" in
      @*/*) continue ;;
      @*)   printf '%s\n' "$token" ;;
    esac
  done < <(codeowners_tokens "$file")
}

MENTIONS=""
while IFS= read -r handle; do
  [ -n "$handle" ] || continue
  case " $MENTIONS " in *" $handle "*) continue ;; esac
  if [ -n "$MENTIONS" ]; then MENTIONS="$MENTIONS $handle"; else MENTIONS="$handle"; fi
done < <(individual_handles "$CODEOWNERS_FILE")

if [ -z "$MENTIONS" ] && [ -n "$REPO_OWNER" ]; then
  MENTIONS="@$REPO_OWNER"
fi

# ── Body ────────────────────────────────────────────────────────────────────
emit_header() { # <heading> <lead>
  printf '## %s\n\n' "$1"
  if [ -n "$MENTIONS" ]; then printf '%s — %s\n\n' "$MENTIONS" "$2"; else printf '%s\n\n' "$2"; fi
}

emit_exclusions() {
  [ "$EXCLUSIONS" = none ] && return 0
  [ -n "$EXCLUSIONS" ] || return 0
  printf 'Matching exclusion rules:\n'
  local entry
  for entry in $EXCLUSIONS; do
    printf '  - %s\n' "${entry/:/ : }"
  done
  printf '\n'
}

case "$OUTCOME" in
  armed)
    emit_header "Auto-merge armed" "auto-merge is armed and will merge this PR once every required check passes."
    printf 'The merge waits for the required checks: `pr-size`, `review-verdict`, CI, and `mutation` when the tier requires it.\n\n'
    ;;
  would-merge)
    emit_header "Auto-merge would have merged" "this PR would have auto-merged, but the repository mode is report-only, so nothing was merged."
    ;;
  blocked-exclusion)
    emit_header "Auto-merge blocked by an exclusion" "this PR matches an auto-merge exclusion, so a human must review and merge the PR."
    emit_exclusions
    ;;
esac

printf 'Size: tier=%s\n' "$SIZE_TIER"
printf 'Review: verdict=%s\n' "$REVIEW_VERDICT"
printf '\n<!-- pr-automerge: %s:%s -->\n' "$OUTCOME" "$HEAD_SHA"
