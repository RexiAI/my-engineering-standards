#!/usr/bin/env bats
# check-pr-review.bats — characterization tests for scripts/check-pr-review.sh
#
# Both tests are discriminating: replacing the script with `exit 0` fails the
# empty-tree test; deleting its clean line fails the happy-path test.
# No AC prefix — these cover script behavior beyond the archived AC-001..007
# scenario list (see scripts/tests/README.md).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-pr-review: clean repo exits 0 and prints its documented clean line" {
  run bash "$REPO_ROOT/scripts/check-pr-review.sh" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PR review agent check: every check passed"* ]]
}

@test "check-pr-review: empty tree exits 1 and names the missing artifact" {
  run bash "$REPO_ROOT/scripts/check-pr-review.sh" "$TMPDIR_HELPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"agents/pr-review.md is missing"* ]]
}

# ── AC-024-01-12 change-set guard — hermetic fixtures for the ADR 0009
# amendment (base-ref resolution + documented-pipeline-change semantics).
# Only the change-set verdict is asserted — other checks may legitimately
# fail in the minimal fixture, so the verdict line is grepped from the
# output, color codes and all (the FAIL/PASS prefix is separated by an
# escape sequence, hence grepping from 'AC-024-01-12' onward).

seed_gate_repo() { # a scratch repo with the exact 8-agent spec roster committed
  local repo="$TMPDIR_HELPER/gate" a
  mkdir -p "$repo/agents" "$repo/docs/adr"
  for a in spec-coder spec-mutation-runner spec-pipeline spec-pr-opener \
    spec-refactorer spec-specifier spec-ux spec-verifier; do
    printf '# agent\n' > "$repo/agents/$a.md"
  done
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "base"
  printf '%s' "$repo"
}

@test "unit: AC-024-01-12 fails when a spec agent changes without a docs/adr change in the set" {
  local repo base
  repo="$(seed_gate_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  printf '# changed agent\n' > "$repo/agents/spec-ux.md"
  run env GITHUB_BASE_SHA="$base" GITHUB_BASE_REF= bash "$REPO_ROOT/scripts/check-pr-review.sh" "$repo"
  [[ "$output" == *"AC-024-01-12: change set modifies agents/spec-*.md without adding or modifying a docs/adr/*.md"* ]]
}

@test "unit: AC-024-01-12 passes a documented pipeline change — spec agent plus untracked ADR in the same set" {
  local repo base
  repo="$(seed_gate_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  printf '# changed agent\n' > "$repo/agents/spec-ux.md"
  printf '# ADR\n' > "$repo/docs/adr/0099-selftest-documented-change.md"
  run env GITHUB_BASE_SHA="$base" GITHUB_BASE_REF= bash "$REPO_ROOT/scripts/check-pr-review.sh" "$repo"
  [[ "$output" == *"AC-024-01-12: change set modifies agents/spec-*.md as a documented pipeline change"* ]]
}

@test "unit: AC-024-01-12 fails loudly when no base ref can be resolved — never a vacuous PASS" {
  local repo
  repo="$(seed_gate_repo)"
  printf '# changed agent\n' > "$repo/agents/spec-ux.md"
  # no remote/origin/main, no GITHUB_BASE_* — the old code passed vacuously here
  run env GITHUB_BASE_SHA= GITHUB_BASE_REF= bash "$REPO_ROOT/scripts/check-pr-review.sh" "$repo"
  [[ "$output" == *"AC-024-01-12: cannot resolve a base ref for the change set"* ]]
  [[ "$output" != *"AC-024-01-12: no agents/spec-*.md file is modified"* ]]
}

@test "unit: AC-024-01-12 passes a clean change set through an explicit GITHUB_BASE_SHA" {
  local repo base
  repo="$(seed_gate_repo)"
  base="$(git -C "$repo" rev-parse HEAD)"
  printf '# unrelated\n' > "$repo/docs/adr/README.md"
  run env GITHUB_BASE_SHA="$base" GITHUB_BASE_REF= bash "$REPO_ROOT/scripts/check-pr-review.sh" "$repo"
  [[ "$output" == *"AC-024-01-12: no agents/spec-*.md file is modified in the change set"* ]]
}
