#!/usr/bin/env bats
# check-stop-and-ask-matrix.bats — characterization tests for
# scripts/check-stop-and-ask-matrix.sh
#
# Deliberately fixture-driven, not run against the repo root: the script's
# AC-009-03-03 assertion fails on any *uncommitted* working-tree change to
# scripts/check-code-principles.sh, so a repo-root run is not deterministic
# mid-branch. Both fixtures below are hermetic.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-stop-and-ask-matrix: an empty tree cannot be checked and exits 2" {
  run --separate-stderr bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"docs/SPEC_PIPELINE.md"* ]]
}

@test "check-stop-and-ask-matrix: a matrix missing the design-gate row exits 1 with FAIL AC-009" {
  mkdir -p "$TMPDIR_HELPER/docs" "$TMPDIR_HELPER/agents" "$TMPDIR_HELPER/scripts"
  cat > "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md" <<'MD'
## Stop-and-Ask decision matrix

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report |
MD
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"AC-009-01-01 — '## Stop-and-Ask decision matrix' heading present"* ]]
  [[ "$output" == *"AC-009-01-02 — section must state the matrix is authoritative"* ]]
  [[ "$output" == *"matrix row missing or altered"* ]]
  [[ "$output" == *"Fix the code, never the threshold"* ]]
}

@test "check-stop-and-ask-matrix: the design-gate row wording is asserted verbatim" {
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$REPO_ROOT"
  [[ "$output" == *"Fix the code, never the threshold"* ]]
  [[ "$output" == *"AC-009-03-04"* ]]
}

# ── spec 035 extensions: the autopilot contract ──────────────────────────────
# The fixture copies the real doc + agents so the autopilot section and agent
# references are the ones under test; each case then breaks exactly one thing.

make_autopilot_fixture() {
  local root="$1"
  mkdir -p "$root/scripts" "$root/docs" "$root/agents"
  cp "$REPO_ROOT/docs/SPEC_PIPELINE.md" "$root/docs/SPEC_PIPELINE.md"
  cp "$REPO_ROOT/agents/"*.md "$root/agents/"
  cp "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$root/scripts/"
  cp "$REPO_ROOT/scripts/check-code-principles.sh" "$root/scripts/"
  chmod +x "$root/scripts/check-stop-and-ask-matrix.sh" "$root/scripts/check-code-principles.sh"
}

strip_autopilot_section() {
  local file="$1" tmp="$1.tmp"
  awk '
    /^## / { if (skip) skip = 0 }
    /^## Autopilot mode$/ { skip = 1; next }
    !skip { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

@test "AC-035-30 — a matrix without the Autopilot mode section FAILs AC-035-30" {
  make_autopilot_fixture "$TMPDIR_HELPER"
  strip_autopilot_section "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md"
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *$'\033[0;31mFAIL'* ]]
  [[ "$output" == *"AC-035-30"* ]]
  [[ "$output" == *"missing the '## Autopilot mode' section"* ]]
}

@test "AC-035-31 — a missing disposition for one matrix row FAILs AC-035-31 naming it" {
  make_autopilot_fixture "$TMPDIR_HELPER"
  grep -vF '| Deploy verification fails |' \
    "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md" > "$TMPDIR_HELPER/doc.tmp"
  mv "$TMPDIR_HELPER/doc.tmp" "$TMPDIR_HELPER/docs/SPEC_PIPELINE.md"
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *$'\033[0;31mFAIL'* ]]
  [[ "$output" == *"AC-035-31"* ]]
  [[ "$output" == *"Deploy verification fails"* ]]
}

@test "AC-035-32 — an unconditional question phrase with no autopilot reference FAILs AC-035-32" {
  make_autopilot_fixture "$TMPDIR_HELPER"
  printf '\nAsk the user before continuing.\n' >> "$TMPDIR_HELPER/agents/spec-coder.md"
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *$'\033[0;31mFAIL'* ]]
  [[ "$output" == *"AC-035-32"* ]]
  [[ "$output" == *"spec-coder.md"* ]]
}

@test "unit — the complete fixture passes the autopilot checks (exit 0)" {
  make_autopilot_fixture "$TMPDIR_HELPER"
  run bash "$REPO_ROOT/scripts/check-stop-and-ask-matrix.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"AC-035-30"* ]]
  [[ "$output" == *"AC-035-31"* ]]
  [[ "$output" == *"AC-035-32"* ]]
  [[ "$output" != *$'\033[0;31mFAIL'* ]]
}
