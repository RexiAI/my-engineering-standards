#!/usr/bin/env bats
# ac-037-references.bats — acceptance tests for spec 037 Task 3
# (specs/037-split-spec-pipeline-doc/20-acceptance/AC-037-03-references.md).
# Moved sections are repointed; index sections keep their old path; every stage
# agent reads only its own slice.

load test_helper
bats_require_minimum_version 1.5.0

DIR="$REPO_ROOT/docs/spec-pipeline"
DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"

# moved-heading|destination-file — the sections that left the index in spec 037
MOVED=(
  "Why a separate Verifier stage|rationale.md"
  "Audit contract|audit-contract.md"
  "Archive in the PR|pr-opener.md"
  "Definition of done|audit-contract.md"
  "Scenario format|specifier.md"
  "The information barrier|rationale.md"
  "Post-PR CI check-and-remediate loop (phase 2)|post-pr-loops.md"
  "Deploy verification loop (phase 3)|deployer.md"
  "Production deploy verification (post-merge)|post-pr-loops.md"
  "Conformance tiers|coder.md"
  "Model configuration|model-config.md"
  "PR review model wiring|model-config.md"
  "Typed-judgment layer|typed-judgment.md"
  "Tooling by language|coder.md"
  "Why no BDD runner|rationale.md"
  "Why no scenario mutation|rationale.md"
)

# search scope for reference rewrites (Task 3)
SCOPE=(agents commands AGENTS.md docs scripts skills)

@test "AC-037-03-01: moved-section references are repointed to the new file" {
  local entry heading dest
  for entry in "${MOVED[@]}"; do
    heading="${entry%|*}"
    dest="${entry#*|}"
    # no stale reference to the index for a moved section
    if grep -rniF "docs/SPEC_PIPELINE.md §$heading" "${SCOPE[@]/#/$REPO_ROOT/}" 2>/dev/null | grep -v '^Binary'; then
      echo "stale reference to moved section: $heading" >&2
      return 1
    fi
    # and the new target is actually cited somewhere
    grep -rqF "docs/spec-pipeline/$dest" "${SCOPE[@]/#/$REPO_ROOT/}" 2>/dev/null || {
      echo "no reference to docs/spec-pipeline/$dest" >&2
      return 1
    }
  done
}

@test "AC-037-03-02: index-section references keep the index path" {
  grep -rqF 'docs/SPEC_PIPELINE.md §Remediation budget' "$REPO_ROOT/agents"
  grep -qF '## Remediation budget' "$DOC"
  grep -rqF 'docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix' "$REPO_ROOT/agents"
  grep -qF '## Stop-and-Ask decision matrix' "$DOC"
}

@test "AC-037-03-03: each stage agent reads its own stage file plus named index sections" {
  local agent stage
  for agent in specifier ux coder refactorer verifier mutation-runner pr-opener deployer; do
    local file="$REPO_ROOT/agents/spec-$agent.md"
    [ -f "$file" ] || { echo "missing agents/spec-$agent.md" >&2; return 1; }
    stage="$DIR/$agent.md"
    grep -qF "docs/spec-pipeline/$agent.md" "$file" || {
      echo "agents/spec-$agent.md does not name its stage file" >&2
      return 1
    }
    # named index sections, not a "read the whole doc" instruction
    grep -qE 'docs/SPEC_PIPELINE\.md`? §(Stages|Artifact layout|Stop-and-Ask|Remediation budget|Commit and push)' "$file" || {
      echo "agents/spec-$agent.md names no index section" >&2
      return 1
    }
    ! grep -qi 'read that doc first' "$file"
    ! grep -qi 'read `docs/SPEC_PIPELINE.md` in full' "$file"
  done
}

@test "unit: the orchestrator's full-index read is intentional and documented" {
  # agents/spec-pipeline.md orchestrates every stage, so unlike a stage agent it
  # reads the index in full — but it must point at the stage-file table.
  grep -qF 'docs/SPEC_PIPELINE.md` in full' "$REPO_ROOT/agents/spec-pipeline.md"
  grep -qF '§Stage files' "$REPO_ROOT/agents/spec-pipeline.md"
}

@test "unit: no moved section is still linked from the AGENTS.md one-liner" {
  local stale="docs/SPEC_PIPELINE.md §Model con""figuration"
  ! grep -qF "$stale" "$REPO_ROOT/AGENTS.md"
  grep -qF 'docs/spec-pipeline/model-config.md §Model configuration' "$REPO_ROOT/AGENTS.md"
}
