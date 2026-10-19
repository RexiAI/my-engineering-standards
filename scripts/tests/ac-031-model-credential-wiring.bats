#!/usr/bin/env bats
# ac-031-model-credential-wiring.bats — acceptance tests for spec 031 Task 2
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-model-credential-wiring.md).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-06 — opencode.json agent block gains spec-deployer with an env reference, no literal model id" {
  run python3 - "$REPO_ROOT/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
m = d["agent"]["spec-deployer"]["model"]
assert m == "{env:SPEC_DEPLOYER_MODEL}", m
print("OK")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK"* ]]
  # the entry line itself carries no provider/model literal
  run grep '"spec-deployer"' "$REPO_ROOT/opencode.json"
  [[ "$output" == *'{env:SPEC_DEPLOYER_MODEL}'* ]]
  ! printf '%s' "$output" | grep -qE '[A-Za-z0-9._-]+/[A-Za-z0-9._-]+"[[:space:]]*\}'
}

@test "AC-031-07 — config/model.local.env.example carries the committed SPEC_DEPLOYER_MODEL default" {
  grep -qx 'SPEC_DEPLOYER_MODEL=bailian-token-plan-personal/qwen3.8-flash' \
    "$REPO_ROOT/config/model.local.env.example"
}

@test "AC-031-08 — config/agent.local.env.example carries commented Vercel placeholders (angle-bracket convention)" {
  f="$REPO_ROOT/config/agent.local.env.example"
  grep -qxF '# VERCEL_TOKEN=<your-vercel-token>' "$f"
  grep -qxF '# VERCEL_ORG_ID=<your-vercel-org-id>' "$f"
  grep -qxF '# VERCEL_PROJECT_ID=<your-vercel-project-id>' "$f"
}

@test "AC-031-09 — check-no-hardcoded-secrets.sh exits 0 with the wiring in place" {
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"config/agent.local.env.example"* ]]
}

@test "AC-031-10 — guard-env.sh still exits 0 (no real env file tracked)" {
  run bash "$REPO_ROOT/scripts/guard-env.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
}

@test "unit — the model roster maps spec-deployer to SPEC_DEPLOYER_MODEL" {
  run bash -c "source '$REPO_ROOT/scripts/model-env.vars.sh'; model_env_var_for_agent spec-deployer"
  [ "$status" -eq 0 ]
  [ "$output" = "SPEC_DEPLOYER_MODEL" ]
}

@test "unit — the child-bridge template carries the spec-deployer env-reference wiring" {
  run grep '"spec-deployer"' "$REPO_ROOT/templates/opencode.json.bridge"
  [[ "$output" == *'{env:SPEC_DEPLOYER_MODEL}'* ]]
}
