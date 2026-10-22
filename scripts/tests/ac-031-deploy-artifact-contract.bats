#!/usr/bin/env bats
# ac-031-deploy-artifact-contract.bats — acceptance tests for spec 031 Task 4
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-deploy-artifact-contract.md).
# AC-17 asserts the docs contract; AC-18/19/21 drive check-audit-trail.sh
# against hermetic temp spec-folder fixtures (frontend = vercel.json at the
# project root, i.e. the parent of SPECS_DIR).

load test_helper
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"
GATE="$REPO_ROOT/scripts/check-audit-trail.sh"

# seed_folder <spec-folder> — a complete pre-40-deploy audit folder
seed_folder() {
  local d="$1"
  mkdir -p "$d/20-acceptance"
  printf '# Fixture spec\n\n## Task 1 — a task\n\nAcceptance criteria.\n' > "$d/10-tasks.md"
  printf '## AC-901-01 — an example scenario\n\nGiven/When/Then\n' > "$d/20-acceptance/AC-901-01-example.md"
  cat > "$d/25-verification.md" <<'EOF'
# Verification

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-08-15T10:00:00Z

Scenario IDs found: 60

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-08-15T10:00:01Z

All green.

## Evidence: complexity gate

command: scripts/check-code-principles.sh
exit: 0
at: 2026-08-15T10:00:02Z

No complexity violations.

## Evidence: design-principles gate

command: scripts/check-code-principles.sh
exit: 0
at: 2026-08-15T10:00:03Z

No violations.

## Evidence: scenario-to-behavior spot check

command: manual spot check of two acceptance scenarios against their tests
exit: 0
at: 2026-08-15T10:00:04Z

Spot check passed.
EOF
  printf '# Report\n\nMutation score: skipped — mvp tier\nFinal test status: green\n' > "$d/30-report.md"
}

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-17 — 40-deploy.md evidence format is defined in the audit-contract Deploy Verifier row" {
  run grep -F '| Deploy Verifier | `40-deploy.md` |' "$DOC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Deploy URL"* ]]
  [[ "$output" == *"build status (pass/fail/skip)"* ]]
  [[ "$output" == *"health check status"* ]]
  [[ "$output" == *"E2E verdict (pass/fail/skip)"* ]]
  [[ "$output" == *"timestamp"* ]]
  [[ "$output" == *"phase-3 attempt count"* ]]
  [[ "$output" == *"verdict (PASS/FAIL/ESCALATED/SKIPPED)"* ]]
}

@test "AC-031-18 — frontend spec with 30-report.md + non-empty 40-deploy.md exits 0" {
  local root="$TMPDIR_HELPER/fe-repo"
  mkdir -p "$root/specs"
  printf '{}' > "$root/vercel.json"
  seed_folder "$root/specs/901-fe"
  printf 'Verdict: PASS\n\n## Evidence: deploy\n\ncommand: vercel inspect\nexit: 0\nat: 2026-10-19T10:00:00Z\n\nREADY https://901-fe.vercel.app\n' > "$root/specs/901-fe/40-deploy.md"
  run bash -c "cd '$root' && bash '$GATE' 901-fe specs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"40-deploy.md present and non-empty"* ]]
}

@test "AC-031-19 — non-frontend spec with 40-deploy.md carrying a skip reason exits 0 and accepts it" {
  local root="$TMPDIR_HELPER/be-repo"
  mkdir -p "$root/specs"
  seed_folder "$root/specs/901-be"
  printf 'Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable\n' > "$root/specs/901-be/40-deploy.md"
  run bash -c "cd '$root' && bash '$GATE' 901-be specs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]]
}

@test "AC-031-20 — FIVE_CHECKS still holds exactly five entries and 40-deploy.md lives in a separate function" {
  awk '/^FIVE_CHECKS=\(/,/^\)/' "$GATE" | grep -cE '^ +"' | grep -qx 5
  ! awk '/^FIVE_CHECKS=\(/,/^\)/' "$GATE" | grep -qi '40-deploy'
  grep -qE '^check_deploy_artifact\(\)' "$GATE"
  # the five named checks are intact
  for c in "scenario traceability" "full test suite" "complexity gate" "design-principles gate" "scenario-to-behavior spot check"; do
    grep -qF "\"$c\"" "$GATE"
  done
}

# Amended on fix/audit-trail-require-deploy (ADR 0010): AC-031-21's missing-artifact
# requirement is only satisfiable after stage 5c writes 40-deploy.md, and stage 5b
# runs this gate pre-push — so the scenario is exercised via the stage-5d
# --require-deploy invocation (the upgrade path documented in spec 031's own gate
# comment). The no-flag default is covered by the unit case below.
@test "AC-031-21 — frontend spec with 30-report.md but no 40-deploy.md exits non-zero naming the file (--require-deploy, stage 5d final gate)" {
  local root="$TMPDIR_HELPER/fe-repo"
  mkdir -p "$root/specs"
  printf '{}' > "$root/vercel.json"
  seed_folder "$root/specs/901-fe"
  run bash -c "cd '$root' && bash '$GATE' --require-deploy 901-fe specs"
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing 40-deploy.md"* ]]
}

@test "unit — default run (stage 5b pre-push): frontend spec missing 40-deploy.md exits 0, absence tolerated pre-5c" {
  local root="$TMPDIR_HELPER/fe-repo"
  mkdir -p "$root/specs"
  printf '{}' > "$root/vercel.json"
  seed_folder "$root/specs/901-fe"
  run bash -c "cd '$root' && bash '$GATE' 901-fe specs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"40-deploy.md absent"* ]]
}

@test "unit — frontend spec with present-but-empty 40-deploy.md still fails under the default run (AC-031-19 guarantee preserved)" {
  local root="$TMPDIR_HELPER/fe-repo"
  mkdir -p "$root/specs"
  printf '{}' > "$root/vercel.json"
  seed_folder "$root/specs/901-fe"
  : > "$root/specs/901-fe/40-deploy.md"
  run bash -c "cd '$root' && bash '$GATE' 901-fe specs"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty 40-deploy.md"* ]]
}

@test "unit — empty 40-deploy.md fails as empty" {
  local root="$TMPDIR_HELPER/be-repo"
  mkdir -p "$root/specs"
  seed_folder "$root/specs/901-be"
  : > "$root/specs/901-be/40-deploy.md"
  run bash -c "cd '$root' && bash '$GATE' 901-be specs"
  [ "$status" -ne 0 ]
  [[ "$output" == *"empty 40-deploy.md"* ]]
}
