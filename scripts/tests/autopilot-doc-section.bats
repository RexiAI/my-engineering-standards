#!/usr/bin/env bats
# autopilot-doc-section.bats — acceptance tests for spec 035 Task 4
# (specs/035-autopilot-mode/20-acceptance/AC-035-doc-section.md).
# The `## Autopilot mode` section is the authoritative document: trigger,
# no-questions rule, a disposition for all 12 matrix rows, the 6 hard stops,
# and the 9 never-list refusals.

load test_helper
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"

# autopilot_section — print the body of the `## Autopilot mode` section.
autopilot_section() {
  awk '
    /^## / { if (found) exit }
    /^## Autopilot mode$/ { found = 1; next }
    found { print }
  ' "$DOC"
}

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "AC-035-11 — the section declares the trigger and the no-questions rule" {
  run autopilot_section
  [ "$status" -eq 0 ]
  [[ "$output" == *"SPEC_AUTOPILOT=1"* ]]
  [[ "$output" == *"/autopilot"* ]]
  [[ "$output" == *"autopilot"* ]]
  [[ "$output" == *"question tool"* ]]
  [[ "$output" == *"BLOCKED — <question>"* ]]
  [[ "$output" == *"waits for human input"* ]]
  [[ "$output" == *"choose the documented default, record it, continue"* ]]
}

@test "AC-035-12 — a disposition exists for all 12 matrix rows, including Deploy verification fails" {
  local sec i
  sec="$(autopilot_section)"
  local conditions=(
    'Working tree dirty'
    'Repo not found after discovery (wrong directory, `.standards/` submodule missing)'
    'Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`)'
    'Project type ambiguous (language stack / conformance tier undetectable)'
    'Version bump / git tag not requested'
    'A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold)'
    'Design gate WARN (not FAIL)'
    'Out-of-scope finding'
    'Acceptance criteria ambiguous'
    'Verifier verdict FAIL'
    'Deploy verification fails'
    'PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green)'
  )
  [ "${#conditions[@]}" -eq 12 ]
  for i in "${!conditions[@]}"; do
    [[ "$sec" == *"${conditions[$i]}"* ]]
    # the condition appears on a disposition table row, not only in prose
    printf '%s\n' "$sec" | grep -F -- "| ${conditions[$i]} |" >/dev/null
  done
}

@test "AC-035-13 — all 6 hard stops are listed and never converted into a guess" {
  run autopilot_section
  [[ "$output" == *"dirty tree outside the current spec folder"* ]]
  [[ "$output" == *'no repo / no `00-informal.md` / no way to establish requirements'* ]]
  [[ "$output" == *"phase-1 or phase-2 budget exhausted"* ]]
  [[ "$output" == *"deploy failure after 3 attempts"* ]]
  [[ "$output" == *'`30-report.md` missing or not green at PR time'* ]]
  [[ "$output" == *"any never-list action"* ]]
  [[ "$output" == *"never converts a hard stop into a guess"* ]]
}

@test "AC-035-14 — all 9 never-list refusals are listed as refusals, not decisions" {
  run autopilot_section
  [[ "$output" == *"no merge"* ]]
  [[ "$output" == *"no git tag"* ]]
  [[ "$output" == *'no push to `main`/`master`'* ]]
  [[ "$output" == *"no force-push"* ]]
  [[ "$output" == *"no branch deletion"* ]]
  [[ "$output" == *"no gate-threshold change"* ]]
  [[ "$output" == *"no secret creation/rotation"* ]]
  [[ "$output" == *"no writes outside the target repo"* ]]
  [[ "$output" == *'no `git init`/submodule scaffolding'* ]]
  [[ "$output" == *"refusals, not decisions"* ]]
}
