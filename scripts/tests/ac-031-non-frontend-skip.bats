#!/usr/bin/env bats
# ac-031-non-frontend-skip.bats — acceptance tests for spec 031 Task 8
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-non-frontend-skip.md).
# AC-42/45-49 pin the spec-deployer contract (agent file); AC-43 exercises the
# audit-trail gate; AC-44 pins GHCR-path independence of the shipped CI files.

load test_helper
bats_require_minimum_version 1.5.0

AGENT="$REPO_ROOT/agents/spec-deployer.md"
GATE="$REPO_ROOT/scripts/check-audit-trail.sh"
WF_NEXTJS="$REPO_ROOT/.github/workflows/ci-nextjs.yml"
WF_VERCEL="$REPO_ROOT/.github/workflows/ci-vercel-production-verify.yml"

seed_folder() {
  local d="$1"
  mkdir -p "$d/20-acceptance"
  printf '# Fixture spec\n\n## Task 1 — a task\n\nAcceptance criteria.\n' > "$d/10-tasks.md"
  printf '## AC-903-01 — an example scenario\n\nGiven/When/Then\n' > "$d/20-acceptance/AC-903-01-example.md"
  {
    for c in "scenario traceability" "full test suite" "complexity gate" "design-principles gate" "scenario-to-behavior spot check"; do
      printf '## Evidence: %s\n\nc: x\ncommand: true\nexit: 0\nat: 2026-08-15T10:00:00Z\n\nraw output\n\n' "$c"
    done
  } > "$d/25-verification.md"
  printf '# Report\n\nFinal test status: green\n' > "$d/30-report.md"
}

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-031-42 — non-frontend repo: agent writes 40-deploy.md with SKIPPED verdict and the skip reason" {
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"Verdict: SKIPPED"* ]]
  [[ "$flat" == *"Non-frontend repo — deploy verification not applicable"* ]]
  [[ "$flat" == *"exit cleanly"* ]]
}

@test "AC-031-43 — non-frontend 40-deploy.md with SKIPPED never fails the deploy gate" {
  local root="$TMPDIR_HELPER/be"
  mkdir -p "$root/specs"
  seed_folder "$root/specs/903-be"
  printf 'Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable\n' > "$root/specs/903-be/40-deploy.md"
  run bash -c "cd '$root' && bash '$GATE' 903-be specs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip reason acceptable"* ]]
}

@test "AC-031-44 — GHCR container path is untouched: ci-nextjs.yml still pushes ghcr.io and the Vercel lane is a separate file" {
  [ -f "$WF_NEXTJS" ]
  grep -qF 'ghcr.io' "$WF_NEXTJS"
  ! grep -qiF 'vercel' "$WF_NEXTJS"
  [ -f "$WF_VERCEL" ]
  ! grep -qiF 'ghcr' "$WF_VERCEL"
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"neither one cancels the other"* ]]
}

@test "AC-031-45 — preview build timeout records FAIL with the timeout reason and consumes a phase-3 round" {
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"Preview build did not complete within"* ]]
  [[ "$flat" == *"verdict"*"FAIL"* ]]
  [[ "$flat" == *"consumes one"*"phase-3 attempt"* ]]
}

@test "AC-031-46 — preview build failure records FAIL with the Vercel error classification and build log excerpt" {
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"BUILD_FAILED"* ]]
  [[ "$flat" == *"Vercel error classification"* ]]
  [[ "$flat" == *"build log excerpt"* ]]
  [[ "$flat" == *"fix-routing rule determines the next action"* || "$flat" == *"Fix-routing (deterministic)"* ]]
}

@test "AC-031-47 — deploy succeeds but health check fails: FAIL records the response code or timeout" {
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"non-2xx response or a"*"timeout is a health-check"*"FAIL"* ]]
  [[ "$flat" == *"record the response code or the"*"timeout"* ]]
}

@test "AC-031-48 — E2E failure against the live preview URL records FAIL and routes to spec-coder" {
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"E2E runner exits non-zero"* ]]
  [[ "$flat" == *"routed to spec-coder"* ]]
  [[ "$flat" == *"runner's exit code and failure details"* ]]
}

@test "AC-031-49 — no Vercel project linked: SKIPPED with the manual-setup reason, pipeline does not fail" {
  flat="$(tr '\n' ' ' < "$AGENT")"
  [[ "$flat" == *"No Vercel project linked to this repository — manual setup required"* ]]
  [[ "$flat" == *"the pipeline does not fail"* ]]
}
