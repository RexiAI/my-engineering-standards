#!/usr/bin/env bats
# archive-spec.bats — characterization tests for scripts/archive-spec.sh
#
# Usage and not-found paths are fully hermetic. The success path runs in a
# scratch git repo under $TMPDIR_HELPER (never the real tree), so it is safe
# to exercise here too — spec 029 phase-2 added that coverage to pin the
# verbatim-embedding contract for remaining NN-*.md evidence artifacts.

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "archive-spec: no slug exits 1 and prints the usage line" {
  run bash "$REPO_ROOT/scripts/archive-spec.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: archive-spec.sh NNN-slug"* ]]
}

@test "archive-spec: two arguments is still a usage error" {
  run bash "$REPO_ROOT/scripts/archive-spec.sh" 001-a 002-b
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage: archive-spec.sh NNN-slug"* ]]
}

@test "archive-spec: a nonexistent spec exits 1 and names the missing folder" {
  run bash "$REPO_ROOT/scripts/archive-spec.sh" 999-does-not-exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"specs/999-does-not-exist does not exist"* ]]
}

# seed_archive_repo — a minimal finished spec in a scratch git repo (all paths
# under $TMPDIR_HELPER; the real tree is never touched). 30-report.md exists so
# the "finished spec" preflight passes; the folder is committed so the script's
# `git rm -r` succeeds.
seed_archive_repo() {
  local repo="$TMPDIR_HELPER/repo" spec="$TMPDIR_HELPER/repo/specs/900-ev"
  mkdir -p "$spec/20-acceptance"
  printf '# informal\n\nthe ask\n' > "$spec/00-informal.md"
  printf '# tasks\n\ntask list\n' > "$spec/10-tasks.md"
  printf '# verification\n\nverdict\n' > "$spec/25-verification.md"
  printf '# report\n\ngates green\n' > "$spec/30-report.md"
  printf '## AC-900-01: scenario one\n\nGiven/When/Then\n' > "$spec/20-acceptance/AC-900-01.md"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "seed spec 900-ev"
}

@test "archive-spec: remaining NN-*.md evidence embeds verbatim under its own heading" {
  # Spec 029 phase-2 contract: archiving must not destroy evidence artifacts
  # beyond the four composed docs — content contracts grep their ^## anchors
  # in the one-pager after specs/ is gone.
  seed_archive_repo
  local repo="$TMPDIR_HELPER/repo"
  local spec="$repo/specs/900-ev"
  printf '## Candidate results\n\n### Sentinel-9B\n\n**Skip reason:** EXACT-BLOCK-42c1\n' > "$spec/35-evidence.md"
  cp "$spec/35-evidence.md" "$TMPDIR_HELPER/evidence-expected.md"
  # commit the evidence too — in the real pipeline spec files are tracked
  # before stage 5b, and `git rm -r` only removes tracked paths
  git -C "$repo" add -A
  git -C "$repo" commit -qm "add 35-evidence.md"
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/archive-spec.sh' 900-ev"
  [ "$status" -eq 0 ]
  local archive="$repo/docs/changes/900-ev.md"
  [ -f "$archive" ]
  [ ! -d "$spec" ]  # the success path ran to completion (spec folder removed)
  grep -q '^## 35-evidence\.md$' "$archive"
  # verbatim: the bytes between the heading and EOF equal the source file
  awk '/^## 35-evidence\.md$/{f=1;next} f' "$archive" | sed -e '/./,$!d' \
    > "$TMPDIR_HELPER/embedded.md"
  diff "$TMPDIR_HELPER/evidence-expected.md" "$TMPDIR_HELPER/embedded.md"
  # the four composed docs are embedded through their sections only — never
  # re-embedded as a second "## <NN-file>.md" copy: no duplicate heading, and
  # 00-informal's body text ("the ask") appears exactly once.
  ! grep -qE '^## (00-informal|10-tasks|25-verification|30-report)\.md$' "$archive"
  [ "$(grep -c 'the ask' "$archive")" -eq 1 ]
}

@test "archive-spec: multiple evidence artifacts embed in filename order" {
  seed_archive_repo
  local repo="$TMPDIR_HELPER/repo"
  local spec="$repo/specs/900-ev"
  printf '## Later body\n' > "$spec/40-later.md"
  printf '## Early body\n' > "$spec/35-early.md"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "add evidence artifacts"
  run bash -c "cd '$repo' && bash '$REPO_ROOT/scripts/archive-spec.sh' 900-ev"
  [ "$status" -eq 0 ]
  local archive="$repo/docs/changes/900-ev.md" a b
  a=$(grep -n '^## 35-early\.md$' "$archive" | cut -d: -f1)
  b=$(grep -n '^## 40-later\.md$' "$archive" | cut -d: -f1)
  [ -n "$a" ]
  [ -n "$b" ]
  [ "$a" -lt "$b" ]
}
