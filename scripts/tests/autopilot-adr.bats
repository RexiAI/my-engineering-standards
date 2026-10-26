#!/usr/bin/env bats
# autopilot-adr.bats — acceptance tests for spec 035 Task 13
# (specs/035-autopilot-mode/20-acceptance/AC-035-adr.md).
# docs/GOVERNANCE.md §ADR Requirement makes a pipeline-role change
# review-blocking: ADR 0015 is that record.

load test_helper
bats_require_minimum_version 1.5.0

ADR="$REPO_ROOT/docs/adr/0015-autopilot-mode.md"
IDX="$REPO_ROOT/docs/adr/README.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-37 — ADR 0015 exists, follows the template, and records every required decision" {
  [ -f "$ADR" ]
  for h in "## Title" "## Status" "## Context" "## Decision" "### Alternatives Considered" "## Consequences" "## Compliance" "## Notes"; do
    grep -qxF -- "$h" "$ADR"
  done
  flat="$(grep -E '^#{2,3} ' "$ADR" | tr '\n' '|')"
  [[ "$flat" == *"## Title|## Status|## Context|## Decision|### Alternatives Considered|## Consequences|## Compliance|## Notes|"* ]]

  # status is Accepted
  awk '/^## Status$/{f=1;next} /^## /{f=0} f' "$ADR" | grep -qxF 'Accepted'

  # Decision: trigger, ask→decide conversion, stops stay stops, never-list, artifacts
  grep -qF 'SPEC_AUTOPILOT=1' "$ADR"
  grep -qF '/autopilot' "$ADR"
  grep -qiF 'choose the documented default' "$ADR"
  grep -qiF 'stops stay stops' "$ADR"
  grep -qiF 'never-list' "$ADR"
  grep -qF '45-decisions.md' "$ADR"
  grep -qiF 'morning report' "$ADR"

  # Compliance names both enforcement scripts
  grep -qF 'check-stop-and-ask-matrix.sh' "$ADR"
  grep -qF 'check-audit-trail.sh' "$ADR"
}

@test "AC-035-38 — ADR 0015 is indexed with a title and Accepted status" {
  run grep -F '| 0015 |' "$IDX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(0015-autopilot-mode.md)"* ]]
  [[ "$output" == *"Accepted"* ]]
}
