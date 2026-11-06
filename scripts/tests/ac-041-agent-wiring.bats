#!/usr/bin/env bats
# ac-041-agent-wiring.bats — acceptance tests for spec 041 Task 3
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-agent-wiring.md).
#
# "Stage procedure" is the stage doc under docs/spec-pipeline/ plus the agent
# prompt that points at it. The append recipe is exercised against a fixture
# spec folder under $TMPDIR_HELPER — never the real specs/ tree.

load test_helper
bats_require_minimum_version 1.5.0

STAGES="$REPO_ROOT/docs/spec-pipeline"
VERIFIER_DOC="$STAGES/verifier.md"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-041-21 — the full-test-suite block records the filtered shape" {
  local section flat
  section="$(awk '/^## Test-log capture/ { inblock = 1 } inblock && /^## Telemetry/ { exit } inblock { print }' "$VERIFIER_DOC")"
  [ -n "$section" ]
  flat="$(tr '\n' ' ' <<< "$section" | tr -s ' ')"
  [[ "$flat" == *'scripts/agent-test-summary.sh --run'* ]]
  [[ "$flat" == *'-- <real command>'* ]]
  [[ "$flat" == *'carries the real command verbatim after `--`'* ]]
  [[ "$flat" == *'SUMMARY:'* ]]
  [[ "$flat" == *'full log: §Raw log: full test suite'* ]]
}

@test "AC-041-22 — the append recipe puts the full log in the evidence file verbatim" {
  local recipe fixture spec log start
  recipe="$(grep -m1 "^{ printf '## Raw log:" "$VERIFIER_DOC")"
  [ -n "$recipe" ]
  [ "$(grep -o '\$LOG' <<< "$recipe" | wc -l | tr -d ' ')" -eq 1 ]
  recipe="${recipe//<check>/full test suite}"
  recipe="${recipe//specs\/NNN-slug/specs/999-fixture}"
  fixture="$TMPDIR_HELPER"
  spec="$fixture/specs/999-fixture"
  mkdir -p "$spec"
  printf '# Verification\n\n## Evidence: scenario traceability\n\nok\n' > "$spec/25-verification.md"
  log="$fixture/raw.log"
  printf 'line one\n\nline three without trailing newline' > "$log"
  cd "$fixture" || return 1
  export CMD='make test' XC=0 AT='2026-11-05T00:00:00Z' LOG="$log"
  eval "$recipe"
  start="$(grep -n '^## Raw log: full test suite$' "$spec/25-verification.md" | cut -d: -f1)"
  [ -n "$start" ]
  [ "$(tail -n "+$((start + 6))" "$spec/25-verification.md" | sha256sum | awk '{print $1}')" \
    = "$(sha256sum "$log" | awk '{print $1}')" ]
}

@test "AC-041-23 — every suite-running stage cites the helper" {
  local doc
  for doc in coder refactorer verifier mutation-runner; do
    grep -q 'scripts/agent-test-summary.sh' "$STAGES/$doc.md"
  done
}

@test "AC-041-24 — the append recipe exists exactly once" {
  local count
  count="$(grep -rc "printf '## Raw log:" "$REPO_ROOT/agents" "$STAGES" 2>/dev/null \
    | awk -F: '{ total += $2 } END { print total + 0 }')"
  [ "$count" -eq 1 ]
}

@test "AC-041-25 — design-principles and complexity lanes are never filtered" {
  local complexity_row flat
  flat="$(tr '\n' ' ' < "$VERIFIER_DOC" | tr -s ' ')"
  grep -q 'scripts/check-code-principles.sh' "$VERIFIER_DOC"
  [[ "$flat" == *"Only the test-suite lane is filtered"* ]]
  [[ "$flat" == *"design-principles gate and the complexity linters are invoked directly"* ]]
  [[ "$flat" == *'every `FAIL` and `WARN` line must be recorded verbatim'* ]]
  complexity_row="$(grep -m1 '| 3 | Complexity gate' "$VERIFIER_DOC")"
  [ -n "$complexity_row" ]
  [[ "$complexity_row" != *"agent-test-summary"* ]]
}

@test "AC-041-26 — agent caps and orchestration stay green" {
  run bash "$REPO_ROOT/scripts/check-agent-line-cap.sh"
  [ "$status" -eq 0 ]
  run bash "$REPO_ROOT/scripts/check-orchestration.sh"
  [ "$status" -eq 0 ]
}
