#!/usr/bin/env bats
# ac-031-archive-ordering.bats — acceptance tests for spec 031 Task 5
# (specs/031-vercel-deploy-lane/20-acceptance/AC-031-archive-ordering.md).
# archive-spec.sh behavior is exercised in scratch git repos (hermetic, same
# pattern as archive-spec.bats); check-specs-archived.sh likewise.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# seed_finished_spec <repo> <slug> — a minimal finished spec, committed
seed_finished_spec() {
  local repo="$1" slug="${2:-902-ev}"
  local spec="$repo/specs/$slug"
  mkdir -p "$spec/20-acceptance" "$repo/docs/changes"
  printf '# tasks\n\ntask list\n' > "$spec/10-tasks.md"
  printf '## AC-902-01: scenario one\n\nGiven/When/Then\n' > "$spec/20-acceptance/AC-902-01.md"
  printf '# verification\n\nverdict\n' > "$spec/25-verification.md"
  printf '# report\n\ngates green\n' > "$spec/30-report.md"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "seed $slug"
}

@test "AC-031-22 — archive-spec.sh embeds 40-deploy.md verbatim under its own heading" {
  local repo="$TMPDIR_HELPER/repo"
  seed_finished_spec "$repo"
  local spec="$repo/specs/902-ev"
  printf 'Verdict: PASS\n\nDeploy URL: https://902-ev.vercel.app\nat: 2026-10-19T10:00:00Z\n' > "$spec/40-deploy.md"
  cp "$spec/40-deploy.md" "$TMPDIR_HELPER/expected.md"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "add 40-deploy.md"
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/archive-spec.sh' 902-ev"
  [ "$status" -eq 0 ]
  local archive="$repo/docs/changes/902-ev.md"
  grep -q '^## 40-deploy\.md$' "$archive"
  awk '/^## 40-deploy\.md$/{f=1;next} f' "$archive" | sed -e '/./,$!d' > "$TMPDIR_HELPER/embedded.md"
  # verbatim until the next NN-artifact heading (none here) or EOF
  diff "$TMPDIR_HELPER/expected.md" "$TMPDIR_HELPER/embedded.md"
}

@test "AC-031-23 — archive-spec.sh still refuses without 30-report.md (exit non-zero, not finished)" {
  local repo="$TMPDIR_HELPER/repo"
  seed_finished_spec "$repo"
  rm "$repo/specs/902-ev/30-report.md"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "unfinish"
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/archive-spec.sh' 902-ev"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not finished"* ]]
}

@test "AC-031-24 — check-specs-archived.sh: existing archive without any 40-deploy.md history still passes" {
  local repo="$TMPDIR_HELPER/repo"
  mkdir -p "$repo/docs/changes"
  git -C "$repo" init -q
  git -C "$repo" config user.email "t@e.st"; git -C "$repo" config user.name T
  printf '# 001-old archived spec\n' > "$repo/docs/changes/001-old.md"
  git -C "$repo" add -A
  git -C "$repo" commit -qm archive-only
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All finished specs archived."* ]]
}

@test "AC-031-25 — phase-3 budget exhausted (ESCALATED + marker, no archive): exits 0, no false failure" {
  local repo="$TMPDIR_HELPER/repo"
  seed_finished_spec "$repo" "099-ex"
  local spec="$repo/specs/099-ex"
  printf 'Verdict: ESCALATED\n\nPhase-3 budget exhausted — 3 fix-and-redeploy rounds failed.\n' > "$spec/40-deploy.md"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "escalated deploy"
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" != *"not archived"* ]]
  [[ "$output" == *"099-ex"* ]]
}

@test "unit — the exception needs BOTH a line-start marker and Verdict: ESCALATED" {
  # This assertion changed with the anchoring fix: the exception used to accept
  # either signal anywhere in the file (OR, unanchored grep). It now requires
  # the marker line AND the ESCALATED verdict line, each at line start — see
  # check-specs-archived.sh §Spec 031 exception. A verdict alone is not enough,
  # and prose that merely mentions either string never was.
  local repo="$TMPDIR_HELPER/repo"
  seed_finished_spec "$repo" "099-e2"
  printf 'Verdict: ESCALATED\n' > "$repo/specs/099-e2/40-deploy.md"
  git -C "$repo" add -A && git -C "$repo" commit -qm esc
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"099-e2 is finished"* ]]

  local repo1="$TMPDIR_HELPER/repo1"
  seed_finished_spec "$repo1" "099-m1"
  printf 'Phase-3 budget exhausted\n' > "$repo1/specs/099-m1/40-deploy.md"
  git -C "$repo1" add -A && git -C "$repo1" commit -qm marker-only
  run bash -c "cd '$repo1' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"099-m1 is finished"* ]]

  local repo3="$TMPDIR_HELPER/repo3"
  seed_finished_spec "$repo3" "099-e3"
  printf 'Phase-3 budget exhausted\n\nVerdict: ESCALATED\n' > "$repo3/specs/099-e3/40-deploy.md"
  git -C "$repo3" add -A && git -C "$repo3" commit -qm both
  run bash -c "cd '$repo3' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 0 ]

  local repo2="$TMPDIR_HELPER/repo2"
  seed_finished_spec "$repo2" "099-p1"
  printf 'Verdict: PASS\nDeploy URL: https://x.vercel.app\n' > "$repo2/specs/099-p1/40-deploy.md"
  git -C "$repo2" add -A && git -C "$repo2" commit -qm pass-no-archive
  run bash -c "cd '$repo2' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"099-p1 is finished"* ]]
}

@test "AC-031-26 — pre-031 in-flight spec (30-report.md, no 40-deploy.md) still requires archival" {
  local repo="$TMPDIR_HELPER/repo"
  seed_finished_spec "$repo" "098-pre"
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/check-specs-archived.sh'"
  [ "$status" -eq 1 ]
  [[ "$output" == *"098-pre is finished (has 30-report.md) but not archived"* ]]
}

@test "AC-031-27 — both scripts still key finished-spec detection off 30-report.md" {
  grep -qF '"$SPEC_DIR/30-report.md"' "$REPO_ROOT/scripts/archive-spec.sh"
  grep -qF "git ls-files 'specs/*/30-report.md'" "$REPO_ROOT/scripts/check-specs-archived.sh"
}
