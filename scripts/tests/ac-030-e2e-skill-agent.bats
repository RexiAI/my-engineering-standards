#!/usr/bin/env bats
# ac-030-e2e-skill-agent.bats — CI integration + traceability wrapper for the
# spec 030 acceptance suite (agentic E2E standard: e2e-testing skill + e2e-runner agent).
#
# The assertions live in the plain-bash scenario tests prescribed by
# specs/030-e2e-skill-agent/10-tasks.md (tests/AC-030-NN.sh — one function per
# scenario, runnable standalone via `bash tests/AC-030-NN.sh`). This wrapper
# executes each scenario individually and carries the literal AC-030-NN-MM IDs
# in its @test names: scripts/tests/*.bats is a file pattern that
# scripts/check-scenario-traceability.sh scans, so every scenario ID stays
# cited from the project's real test surface (docs/SPEC_PIPELINE.md
# §Scenario format, §Why no scenario mutation), following the precedent of
# scripts/tests/ac-004-005-007-trace.bats.

load test_helper
bats_require_minimum_version 1.5.0

# run_scenario <task-NN> <scenario-id> — execute one scenario of the task's
# suite file; green means exit 0 and no FAIL line in the output.
run_scenario() {
  run --separate-stderr bash "$REPO_ROOT/tests/AC-030-$1.sh" "$2"
  [ "$status" -eq 0 ]
  [[ "$output" != *"FAIL "* ]]
}

# run_task_suite <task-NN> — execute the whole suite file (scenarios + units);
# green means exit 0 and a RESULT line with failed=0.
run_task_suite() {
  run --separate-stderr bash "$REPO_ROOT/tests/AC-030-$1.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESULT AC-030-$1: passed="*" failed=0"* ]]
}

# ---- Task 1: skills/e2e-testing/SKILL.md (AC-030-01) ----

@test "AC-030-01-01: SKILL.md frontmatter exists with required fields" {
  run_scenario 01 AC-030-01-01
}

@test "AC-030-01-02: name field is exactly e2e-testing (matches directory)" {
  run_scenario 01 AC-030-01-02
}

@test "AC-030-01-03: name format valid, lowercase-hyphen, <=64 chars" {
  run_scenario 01 AC-030-01-03
}

@test "AC-030-01-04: description non-empty and within 1024-char limit" {
  run_scenario 01 AC-030-01-04
}

@test "AC-030-01-05: body line count within 500-line limit" {
  run_scenario 01 AC-030-01-05
}

@test "AC-030-01-06: required body sections present" {
  run_scenario 01 AC-030-01-06
}

@test "AC-030-01-07: version pin 0.17.0 and pre-1.0 instability warning present" {
  run_scenario 01 AC-030-01-07
}

@test "AC-030-01-08: telemetry opt-out E2E_TELEMETRY_DISABLED mandated" {
  run_scenario 01 AC-030-01-08
}

@test "AC-030-01-09: act+expect golden rule stated" {
  run_scenario 01 AC-030-01-09
}

@test "AC-030-01-10: opaque Secret path taught, inline credentials forbidden" {
  run_scenario 01 AC-030-01-10
}

@test "AC-030-01-11: no literal model or provider ids in SKILL.md" {
  run_scenario 01 AC-030-01-11
}

@test "AC-030-01-12: no forbidden re-run phrasing in SKILL.md" {
  run_scenario 01 AC-030-01-12
}

# ---- Task 2: skills/e2e-testing/references/*.md (AC-030-02) ----

@test "AC-030-02-01: all six reference files exist" {
  run_scenario 02 AC-030-02-01
}

@test "AC-030-02-02: each reference file is referenced from SKILL.md" {
  run_scenario 02 AC-030-02-02
}

@test "AC-030-02-03: no nested reference chains between reference files" {
  run_scenario 02 AC-030-02-03
}

@test "AC-030-02-04: setup.md content coverage" {
  run_scenario 02 AC-030-02-04
}

@test "AC-030-02-05: writing-tests.md content coverage" {
  run_scenario 02 AC-030-02-05
}

@test "AC-030-02-06: running-debugging.md content coverage" {
  run_scenario 02 AC-030-02-06
}

@test "AC-030-02-07: bug-bash.md content coverage" {
  run_scenario 02 AC-030-02-07
}

@test "AC-030-02-08: ci.md and mobile-rn.md content coverage" {
  run_scenario 02 AC-030-02-08
}

# ---- Task 3: assets/e2e.config.example.ts (AC-030-03) ----

@test "AC-030-03-01: config example file exists" {
  run_scenario 03 AC-030-03-01
}

@test "AC-030-03-02: model ids read from process.env, none hardcoded" {
  run_scenario 03 AC-030-03-02
}

@test "AC-030-03-03: port-0 pattern and shell-less app launch present" {
  run_scenario 03 AC-030-03-03
}

@test "AC-030-03-04: budgets and cache modes configured" {
  run_scenario 03 AC-030-03-04
}

@test "AC-030-03-05: telemetry opt-out, tests glob, no .env loading" {
  run_scenario 03 AC-030-03-05
}

# ---- Task 4: agents/e2e-runner.md (AC-030-04) ----

@test "AC-030-04-01: agent frontmatter has required fields" {
  run_scenario 04 AC-030-04-01
}

@test "AC-030-04-02: permission denies git push and git commit" {
  run_scenario 04 AC-030-04-02
}

@test "AC-030-04-03: permission denies edits outside allowed paths, .e2e read-only" {
  run_scenario 04 AC-030-04-03
}

@test "AC-030-04-04: no model key in frontmatter" {
  run_scenario 04 AC-030-04-04
}

@test "AC-030-04-05: body has required sections for both duties" {
  run_scenario 04 AC-030-04-05
}

@test "AC-030-04-06: workflow vs agent choice justified" {
  run_scenario 04 AC-030-04-06
}

@test "AC-030-04-07: ground truth and stopping conditions stated" {
  run_scenario 04 AC-030-04-07
}

@test "AC-030-04-08: bug-bash bounds, confirmation gate, hygiene" {
  run_scenario 04 AC-030-04-08
}

# ---- Task 5: doc wiring (AC-030-05) ----

@test "AC-030-05-01: docs/TESTING.md agentic E2E section, skill pointer, Playwright preserved" {
  run_scenario 05 AC-030-05-01
}

@test "AC-030-05-02: AGENTS.md Reading the Standards line added" {
  run_scenario 05 AC-030-05-02
}

@test "AC-030-05-03: no literal model ids added to docs" {
  run_scenario 05 AC-030-05-03
}

# ---- Task 6: conditional model wiring (AC-030-06) ----

@test "AC-030-06-01: opencode.json e2e-runner entry uses env reference (conditional)" {
  run_scenario 06 AC-030-06-01
}

@test "AC-030-06-02: config/model.local.env.example defines the var (conditional)" {
  run_scenario 06 AC-030-06-02
}

@test "AC-030-06-03: model-env roster updated and check-model-env green (conditional)" {
  run_scenario 06 AC-030-06-03
}

# ---- Task 7: gate verification (AC-030-07) ----

@test "AC-030-07-01: check-skills.sh exits 0" {
  run_scenario 07 AC-030-07-01
}

@test "AC-030-07-02: check-orchestration.sh exits 0" {
  run_scenario 07 AC-030-07-02
}

@test "AC-030-07-03: check-model-env.sh exits 0 and holistic hygiene holds" {
  run_scenario 07 AC-030-07-03
}

# ---- Per-task full-suite entry points (scenarios + units) ----

@test "AC-030-01: T1 full suite (scenarios + units) exits 0" {
  run_task_suite 01
}

@test "AC-030-02: T2 full suite (scenarios + units) exits 0" {
  run_task_suite 02
}

@test "AC-030-03: T3 full suite (scenarios + units) exits 0" {
  run_task_suite 03
}

@test "AC-030-04: T4 full suite (scenarios + units) exits 0" {
  run_task_suite 04
}

@test "AC-030-05: T5 full suite (scenarios + units) exits 0" {
  run_task_suite 05
}

@test "AC-030-06: T6 full suite (scenarios + units) exits 0" {
  run_task_suite 06
}

@test "AC-030-07: T7 full suite (scenarios + units) exits 0" {
  run_task_suite 07
}
