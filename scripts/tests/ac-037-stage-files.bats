#!/usr/bin/env bats
# ac-037-stage-files.bats — acceptance tests for spec 037 Task 2
# (specs/037-split-spec-pipeline-doc/20-acceptance/AC-037-02-stage-files.md).
# One file per stage agent, every original top-level section landing exactly
# once, named sections in their owning file, and a back-pointer header.

load test_helper
bats_require_minimum_version 1.5.0

DIR="$REPO_ROOT/docs/spec-pipeline"
DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"

# The top-level `##` headings of docs/SPEC_PIPELINE.md at the 036-merged base
# commit (fence-aware list). Frozen so the assertion is not self-referential
# once the split lands on main.
BASE_HEADINGS=(
  "Stages"
  "Why a separate Verifier stage"
  "Artifact layout"
  "Audit contract"
  "Archive in the PR"
  "Definition of done"
  "Scenario format"
  "The information barrier"
  "Compensating control: catch it, don't just prevent it"
  "Stop-and-Ask decision matrix"
  "Autopilot mode"
  "Commit and push carve-out"
  "Remediation budget"
  "Post-PR CI check-and-remediate loop (phase 2)"
  "Deploy verification loop (phase 3)"
  "Production deploy verification (post-merge)"
  "Conformance tiers"
  "Model configuration"
  "PR review model wiring"
  "Typed-judgment layer"
  "Tooling by language"
  "Why no BDD runner"
  "Why no scenario mutation"
)

STAGE_FILES=(
  specifier ux coder refactorer verifier mutation-runner pr-opener deployer
)

@test "AC-037-02-01: one file per stage agent under docs/spec-pipeline/" {
  [ -d "$DIR" ]
  for stage in "${STAGE_FILES[@]}"; do
    [ -f "$DIR/$stage.md" ] || { echo "missing stage file: $stage.md" >&2; return 1; }
  done
}

@test "AC-037-02-02: every original top-level section lands in exactly one file" {
  local heading count
  for heading in "${BASE_HEADINGS[@]}"; do
    count="$(grep -hxF "## $heading" "$DOC" "$DIR"/*.md | wc -l | tr -d ' ')"
    [ "$count" -eq 1 ] || {
      echo "heading '$heading' appears $count times (expected 1)" >&2
      return 1
    }
  done
}

@test "AC-037-02-03: named sections live in their owning stage file" {
  grep -qxF '## Scenario format' "$DIR/specifier.md"
  grep -qxF '## Conformance tiers' "$DIR/coder.md"
  grep -qxF '## Tooling by language' "$DIR/coder.md"
  grep -qxF '## Archive in the PR' "$DIR/pr-opener.md"
  grep -qxF '## Deploy verification loop (phase 3)' "$DIR/deployer.md"
}

@test "AC-037-02-04: every stage file points back to the index and names its index sections" {
  local stage head5
  for stage in "${STAGE_FILES[@]}"; do
    [ -f "$DIR/$stage.md" ] || { echo "missing $stage.md" >&2; return 1; }
    head5="$(head -5 "$DIR/$stage.md")"
    printf '%s\n' "$head5" | grep -qF 'docs/SPEC_PIPELINE.md' || {
      echo "$stage.md does not reference docs/SPEC_PIPELINE.md in its first 5 lines" >&2
      return 1
    }
    printf '%s\n' "$head5" | grep -q '§' || {
      echo "$stage.md does not name an index section in its first 5 lines" >&2
      return 1
    }
  done
}

@test "unit: shared reference files exist and are referenced from a stage file" {
  for shared in audit-contract model-config rationale typed-judgment post-pr-loops; do
    [ -f "$DIR/$shared.md" ] || { echo "missing shared file: $shared.md" >&2; return 1; }
  done
  grep -qF 'docs/spec-pipeline/audit-contract.md' "$DIR/verifier.md"
  grep -qF 'docs/spec-pipeline/typed-judgment.md' "$DIR/model-config.md"
}
