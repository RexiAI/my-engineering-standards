#!/usr/bin/env bats
# ac-031-pipeline-doc-rewrite.bats — acceptance tests for spec 031 Task 3
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-pipeline-doc-rewrite.md).
# docs/SPEC_PIPELINE.md is the assertion target; section extraction mirrors the
# awk helpers used by check-post-pr-ci-loop.sh.

load test_helper
load ac-031-doc-section
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-11 — stage table lists 5a, 5b (no longer archives), 5c Deploy Verifier (spec-deployer), 5d Archiver (spec-pr-opener)" {
  run section "Stages"
  [[ "$output" == *"| 5a | Mutation Runner | \`spec-mutation-runner\`"* ]]
  [[ "$output" == *"| 5b | PR Opener | \`spec-pr-opener\`"* ]]
  [[ "$output" == *"no longer archives"* ]]
  [[ "$output" == *"| 5c | Deploy Verifier | \`spec-deployer\`"* ]]
  [[ "$output" == *"| 5d | Archiver | \`spec-pr-opener\`"* ]]
  # exactly one 5c row and one 5d row
  [ "$(printf '%s\n' "$output" | grep -c '^| 5c ')" -eq 1 ]
  [ "$(printf '%s\n' "$output" | grep -c '^| 5d ')" -eq 1 ]
}

@test "AC-031-12 — artifact layout lists 40-deploy.md with its deploy-evidence purpose" {
  run section "Artifact layout"
  [[ "$output" == *"40-deploy.md"* ]]
  [[ "$output" == *"deploy"* ]]
  [[ "$output" == *"E2E verdict"* ]]
  [[ "$output" == *"health"* ]]
}

@test "AC-031-13 — definition of done requires 40-deploy.md present with verdict or skip reason" {
  run section "Definition of done"
  [[ "$output" == *"40-deploy.md"* ]]
  [[ "$output" == *"verdict"* ]]
  [[ "$output" == *"skip reason"* ]]
  [[ "$output" == *"Stage 5d"* ]]
  [[ "$output" == *"archive-spec.sh"* ]]
  # the old "Stage 5b ran ... archive" item is gone
  ! grep -q 'Stage 5b ran `scripts/archive-spec.sh`' "$DOC"
}

@test "AC-031-14 — commit-and-push carve-out names stage 5d explicitly alongside 5b" {
  run section "Commit and push carve-out"
  [[ "$output" == *"5d"* ]]
  [[ "$output" == *"5b"* ]]
  [[ "$output" == *"spec/NNN-slug"* ]]
}

@test "AC-031-15 — pipeline-finishes sentence names 5d (the Archiver) as the final act, not 5b" {
  ! grep -qF 'The pipeline finishes at the moment stage 5b pushes the archive commit' "$DOC"
  # sentence may wrap across physical lines — flatten the paragraph first
  sentence="$(tr '\n' ' ' < "$DOC" | grep -oE 'The pipeline finishes at the moment[^.]*\.' | head -1)"
  [[ "$sentence" == *"5d"* ]]
  [[ "$sentence" == *"Archiver"* ]]
  [[ "$sentence" == *"final act"* ]]
  [[ "$sentence" != *"5b"* ]]
}

@test "AC-031-16 — phase ordering: phase-3 deploy verification runs only after phase-2 CI is green, never racing" {
  run grep -iF 'phase-3' "$DOC"
  [ "$status" -eq 0 ]
  # an explicit statement that phase 3 starts only after phase 2 is green
  grep -qiE 'phase[ -]3[^.]*only after[^.]*phase[ -]2' "$DOC"
  grep -qF 'no longer archives' "$DOC"   # 5b row states the archive moved (belt for the table edit)
}

@test "unit — archive section reassigns archive-spec.sh from 5b to 5d" {
  run section "Archive in the PR"
  [[ "$output" == *"Stage 5d"* ]]
  ! printf '%s\n' "$output" | grep -q 'Stage 5b (PR Opener) runs this as its final act'
}
