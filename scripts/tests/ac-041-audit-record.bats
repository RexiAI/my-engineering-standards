#!/usr/bin/env bats
# ac-041-audit-record.bats — acceptance tests for spec 041 Task 7
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-audit-record.md).
#
# The record lives in 10-tasks.md §Measured before/after so archive-spec.sh
# carries it into docs/changes/041-pipeline-token-savings.md verbatim.

load test_helper
bats_require_minimum_version 1.5.0

TASKS="$REPO_ROOT/specs/041-pipeline-token-savings/10-tasks.md"
# Stacked base: spec/038's tip, the commit this spec branches from (037 and 038
# already landed there). Re-pin if the stack is rebased.
BASE_COMMIT="4dbf164"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# measured_table — the `## Measured before/after` table rows, separator excluded.
measured_table() {
  awk '
    /^## Measured before\/after/ { inblock = 1; next }
    inblock && /^## / { exit }
    inblock && /^\| / { print }
  ' "$TASKS"
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
  grep -q 'Baseline command or fixture' "$TASKS"
}

@test "AC-041-51 — every rejected item carries its reason" {
  local row4
  row4="$(item_rows | grep '^| 4 |')"
  [ -n "$row4" ]
  [[ "$row4" == *"rejected"* ]]
  [[ "$row4" == *"premise is false"* ]]
  grep -q 'agents/pr-review.md:69' "$TASKS"
  grep -q 'D3' "$TASKS"
  grep -q "Coder's/Refactorer's own suite runs" "$TASKS"
}

@test "AC-041-52 — every gate named in the record is green" {
  local gate
  for gate in 'make test' 'scripts/check-doc-section-refs.sh' \
              'scripts/check-agent-line-cap.sh' 'scripts/check-orchestration.sh' \
              'scripts/check-skills.sh' 'scripts/check-scenario-traceability.sh' \
              'scripts/check-code-principles.sh'; do
    grep -qF "$gate" "$TASKS"
  done
  grep -q 'Gate results at hand-off' "$TASKS"
  # Each recorded gate line carries its exit code.
  [ "$(grep -cE '^[a-z].*exit 0$' <<< "$(sed -n '/## Gate results at hand-off/,$p' "$TASKS")")" -ge 7 ]
}

@test "AC-041-53 — no gate script or threshold changed" {
  local script
  git -C "$REPO_ROOT" cat-file -e "$BASE_COMMIT^{commit}"
  for script in scripts/check-audit-trail.sh scripts/check-scenario-traceability.sh \
                scripts/check-code-principles.sh scripts/check-agent-line-cap.sh; do
    run git -C "$REPO_ROOT" diff --quiet "$BASE_COMMIT" -- "$script"
    [ "$status" -eq 0 ]
  done
  grep -q 'complexity 6' "$TASKS"
  grep -q 'mutation ≥80%' "$TASKS"
  grep -q 'agent cap 120' "$TASKS"
}

@test "AC-041-54 — the no-weakening claims are stated, not implied" {
  local decisions flat
  decisions="$(sed -n '/## Recorded decisions/,/## Measured before\/after/p' "$TASKS")"
  flat="$(tr '\n' ' ' <<< "$decisions" | tr -s ' ')"
  [[ "$flat" == *"design-principles gate's contract requires every FAIL/WARN line verbatim"* ]]
  [[ "$flat" == *"both lanes stay raw, invoked directly"* ]]
  [[ "$flat" == *"Reuse is granted only on an exact hash match"* ]]
  [[ "$flat" == *"failure mode is a redundant run, never a skipped one"* ]]
}
