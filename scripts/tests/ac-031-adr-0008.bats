#!/usr/bin/env bats
# ac-031-adr-0008.bats — acceptance tests for spec 031 Task 9
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-adr-0008.md).
# docs/GOVERNANCE.md §ADR Requirement makes pipeline-role / gate-artifact /
# billing changes review-blocking — this ADR is that record.

load test_helper
bats_require_minimum_version 1.5.0

ADR="$REPO_ROOT/docs/adr/0008-vercel-deploy-lane.md"
IDX="$REPO_ROOT/docs/adr/README.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-50 — ADR 0008 exists, follows templates/ADR.md structure, and records the four decisions" {
  [ -f "$ADR" ]
  for h in "## Title" "## Status" "## Context" "## Decision" "### Alternatives Considered" "## Consequences" "## Compliance" "## Notes"; do
    grep -qxF -- "$h" "$ADR"
  done
  # every template section, in template order
  flat="$(grep -E '^#{2,3} ' "$ADR" | tr '\n' '|')"
  [[ "$flat" == *"## Title|## Status|## Context|## Decision|### Alternatives Considered|## Consequences|## Compliance|## Notes|"* ]]
  # content: new pipeline role, gate artifact, tail split, billing
  grep -qiF 'spec-deployer' "$ADR"
  grep -qF '40-deploy.md' "$ADR"
  grep -qF '5a/5b/5c/5d' "$ADR"
  grep -qiE 'billing|cost' "$ADR"
  grep -qiF 'Vercel builds cost money' "$ADR"
}

@test "AC-031-51 — ADR 0008 status is Accepted" {
  awk '/^## Status$/{f=1;next} /^## /{f=0} f' "$ADR" | grep -qxF 'Accepted'
}

@test "AC-031-52 — ADR index has a 0008 row with title and link to the file" {
  run grep -F '| 0008 |' "$IDX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(0008-vercel-deploy-lane.md)"* ]]
  [[ "$output" == *"Accepted"* ]]
}

@test "unit — 0008 is the highest ADR number in docs/adr (next after 0007)" {
  ls "$REPO_ROOT/docs/adr" | grep -E '^[0-9]{4}-' | sort | tail -1 | grep -q '^0008'
}
