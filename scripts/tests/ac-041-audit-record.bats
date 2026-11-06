#!/usr/bin/env bats
# ac-041-audit-record.bats — acceptance tests for spec 041 Task 7
# (AC-041-audit-record.md).
#
# The record lives in 10-tasks.md §Measured before/after, which archive-spec.sh
# carries into docs/changes/041-pipeline-token-savings.md verbatim. Resolve the
# live spec folder first (pre-archive) and the archived one-pager second
# (post-archive, i.e. every run on the branch after stage 5d, including CI):
# same text, two homes — the assertions read whichever exists.

load test_helper
bats_require_minimum_version 1.5.0

SPEC_RECORD="$REPO_ROOT/specs/041-pipeline-token-savings/10-tasks.md"
ARCHIVE_RECORD="$REPO_ROOT/docs/changes/041-pipeline-token-savings.md"
if [ -f "$SPEC_RECORD" ]; then
  RECORD="$SPEC_RECORD"
else
  RECORD="$ARCHIVE_RECORD"
fi

# Stacked base: spec/038's tip, the commit this spec branches from (037 and 038
# already landed there). Re-pin if the stack is rebased.
PINNED_BASE="4dbf164"

# base_commit — the commit the gate-script immutability check diffs against.
# The pinned stacked base when the clone carries it: that is the strict path,
# and it is the one a full clone takes. actions/checkout fetches a single
# commit on CI, which has neither the pinned object nor origin/main, so fall
# back to the merge-base with any base branch the clone does carry. Returns 1
# when the clone genuinely carries no base — the caller skips rather than
# passing vacuously.
base_commit() {
  local ref merge_base
  # Prefer the merge-base with a base branch: once the branch has merged main
  # (the normal stacked-PR resolution), the pinned sha still exists locally but
  # no longer frames this branch's own changes.
  for ref in origin/main origin/master main master; do
    git -C "$REPO_ROOT" rev-parse --verify -q "${ref}^{commit}" >/dev/null 2>&1 || continue
    merge_base="$(git -C "$REPO_ROOT" merge-base HEAD "$ref" 2>/dev/null || true)"
    if [ -n "$merge_base" ]; then
      printf '%s\n' "$merge_base"
      return 0
    fi
  done
  if git -C "$REPO_ROOT" rev-parse --verify -q "${PINNED_BASE}^{commit}" >/dev/null 2>&1; then
    printf '%s\n' "$PINNED_BASE"
    return 0
  fi
  return 1
}

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# measured_table — the `## Measured before/after` table rows, separator excluded.
measured_table() {
  awk '
    /^## Measured before\/after/ { inblock = 1; next }
    inblock && /^## / { exit }
    inblock && /^\| / { print }
  ' "$RECORD"
}

# item_rows — the table's data rows (those whose first cell is a number).
item_rows() {
  measured_table | grep -E '^\| [0-9]+ \|'
}

@test "AC-041-50 — one measured row per informal item" {
  local rows count
  rows="$(item_rows)"
  count="$(grep -c '^| ' <<< "$rows")"
  [ "$count" -eq 4 ]
  while IFS= read -r row; do
    # baseline command/fixture, before, after, status — the four required cells
    # are non-empty once split on pipes.
    [ "$(awk -F'|' '{ print NF }' <<< "$row")" -ge 8 ]
    [[ "$row" =~ \|[[:space:]]*implemented ]] || [[ "$row" =~ \|[[:space:]]*rejected ]]
  done <<< "$rows"
  grep -q 'Baseline command or fixture' "$RECORD"
}

@test "AC-041-51 — every rejected item carries its reason" {
  local row4
  row4="$(item_rows | grep '^| 4 |')"
  [ -n "$row4" ]
  [[ "$row4" == *"rejected"* ]]
  [[ "$row4" == *"premise is false"* ]]
  grep -q 'agents/pr-review.md:69' "$RECORD"
  grep -q 'D3' "$RECORD"
  grep -q "Coder's/Refactorer's own suite runs" "$RECORD"
}

@test "AC-041-52 — every gate named in the record is green" {
  local gate
  for gate in 'make test' 'scripts/check-doc-section-refs.sh' \
              'scripts/check-agent-line-cap.sh' 'scripts/check-orchestration.sh' \
              'scripts/check-skills.sh' 'scripts/check-scenario-traceability.sh' \
              'scripts/check-code-principles.sh'; do
    grep -qF "$gate" "$RECORD"
  done
  grep -q 'Gate results at hand-off' "$RECORD"
  # Each recorded gate line carries its exit code.
  [ "$(grep -cE '^[a-z].*exit 0$' <<< "$(sed -n '/## Gate results at hand-off/,$p' "$RECORD")")" -ge 7 ]
}

@test "AC-041-53 — no gate script or threshold changed" {
  local script base
  if ! base="$(base_commit)"; then
    # Genuinely unavailable: a shallow clone carries neither the pinned base
    # nor a base branch to take a merge-base from, so the diff has no frame.
    # Skipped with the reason stated, never passed vacuously.
    skip "no base commit to diff against: pinned $PINNED_BASE absent and no local base branch for merge-base (shallow clone)"
  fi
  for script in scripts/check-audit-trail.sh scripts/check-scenario-traceability.sh \
                scripts/check-code-principles.sh scripts/check-agent-line-cap.sh; do
    # A gate script added by a stacked base PR (038 adds check-agent-line-cap.sh)
    # does not exist at the base commit, so it cannot have been changed there.
    # Skipping it keeps the claim exact: no gate that existed at base was altered.
    git -C "$REPO_ROOT" cat-file -e "$base:$script" 2>/dev/null || continue
    # Compare the branch's own commits, never the working tree: a merge of main
    # legitimately imports main's changes to the same scripts.
    run git -C "$REPO_ROOT" diff --quiet "$base" HEAD -- "$script"
    [ "$status" -eq 0 ]
  done
  grep -q 'complexity 6' "$RECORD"
  grep -q 'mutation ≥80%' "$RECORD"
  grep -q 'agent cap 120' "$RECORD"
}

@test "AC-041-54 — the no-weakening claims are stated, not implied" {
  local decisions flat
  decisions="$(sed -n '/## Recorded decisions/,/## Measured before\/after/p' "$RECORD")"
  flat="$(tr '\n' ' ' <<< "$decisions" | tr -s ' ')"
  [[ "$flat" == *"design-principles gate's contract requires every FAIL/WARN line verbatim"* ]]
  [[ "$flat" == *"both lanes stay raw, invoked directly"* ]]
  [[ "$flat" == *"Reuse is granted only on an exact hash match"* ]]
  [[ "$flat" == *"failure mode is a redundant run, never a skipped one"* ]]
}
