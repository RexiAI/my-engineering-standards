#!/bin/bash
# archive-spec.sh — Post-merge spec folder cleanup. One-pager to docs/changes/.
#
# After the spec pipeline's PR is merged, the spec folder is no longer needed
# on main — its content lives in the code (acceptance tests), the PR (review),
# and now this one-pager. This script writes a single docs/changes/NNN-slug.md
# and removes specs/NNN-slug/.
#
# Usage:
#   ./.standards/scripts/archive-spec.sh NNN-slug
#   e.g. ./.standards/scripts/archive-spec.sh 001-discount-system
#
# Run from the repo root, AFTER the PR is merged into main. The previous
# `spec/NNN-slug` branch can be deleted before or after — this script reads
# from the working tree, not the branch.
#
# Exit codes:
#   0 — archive written, spec folder removed, ready to commit
#   1 — missing inputs or write failed
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Archive on merge
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
  echo "  Run this AFTER the spec pipeline's PR is merged into main." >&2
  exit 1
fi

if [ ! -f "$SPEC_DIR/00-informal.md" ] && [ ! -f "$SPEC_DIR/10-tasks.md" ]; then
  echo "ERROR: $SPEC_DIR looks empty (no 00-informal.md or 10-tasks.md)." >&2
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
