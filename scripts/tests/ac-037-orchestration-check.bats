#!/usr/bin/env bats
# ac-037-orchestration-check.bats — acceptance tests for spec 037 Task 4
# (specs/037-split-spec-pipeline-doc/20-acceptance/AC-037-04-orchestration-check.md).
# check-orchestration.sh must resolve docs/spec-pipeline/*.md paths and every
# `§<Section>` anchor they — and the index — are cited with.

load test_helper
bats_require_minimum_version 1.5.0

CHECK="$REPO_ROOT/scripts/check-orchestration.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# fixture_tree — a minimal measurable tree: index + one stage doc + an agent
fixture_tree() {
  mkdir -p "$TMPDIR_HELPER/agents" "$TMPDIR_HELPER/commands" "$TMPDIR_HELPER/docs/spec-pipeline"
  printf '# Spec Pipeline\n\n## Stages\n\n## Remediation budget\n' \
    > "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md"
  printf '# Coder stage file\n\n## Conformance tiers\n' \
    > "$TMPDIR_HELPER/docs/spec-pipeline/coder.md"
  printf -- '---\ndescription: fixture\n---\n\nNo references yet.\n' \
    > "$TMPDIR_HELPER/agents/spec-fixture.md"
  echo "$TMPDIR_HELPER"
}

@test "AC-037-04-01: the split tree passes check-orchestration" {
  run bash "$CHECK" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All orchestration references valid."* ]]
}

@test "AC-037-04-02: a missing docs/spec-pipeline path is reported and exits 1" {
  local tree; tree="$(fixture_tree)"
  printf -- '---\ndescription: fixture\n---\n\nSee `docs/spec-pipeline/nope.md`.\n' \
    > "$tree/agents/spec-fixture.md"
  run bash "$CHECK" "$tree"
  [ "$status" -eq 1 ]
  [[ "$output" == *"agents/spec-fixture.md"* ]]
  [[ "$output" == *"docs/spec-pipeline/nope.md"* ]]
}

@test "AC-037-04-03: a missing §anchor in a stage doc prints file:line and exits 1" {
  local tree; tree="$(fixture_tree)"
  printf -- '---\ndescription: fixture\n---\n\nSee `docs/spec-pipeline/coder.md §No Such Section`.\n' \
    > "$tree/agents/spec-fixture.md"
  run bash "$CHECK" "$tree"
  [ "$status" -eq 1 ]
  [[ "$output" == *"agents/spec-fixture.md:5"* ]]
  [[ "$output" == *"No Such Section"* ]]
}

@test "AC-037-04-04: an index §anchor that exists resolves and exits 0" {
  local tree; tree="$(fixture_tree)"
  printf -- '---\ndescription: fixture\n---\n\nSee `docs/SPEC_PIPELINE.md §Remediation budget`.\n' \
    > "$tree/agents/spec-fixture.md"
  run bash "$CHECK" "$tree"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All orchestration references valid."* ]]
}

@test "unit: an index §anchor that does not exist is reported" {
  local tree; tree="$(fixture_tree)"
  printf -- '---\ndescription: fixture\n---\n\nSee `docs/SPEC_PIPELINE.md §No Such Section`.\n' \
    > "$tree/agents/spec-fixture.md"
  run bash "$CHECK" "$tree"
  [ "$status" -eq 1 ]
  [[ "$output" == *"docs/SPEC_PIPELINE.md §No Such Section"* ]]
}

@test "unit: a heading that is a prefix of another word does not resolve" {
  local tree; tree="$(fixture_tree)"
  printf -- '---\ndescription: fixture\n---\n\nSee `docs/SPEC_PIPELINE.md §StagesExtra`.\n' \
    > "$tree/agents/spec-fixture.md"
  run bash "$CHECK" "$tree"
  [ "$status" -eq 1 ]
}
