#!/bin/bash
# archive-spec.sh — Move a finished spec to docs/changes/. One-pager archive.
#
# A finished spec's content lives in the code (acceptance tests), the PR
# (review), and now this one-pager. This script writes a single
# docs/changes/NNN-slug.md and removes specs/NNN-slug/.
#
# Primary caller is the spec pipeline's stage 5b (PR Opener): the archive rides
# inside the spec PR, so the merge lands main with the spec already archived —
# no post-merge step needed. Humans may also run it manually for legacy specs
# already merged without an archive.
#
# A spec may only be archived when it is finished (has 30-report.md, written by
# the Mutation Runner) — archiving mid-pipeline is refused.
#
# Usage:
#   ./.standards/scripts/archive-spec.sh NNN-slug
#   e.g. ./.standards/scripts/archive-spec.sh 001-discount-system
#
# Run from the repo root on the spec branch (stage 5b) or after a legacy merge
# (manual). The script reads from the working tree; it stages the moves and
# prints the commit message to run — it does not commit or push.
#
# Exit codes:
#   0 — archive written, spec folder removed, ready to commit
#   1 — missing inputs, spec not finished, or write failed
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Archive in the PR
#   docs/SPEC_PIPELINE.md §Commit and push carve-out
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: archive-spec.sh NNN-slug" >&2
  echo "  e.g. archive-spec.sh 001-discount-system" >&2
  exit 1
fi

SLUG="$1"
SPEC_DIR="specs/$SLUG"
CHANGES_DIR="docs/changes"
ARCHIVE="$CHANGES_DIR/$SLUG.md"

if [ ! -d "$SPEC_DIR" ]; then
  echo "ERROR: $SPEC_DIR does not exist." >&2
  echo "  Run this on the spec branch (stage 5b) or after a legacy merge." >&2
  exit 1
fi

if [ ! -f "$SPEC_DIR/00-informal.md" ] && [ ! -f "$SPEC_DIR/10-tasks.md" ]; then
  echo "ERROR: $SPEC_DIR looks empty (no 00-informal.md or 10-tasks.md)." >&2
  exit 1
fi

# Only finished specs may be archived: 30-report.md is the Mutation Runner's
# final artifact. Refuse mid-pipeline archives so stage 5b cannot run too early.
if [ ! -f "$SPEC_DIR/30-report.md" ]; then
  echo "ERROR: $SPEC_DIR has no 30-report.md — the spec is not finished." >&2
  echo "  Archive only after the Mutation Runner produced a green 30-report.md." >&2
  exit 1
fi

mkdir -p "$CHANGES_DIR"

# Read input files (best-effort: missing files are skipped, not fatal).
read_file() { [ -f "$1" ] && cat "$1" || echo "_(not produced)_"; }

INFORMAL=$(read_file "$SPEC_DIR/00-informal.md")
TASKS=$(read_file "$SPEC_DIR/10-tasks.md")
VERIFICATION=$(read_file "$SPEC_DIR/25-verification.md")
REPORT=$(read_file "$SPEC_DIR/30-report.md")

# Scenario IDs from 20-acceptance/* — full heading lines, deduped.
SCENARIOS=""
if [ -d "$SPEC_DIR/20-acceptance" ]; then
  SCENARIOS=$(grep -hE '^## AC-[0-9]{3}-[0-9]{2}' "$SPEC_DIR"/20-acceptance/*.md 2>/dev/null \
    | sort -u || true)
fi

# --- Compose the one-pager ---------------------------------------------------
{
  echo "# $SLUG"
  echo ""
  echo "> Spec pipeline archive. Original source: \`$SPEC_DIR/\` (deleted by this script)."
  echo "> Archived: $(date -I)"
  echo ""
  echo "## Original ask"
  echo ""
  echo "$INFORMAL"
  echo ""
  echo "## Tasks"
  echo ""
  echo "$TASKS"
  echo ""
  echo "## Acceptance scenarios"
  echo ""
  if [ -n "$SCENARIOS" ]; then
    echo "$SCENARIOS"
  else
    echo "_(none)_"
  fi
  echo ""
  echo "## Verification"
  echo ""
  echo "$VERIFICATION"
  echo ""
  echo "## Quality gates"
  echo ""
  echo "$REPORT"
} > "$ARCHIVE"

# --- Cleanup ------------------------------------------------------------------
git rm -r "$SPEC_DIR" >/dev/null
git add "$ARCHIVE"

echo "✔ Wrote $ARCHIVE"
echo "✔ Removed $SPEC_DIR (staged)"
echo ""
echo "Next: git commit -m 'docs(changes): archive $SLUG' && git push"
