#!/usr/bin/env bats
# ac-031-phase3-budget-routing.bats — acceptance tests for spec 031 Task 6
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-phase3-budget-routing.md).
# Phase-3 budget + fix-routing live in docs/SPEC_PIPELINE.md; the deploy row
# lives in the Stop-and-Ask matrix; refusal behavior lives in
# agents/spec-deployer.md.

load test_helper
load ac-031-doc-section
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"
AGENT="$REPO_ROOT/agents/spec-deployer.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-28 — phase-3 counter is its own max-3 budget, independent of phase 1 and phase 2" {
  flat="$(section 'Deploy verification loop (phase 3)' | tr '\n' ' ')"
  [[ "$flat" == *"Phase 3"* ]]
  [[ "$flat" == *"max 3"* ]]
  [[ "$flat" == *"independent of **Phase 1**"* ]]
  [[ "$flat" == *"Phase 2"* ]]
  [[ "$flat" == *"exhaustion of one does not consume another's budget"* ]]
}

@test "AC-031-29 — 3rd failure stops the pipeline before 5d, relays 40-deploy.md evidence verbatim, escalates" {
  flat="$(section 'Deploy verification loop (phase 3)' | tr '\n' ' ')"
  [[ "$flat" == *"3rd"* ]]
  [[ "$flat" == *"STOP"*"before stage 5d"* ]]
  [[ "$flat" == *"failing check IDs"* ]]
  [[ "$flat" == *"verbatim"* ]]
  [[ "$flat" == *"escalates to the human"* ]]
  [[ "$flat" == *"Phase-3 budget exhausted"* ]]
  [[ "$flat" == *"Verdict: ESCALATED"* ]]
}

@test "AC-031-30 — E2E runner non-zero routes to spec-coder" {
  run section 'Deploy verification loop (phase 3)'
  [[ "$output" =~ E2E\ test\ runner\ exits\ non-zero.*spec-coder ]]
}

@test "AC-031-31 — Vercel configuration-classified error routes to spec-deployer retry" {
  run section 'Deploy verification loop (phase 3)'
  [[ "$output" =~ configuration-classified\ error.*spec-deployer\ retries\ itself ]]
}

@test "AC-031-32 — structural/complexity gate failure routes to spec-refactorer" {
  run section 'Deploy verification loop (phase 3)'
  [[ "$output" =~ [Ss]tructural.*complexity\ gate\ failure.*spec-refactorer ]]
}

@test "AC-031-33 — ambiguous BUILD_FAILED with no clear diagnostic escalates to the human, no invented heuristic" {
  flat="$(section 'Deploy verification loop (phase 3)' | tr '\n' ' ')"
  [[ "$flat" == *"BUILD_FAILED"* ]]
  [[ "$flat" == *"clearly code-diagnostic or config-diagnostic pattern"* ]]
  [[ "$flat" == *"escalate to the human"* ]]
  ! grep -qF 'parses the Vercel build log with grep patterns' "$DOC"
}

@test "AC-031-34 — Stop-and-Ask matrix has the deploy row with the fix-routing action" {
  run grep -F '| Deploy verification fails |' "$DOC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Route per fix-routing rule"* ]]
  [[ "$output" == *"on ambiguous failure, STOP and escalate to human"* ]]
  [[ "$output" == *"never guess"* ]]
}

@test "AC-031-35 — spec-deployer refuses vercel deploy and records the refusal in 40-deploy.md" {
  [ -f "$AGENT" ]
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"you refuse"* ]]
  [[ "$flat" == *"record the refusal in \`40-deploy.md\`"* ]]
  [[ "$flat" == *"never run"*"vercel deploy"* ]]
}

@test "AC-031-36 — phase 3 does not start on a phase-2 FAIL verdict" {
  flat="$(section 'Deploy verification loop (phase 3)' | tr '\n' ' ')"
  [[ "$flat" == *"only after"*"phase-2"*"green"* ]]
  [[ "$flat" == *"phase-2 FAIL verdict phase 3 does not start"* ]]
}
