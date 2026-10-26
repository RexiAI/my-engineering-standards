#!/usr/bin/env bats
# check-specs-archived.bats — characterization tests for scripts/check-specs-archived.sh
# Contract: 0 when every finished spec (one with 30-report.md) has its
# docs/changes/NNN-slug.md archive; 1 naming the unarchived slug.
# Index-aware (git ls-files), so fixtures must be committed.

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  REPO="$TMPDIR_HELPER/r"
  mkdir -p "$REPO/specs/001-x" "$REPO/docs/changes"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@e.st
  git -C "$REPO" config user.name Test
}
teardown() { teardown_tmpdir; }

@test "check-specs-archived: no finished specs exits 0 with the all-archived line" {
  echo x > "$REPO/README.md"; git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All finished specs archived."* ]]
}

@test "check-specs-archived: a finished spec with no archive exits 1 and names the missing file" {
  echo r > "$REPO/specs/001-x/30-report.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"001-x is finished (has 30-report.md) but not archived"* ]]
  [[ "$output" == *"docs/changes/001-x.md"* ]]
  [[ "$output" == *"scripts/archive-spec.sh 001-x"* ]]
}

@test "check-specs-archived: a finished spec with its archive exits 0 and prints [OK]" {
  echo r > "$REPO/specs/001-x/30-report.md"
  echo a > "$REPO/docs/changes/001-x.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] 001-x archived -> docs/changes/001-x.md"* ]]
}

# ── spec 031 exception: anchored, and only as a marker + verdict pair ─────────
# Regression: the exception used to grep the literal marker anywhere in the
# file, so a 40-deploy.md that merely *mentioned* the string in prose satisfied
# it and let a finished spec skip archiving silently. The marker and the
# escalation verdict must now each start a line.

@test "check-specs-archived: prose mentioning the budget marker does not satisfy the exception" {
  printf 'r\n' > "$REPO/specs/001-x/30-report.md"
  printf '# 40-deploy\n\nHealth check and E2E both passed on attempt 1, so no Phase-3 budget exhausted marker applies and the overall line is Verdict: PASS.\n' \
    > "$REPO/specs/001-x/40-deploy.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"001-x is finished (has 30-report.md) but not archived"* ]]
  [[ "$output" != *"archival deferred to the human"* ]]
}

@test "check-specs-archived: a line-start marker plus Verdict: ESCALATED defers archival" {
  printf 'r\n' > "$REPO/specs/001-x/30-report.md"
  printf '# 40-deploy\n\nPhase-3 budget exhausted\n\nVerdict: ESCALATED\n' \
    > "$REPO/specs/001-x/40-deploy.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] 001-x phase-3 budget exhausted"* ]]
}

@test "check-specs-archived: a bulleted marker plus bulleted verdict defers archival" {
  printf 'r\n' > "$REPO/specs/001-x/30-report.md"
  printf '# 40-deploy\n\n- **Phase-3 budget exhausted**\n- **Verdict: ESCALATED**\n' \
    > "$REPO/specs/001-x/40-deploy.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] 001-x phase-3 budget exhausted"* ]]
}

@test "check-specs-archived: a line-start marker without an ESCALATED verdict still fails" {
  printf 'r\n' > "$REPO/specs/001-x/30-report.md"
  printf '# 40-deploy\n\nPhase-3 budget exhausted\n\nVerdict: FAIL\n' \
    > "$REPO/specs/001-x/40-deploy.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"001-x is finished (has 30-report.md) but not archived"* ]]
}

@test "check-specs-archived: a mid-line verdict mention does not satisfy the exception" {
  printf 'r\n' > "$REPO/specs/001-x/30-report.md"
  printf '# 40-deploy\n\nThe pipeline stopped for the reason recorded as Verdict: ESCALATED in the phase-3 log, see Phase-3 budget exhausted above.\n' \
    > "$REPO/specs/001-x/40-deploy.md"
  git -C "$REPO" add -A; git -C "$REPO" commit -qm i
  run bash -c "cd '$REPO' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"001-x is finished (has 30-report.md) but not archived"* ]]
}
