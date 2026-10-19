#!/usr/bin/env bats
# ac-031-orchestration-compliance.bats — acceptance tests for spec 031 Task 11
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-orchestration-compliance.md).
# These run the REAL gates against the real tree — they are the mechanical
# close-out of the spec; docs/AGENTS_AND_SKILLS.md + check-orchestration.sh
# wiring is what keeps the new agent reference honest.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-56 — check-orchestration.sh exits 0 with spec-deployer wired in" {
  run bash "$REPO_ROOT/scripts/check-orchestration.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All orchestration references valid."* ]]
  [ -f "$REPO_ROOT/agents/spec-deployer.md" ]
}

@test "AC-031-57 — check-model-env.sh exits 0 (env-reference roster incl. spec-deployer)" {
  run bash "$REPO_ROOT/scripts/check-model-env.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  grep -qF '"spec-deployer": { "model": "{env:SPEC_DEPLOYER_MODEL}" }' "$REPO_ROOT/opencode.json"
}

@test "AC-031-58 — check-audit-trail.sh --selftest still exits 0 after the 40-deploy extension" {
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" --selftest
  [ "$status" -eq 0 ]
  [[ "$output" == *"Selftest: every audit-trail scenario exercised and passing"* ]]
}

@test "AC-031-59 — check-no-hardcoded-secrets.sh exits 0 over the scanned tree" {
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
}

@test "AC-031-60 — guard-env.sh exits 0 (config/agent.local.env not tracked)" {
  run bash "$REPO_ROOT/scripts/guard-env.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  ! git -C "$REPO_ROOT" ls-files --error-unmatch config/agent.local.env >/dev/null 2>&1
}

@test "unit — model-env selftest stays green with the 10-agent roster" {
  run bash "$REPO_ROOT/scripts/model-env.selftest.sh"
  [ "$status" -eq 0 ]
}
