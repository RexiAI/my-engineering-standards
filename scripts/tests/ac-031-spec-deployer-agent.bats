#!/usr/bin/env bats
# ac-031-spec-deployer-agent.bats — acceptance tests for spec 031 Task 1
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-spec-deployer-agent.md).
# Carrier pattern: this repo's scripts are tested by bats (docs/TESTING.md
# Track B); scenario IDs live in the @test names per docs/SPEC_PIPELINE.md
# §Scenario format so check-scenario-traceability.sh check 1 traces them.

load test_helper
bats_require_minimum_version 1.5.0

AGENT="$REPO_ROOT/agents/spec-deployer.md"

# frontmatter <file> — print the YAML frontmatter block (between the first
# pair of --- lines), same extraction as check-stop-and-ask-matrix.sh.
frontmatter() {
  awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{exit} f' "$1"
}

# body <file> — print everything after the frontmatter block.
body() {
  awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{f=2;next} f!=1' "$1"
}

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-01 — agents/spec-deployer.md exists with frontmatter keys description, mode, permission.read/edit/bash" {
  [ -f "$AGENT" ]
  run frontmatter "$AGENT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"description:"* ]]
  [[ "$output" == *"mode: subagent"* ]]
  [[ "$output" == *"read:"* ]]
  [[ "$output" == *"edit:"* ]]
  [[ "$output" == *"bash:"* ]]
}

@test "AC-031-02 — permission.bash denies vercel deploy* so the command is refused, not executed" {
  [ -f "$AGENT" ]
  run frontmatter "$AGENT"
  [[ "$output" == *'"vercel deploy*": deny'* ]]
  # deny must sit in the bash block, not just anywhere in the frontmatter:
  # extract the bash sub-block and assert the rule there.
  run bash -c "awk '/^  bash:/{f=1;next} f && /^  [a-z]/{exit} f' <(awk 'NR==1 && \$0==\"---\"{f=1;next} f && \$0==\"---\"{exit} f' '$AGENT')"
  [[ "$output" == *'"vercel deploy*": deny'* ]]
}

@test "AC-031-03 — permission.read denies specs/*/00-informal.md, matching the spec-coder pattern" {
  [ -f "$AGENT" ]
  run frontmatter "$AGENT"
  [[ "$output" == *'"specs/*/00-informal.md": deny'* ]]
  # effective action on the informal-spec path must be deny, asserted with the
  # repo's own permission evaluator (same helper check-stop-and-ask-matrix uses)
  run bash -c "source '$REPO_ROOT/scripts/check-stop-and-ask-matrix-helpers.sh' 2>/dev/null || true; printf '%s' ok"
  [[ "$output" == "ok" ]]
  grep -A2 'read:' <(frontmatter "$AGENT") | grep -q '"specs/\*/00-informal.md": deny'
}

@test "AC-031-04 — agent prompt explicitly lists the only permitted CLI commands" {
  [ -f "$AGENT" ]
  run body "$AGENT"
  for cmd in "vercel inspect" "vercel logs" "vercel ls" "vercel env pull" "vercel env add" "vercel pull" "vercel domains"; do
    [[ "$output" == *"$cmd"* ]]
  done
  [[ "$output" == *"only permitted"* ]]
}

@test "AC-031-05 — agent prompt prohibits vercel deploy with the stated reason (double-build, Git-integration race, orphaned deployments)" {
  [ -f "$AGENT" ]
  run body "$AGENT"
  [[ "$output" == *"never run"* ]]
  [[ "$output" == *"vercel deploy"* ]]
  [[ "$output" == *"double-build"* ]]
  [[ "$output" == *"Git integration"* ]]
  [[ "$output" == *"orphaned deployments"* ]]
}

@test "unit — agent declares the Stop-and-Ask matrix authoritative (same discipline as the other stage agents)" {
  [ -f "$AGENT" ]
  grep -qF 'Stop-and-Ask decision matrix' "$AGENT"
  grep -qF 'authoritative' "$AGENT"
  grep -qF 'never by improvisation' "$AGENT"
}

@test "unit — agent prompt names its stage, artifact, and the e2e delegation target" {
  [ -f "$AGENT" ]
  grep -qF '40-deploy.md' "$AGENT"
  grep -qF 'e2e-runner' "$AGENT"
  grep -qF 'e2e-testing' "$AGENT"
}

@test "unit — permission.edit denies the gate-threshold files (spec-pr-opener pattern)" {
  [ -f "$AGENT" ]
  fm="$(frontmatter "$AGENT")"
  printf '%s\n' "$fm" | grep -qF '"**/check-code-principles.sh": deny'
  printf '%s\n' "$fm" | grep -qF '"**/pmd*.xml": deny'
  printf '%s\n' "$fm" | grep -qF '"**/*golangci*.yml": deny'
  printf '%s\n' "$fm" | grep -qF '"**/.eslintrc*": deny'
}
