#!/bin/bash
# check-specs-archived.sh — Finished specs must be archived before merge.
#
# The spec pipeline archives a spec by moving it to docs/changes/ inside the
# PR (stage 5d, the Archiver, runs scripts/archive-spec.sh — spec 031 moved the
# archive from 5b so it is the genuinely final act, after deploy verification).
# A spec is "finished" once its
# 30-report.md exists (Mutation Runner wrote it). This gate fails when a
# finished spec is still sitting in specs/ with no docs/changes/NNN-slug.md
# archive — i.e. the merge would land pipeline scratch on main. Exception
# (spec 031): a 40-deploy.md recording phase-3 budget exhaustion defers the
# archive to the human and is not a gate failure.
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
  if git ls-files --error-unmatch "$archive" >/dev/null 2>&1; then
    echo "  [OK] $slug archived -> $archive"
    continue
  fi
  # Spec 031 exception: a spec whose 40-deploy.md records phase-3 budget
  # exhaustion (marker text or Verdict: ESCALATED) was STOPPED before stage 5d
  # by design — the pipeline halted and escalated to the human, so non-archival
  # is the correct end state, not a violation. Index-aware (git show :path),
  # same source of truth as the archive check itself.
  deploy_content="$(git show ":specs/$slug/40-deploy.md" 2>/dev/null || true)"
  if printf '%s' "$deploy_content" | grep -qE 'Phase-3 budget exhausted|Verdict:[[:space:]]*ESCALATED'; then
    pass "  [OK] $slug phase-3 budget exhausted (40-deploy.md records escalation) — archival deferred to the human"
    continue
  fi
  fail "  [FAIL] $slug is finished (has 30-report.md) but not archived — missing $archive"
  echo "         Run: scripts/archive-spec.sh $slug (stage 5d does this automatically)"
  ERRORS=$((ERRORS + 1))
done < <(git ls-files 'specs/*/30-report.md')

if [ "$ERRORS" -ne 0 ]; then
  fail "$ERRORS finished spec(s) not archived!"
  exit 1
fi

pass "All finished specs archived."
exit 0
