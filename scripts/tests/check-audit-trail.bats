#!/usr/bin/env bats
# check-audit-trail.bats — characterization tests for scripts/check-audit-trail.sh
# Contract: 0 when the spec folder + verifier evidence are complete (or absent);
# 1 on a missing/empty artifact or incomplete evidence; 2 on a usage error.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-audit-trail: no slug exits 2 and prints the usage block" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-audit-trail.sh"
  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"Usage:"* ]]
  [[ "$output$stderr" == *"check-audit-trail.sh <slug>"* ]]
}

@test "check-audit-trail: an absent spec folder is 'nothing to check' and exits 0" {
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 999-absent "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to check"* ]]
}

@test "check-audit-trail: a spec folder missing 25-verification.md exits 1" {
  mkdir -p "$TMPDIR_HELPER/001-x"
  printf '# tasks\n' > "$TMPDIR_HELPER/001-x/10-tasks.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"25-verification.md"* ]]
}

@test "check-audit-trail: --selftest exercises every negative case and exits 0" {
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" --selftest
  [ "$status" -eq 0 ]
  [[ "$output" == *"Selftest: every audit-trail scenario exercised and passing"* ]]
}

# ── spec 035 extensions: 45-decisions.md enforcement ─────────────────────────

make_complete_spec() {
  local specs="$1" slug="$2"
  local d="$specs/$slug"
  mkdir -p "$d/20-acceptance"
  printf '# Fixture spec\n\n## Task 1 — a task\n\nAcceptance criteria.\n' > "$d/10-tasks.md"
  printf '## AC-035-01 — a scenario\n\nGiven x\nWhen y\nThen z\n' > "$d/20-acceptance/AC-035-x.md"
  cat > "$d/25-verification.md" <<'EOF'
# Verification

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-10-26T03:00:00Z

Scenario IDs found: 1

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T03:00:01Z

All tests passed.

## Evidence: complexity gate

command: scripts/check-code-principles.sh
exit: 0
at: 2026-10-26T03:00:02Z

No complexity violations.

## Evidence: design-principles gate

command: scripts/check-code-principles.sh
exit: 0
at: 2026-10-26T03:00:03Z

No design-principles violations.

## Evidence: scenario-to-behavior spot check

command: manual spot check
exit: 0
at: 2026-10-26T03:00:04Z

Spot check passed.
EOF
  printf '# Report\n\nFinal test status: green\n' > "$d/30-report.md"
}

@test "AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder" {
  make_complete_spec "$TMPDIR_HELPER/specs" "001-x"
  printf 'Autopilot: true\nAutopilot decisions: 0\n' >> "$TMPDIR_HELPER/specs/001-x/30-report.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER/specs"
  [ "$status" -eq 1 ]
  [[ "$output" == *"45-decisions.md"* ]]

  : > "$TMPDIR_HELPER/specs/001-x/45-decisions.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER/specs"
  [ "$status" -eq 1 ]
  [[ "$output" == *"45-decisions.md"* ]]
}

@test "AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0" {
  make_complete_spec "$TMPDIR_HELPER/specs" "001-x"
  printf 'Autopilot: true\nAutopilot decisions: 1\n' >> "$TMPDIR_HELPER/specs/001-x/30-report.md"
  printf 'Condition: x\nOptions: y; z\nChosen: y\nWhy: w\nReversibility: high\nAt: 2026-10-26T03:00:00Z\n' \
    > "$TMPDIR_HELPER/specs/001-x/45-decisions.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER/specs"
  [ "$status" -eq 0 ]
}

@test "AC-035-35 — without the marker, 45-decisions.md is optional either way" {
  make_complete_spec "$TMPDIR_HELPER/specs" "001-x"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER/specs"
  [ "$status" -eq 0 ]

  printf 'No autopilot decisions were required\n' > "$TMPDIR_HELPER/specs/001-x/45-decisions.md"
  run bash "$REPO_ROOT/scripts/check-audit-trail.sh" 001-x "$TMPDIR_HELPER/specs"
  [ "$status" -eq 0 ]
}
