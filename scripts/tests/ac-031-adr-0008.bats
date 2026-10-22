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

# Amended on fix/audit-trail-require-deploy (ADR 0010): this case pinned "0008
# highest" at spec 031's writing time, but the ADR Requirement in
# docs/GOVERNANCE.md makes later ADRs mandatory for later gate changes (0009
# arrives with PR #95, 0010 records this fix's --require-deploy split). The
# durable intent — 0008 exists and every ADR file carries a 4-digit number —
# is what is asserted now; no case deleted.
@test "unit — docs/adr carries the numbered 0008 file and all ADR files use 4-digit numbers (0008 pinned at spec 031's time)" {
  ls "$REPO_ROOT/docs/adr" | grep -qE '^0008-[a-z0-9-]+\.md$'
  ! ls "$REPO_ROOT/docs/adr" | grep -E '^[0-9]{4}-' | grep -vE '^[0-9]{4}-[A-Za-z0-9._-]+\.md$' | grep -q .
}

@test "unit — ADR 0010 (--require-deploy gate split) exists, carries every template heading, and is indexed" {
  local a="$REPO_ROOT/docs/adr/0010-audit-trail-require-deploy-flag.md"
  [ -f "$a" ]
  for h in "## Title" "## Status" "## Context" "## Decision" "### Alternatives Considered" "## Consequences" "## Compliance" "## Notes"; do
    grep -qxF -- "$h" "$a"
  done
  run grep -F '| 0010 |' "$IDX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(0010-audit-trail-require-deploy-flag.md)"* ]]
}
