#!/usr/bin/env bats
# ac-041-pipeline-reuse.bats — acceptance tests for spec 041 Task 5
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-test-run-reuse-pipeline.md).
#
# Fixtures live under $TMPDIR_HELPER; the audit-trail gate is run against the
# fixture specs dir so the real specs/ tree is never touched.

load test_helper
bats_require_minimum_version 1.5.0

STAGES="$REPO_ROOT/docs/spec-pipeline"
VERIFIER_AGENT="$REPO_ROOT/agents/spec-verifier.md"
MUTATION_DOC="$STAGES/mutation-runner.md"
HASH="$(printf 'a%.0s' $(seq 1 64))"

setup() {
  setup_tmpdir
  SPECS="$TMPDIR_HELPER/specs"
  SLUG="999-reuse"
  mkdir -p "$SPECS/$SLUG/20-acceptance"
  printf '# Tasks\n\n## Task 1 — fixture\n\nAcceptance criteria.\n' > "$SPECS/$SLUG/10-tasks.md"
  printf '## AC-999-01 — a fixture scenario\n\nGiven a fixture\nWhen checked\nThen it passes\n' \
    > "$SPECS/$SLUG/20-acceptance/AC-999-01-example.md"
  printf '# Report\n\nMutation score: 100%%\nFinal test status: green\nVerifier verdict: PASS\n' \
    > "$SPECS/$SLUG/30-report.md"
  write_verification
}
teardown() { teardown_tmpdir; }

# write_verification — a complete 25-verification.md whose full-test-suite block
# carries `Test-run hash:` immediately after `at:`.
write_verification() {
  {
    printf '# Verification\n\nOverall verdict: PASS\n\n'
    printf '## Evidence: scenario traceability\n\ncommand: scripts/check-scenario-traceability.sh\nexit: 0\nat: 2026-11-05T10:00:00Z\n\nAll scenarios traced.\n\n'
    printf '## Evidence: full test suite\n\ncommand: scripts/agent-test-summary.sh --run /tmp/pipeline/999-verifier-test-suite.log -- make test\nexit: 0\nat: 2026-11-05T10:00:01Z\nTest-run hash: %s\n\nSUMMARY: mode=run exit=0 signal=0 log_lines=42 log=/tmp/pipeline/999-verifier-test-suite.log\nfull log: §Raw log: full test suite\n\n' "$HASH"
    printf '## Evidence: complexity gate\n\ncommand: golangci-lint run\nexit: 0\nat: 2026-11-05T10:00:02Z\n\nNo complexity violations.\n\n'
    printf '## Evidence: design-principles gate\n\ncommand: scripts/check-code-principles.sh\nexit: 0\nat: 2026-11-05T10:00:03Z\n\nPassed.\n\n'
    printf '## Evidence: scenario-to-behavior spot check\n\ncommand: manual spot check\nat: 2026-11-05T10:00:04Z\nexit: 0\n\nSpot check passed.\n\nNo unaccounted behavior found.\n'
  } > "$SPECS/$SLUG/25-verification.md"
}

@test "AC-041-38 — the verifier records the hash inside the full-test-suite block" {
  grep -q 'Test-run hash:' "$STAGES/verifier.md"
  grep -q 'immediately after `at:`' "$STAGES/verifier.md"
  local block
  block="$(awk '/^## Evidence: full test suite$/ { inblock = 1 } inblock { print } inblock && /^Test-run hash:/ { exit }' "$SPECS/$SLUG/25-verification.md")"
  [ "$(sed -n '$p' <<< "$block")" = "Test-run hash: $HASH" ]
  [ "$(tail -n2 <<< "$block" | sed -n '1p')" = "at: 2026-11-05T10:00:01Z" ]
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" "$SLUG" "$SPECS"
  [ "$status" -eq 0 ]
}

@test "AC-041-39 — a tree that changes during the run is recorded, not hidden" {
  grep -q 'tree-changed-during-run' "$STAGES/verifier.md"
  grep -q 'the post-run hash is' "$STAGES/verifier.md"
}

@test "AC-041-40 — the reuse branch executes no test command" {
  grep -q 'scripts/test-run-reuse.sh --check specs/NNN-slug/25-verification.md' "$MUTATION_DOC"
  grep -q 'Execute no test command' "$MUTATION_DOC"
  grep -q 'reused-from: 25-verification.md §Evidence: full test suite (test-run hash <hash>)' "$MUTATION_DOC"
  grep -q 'verbatim' "$MUTATION_DOC"
}

@test "AC-041-41 — the re-run branch records its own evidence" {
  grep -q 'scripts/agent-test-summary.sh --run' "$MUTATION_DOC"
  grep -q 'Test-run hash:' "$MUTATION_DOC"
  grep -q 'No `reused-from:` line is written' "$MUTATION_DOC"
}

@test "AC-041-42 — mutation testing is never reused" {
  grep -q 'Mutation testing itself always runs' "$MUTATION_DOC"
  grep -q 'no path skips, reuses, or truncates the mutation run' "$MUTATION_DOC"
}

@test "AC-041-43 — the verifier never reuses" {
  local files file hits
  files="$VERIFIER_AGENT $STAGES/verifier.md"
  for file in $files; do
    [[ "$(grep -o 'test-run-reuse\.sh --[a-z-]*' "$file" | sort -u | tr '\n' ' ')" != *"--check"* ]]
  done
  hits="$(grep -o 'test-run-reuse\.sh --print-hash' $files | wc -l | tr -d ' ')"
  [ "$hits" -ge 1 ]
  grep -q 'never reuses a prior run' "$STAGES/verifier.md"
}

@test "AC-041-44 — a reuse-form report still passes the audit-trail gate" {
  printf 'reused-from: 25-verification.md §Evidence: full test suite (test-run hash %s)\n' "$HASH" \
    >> "$SPECS/$SLUG/30-report.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" "$SLUG" "$SPECS"
  [ "$status" -eq 0 ]
}
