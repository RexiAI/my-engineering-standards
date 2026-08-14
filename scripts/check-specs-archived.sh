#!/bin/bash
# check-specs-archived.sh — Finished specs must be archived before merge.
#
# The spec pipeline archives a spec by moving it to docs/changes/ inside the
# PR (stage 5b runs scripts/archive-spec.sh). A spec is "finished" once its
# 30-report.md exists (Mutation Runner wrote it). This gate fails when a
# finished spec is still sitting in specs/ with no docs/changes/NNN-slug.md
# archive — i.e. the merge would land pipeline scratch on main.
#
# Uses git ls-files (index-aware) so untracked local scratch under specs/ is
# not policed; only what would actually reach the merge is checked.
#
# Usage:
#   scripts/check-specs-archived.sh
#
# Exit codes:
#   0 — every finished spec has an archive (or no finished specs exist)
#   1 — at least one finished spec lacks its docs/changes/NNN-slug.md archive
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Archive in the PR
set -euo pipefail

fail() { echo -e "\033[31m$*\033[0m"; }
pass() { echo -e "\033[32m$*\033[0m"; }

ERRORS=0

while IFS= read -r report; do
  slug=$(dirname "$report" | sed 's|specs/||')
  archive="docs/changes/$slug.md"
  if ! git ls-files --error-unmatch "$archive" >/dev/null 2>&1; then
    fail "  [FAIL] $slug is finished (has 30-report.md) but not archived — missing $archive"
    echo "         Run: scripts/archive-spec.sh $slug (stage 5b does this automatically)"
    ERRORS=$((ERRORS + 1))
  else
    echo "  [OK] $slug archived -> $archive"
  fi
done < <(git ls-files 'specs/*/30-report.md')

if [ "$ERRORS" -ne 0 ]; then
  fail "$ERRORS finished spec(s) not archived!"
  exit 1
fi

pass "All finished specs archived."
exit 0
