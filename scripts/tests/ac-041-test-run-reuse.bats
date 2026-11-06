#!/usr/bin/env bats
# ac-041-test-run-reuse.bats — acceptance tests for spec 041 Task 4
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-test-run-reuse-script.md).
#
# Every scenario runs against a scratch git repository under $TMPDIR_HELPER; the
# repo's own worktree is never touched.

load test_helper
bats_require_minimum_version 1.5.0

SCRIPT="$REPO_ROOT/scripts/test-run-reuse.sh"

setup() {
  setup_tmpdir
  REPO="$(setup_git_repo "$TMPDIR_HELPER/repo")"
  printf 'a\n' > "$REPO/a.txt"
  git -C "$REPO" add -A
  git -C "$REPO" commit -qm seed >/dev/null 2>&1
}
teardown() { teardown_tmpdir; }

# hash_now — the current fingerprint, computed from inside the scratch repo.
hash_now() { ( cd "$REPO" && bash "$SCRIPT" --print-hash ); }

# write_verification <file> <exit-value> <hash-line-or-none> [extra-block]
write_verification() {
  local file="$1" xc="$2" hash_line="$3"
  {
    printf '# Verification\n\n## Evidence: scenario traceability\n\ncommand: x\nexit: 0\nat: 2026-01-01T00:00:00Z\n\nok\n\n'
    printf '## Evidence: full test suite\n\ncommand: make test\nexit: %s\nat: 2026-01-01T00:00:01Z\n' "$xc"
    [ "$hash_line" = "none" ] || printf 'Test-run hash: %s\n' "$hash_line"
    printf '\nSUMMARY: mode=run exit=%s signal=0 log_lines=1 log=/tmp/t.log\n\n' "$xc"
    printf '## Evidence: complexity gate\n\ncommand: y\nexit: 0\nat: 2026-01-01T00:00:02Z\n\nok\n'
  } > "$file"
}

@test "AC-041-27 — hash output is one lowercase sha256 line" {
  local h
  h="$(hash_now)"
  [[ "$h" =~ ^[0-9a-f]{64}$ ]]
  cd "$REPO" || return 1
  run bash "$SCRIPT" --print-hash
  [ "$status" -eq 0 ]
  [ "$(wc -l <<< "$output" | tr -d ' ')" -eq 1 ]
}

@test "AC-041-28 — the hash is deterministic on an unchanged tree" {
  local first second
  printf 'dirty\n' >> "$REPO/a.txt"
  first="$(hash_now)"
  second="$(hash_now)"
  [ "$first" = "$second" ]
  [ "${#first}" -eq 64 ]
}

@test "AC-041-29 — a tracked content change changes the hash" {
  local before after
  before="$(hash_now)"
  printf 'changed\n' >> "$REPO/a.txt"
  after="$(hash_now)"
  [ "$before" != "$after" ]
}

@test "AC-041-30 — a new untracked file changes the hash" {
  local before after
  before="$(hash_now)"
  mkdir -p "$REPO/newdir/sub"
  printf 'x\n' > "$REPO/newdir/sub/x.txt"
  after="$(hash_now)"
  [ "$before" != "$after" ]
}

@test "AC-041-31 — a new commit changes the hash" {
  local before after
  before="$(hash_now)"
  git -C "$REPO" commit -q --allow-empty -m empty >/dev/null 2>&1
  after="$(hash_now)"
  [ "$before" != "$after" ]
}

@test "AC-041-32 — a matching hash authorizes reuse" {
  local h v
  h="$(hash_now)"
  v="$TMPDIR_HELPER/matching.md"
  write_verification "$v" 0 "$h"
  cd "$REPO" || return 1
  run bash "$SCRIPT" --check "$v"
  [ "$status" -eq 0 ]
  [ "$output" = "REUSE $h" ]
}

@test "AC-041-33 — a hash mismatch forces a re-run" {
  local v
  v="$TMPDIR_HELPER/mismatch.md"
  write_verification "$v" 0 "$(printf '0%.0s' $(seq 1 64))"
  cd "$REPO" || return 1
  run bash "$SCRIPT" --check "$v"
  [ "$status" -eq 1 ]
  [ "$output" = "RERUN hash-mismatch" ]
}

@test "AC-041-34 — no evidence block forces a re-run" {
  local v="$TMPDIR_HELPER/noblock.md"
  printf '# Verification\n\nNo full-suite evidence here.\n' > "$v"
  cd "$REPO" || return 1
  run bash "$SCRIPT" --check "$v"
  [ "$status" -eq 1 ]
  [ "$output" = "RERUN no-evidence-block" ]
}

@test "AC-041-35 — a non-zero recorded exit forces a re-run" {
  local v
  v="$TMPDIR_HELPER/nonzero.md"
  write_verification "$v" 1 "$(hash_now)"
  cd "$REPO" || return 1
  run bash "$SCRIPT" --check "$v"
  [ "$status" -eq 1 ]
  [ "$output" = "RERUN exit-nonzero" ]
}

@test "AC-041-36 — a missing hash line forces a re-run" {
  local v="$TMPDIR_HELPER/nohash.md"
  write_verification "$v" 0 none
  cd "$REPO" || return 1
  run bash "$SCRIPT" --check "$v"
  [ "$status" -eq 1 ]
  [ "$output" = "RERUN hash-missing" ]
}

@test "AC-041-37 — usage error and non-repo are tooling errors" {
  local plain="$TMPDIR_HELPER/plain"
  mkdir -p "$plain"
  cd "$plain" || return 1
  run bash "$SCRIPT" --print-hash
  [ "$status" -eq 2 ]
  [[ ! "$output" =~ ^[0-9a-f]{64}$ ]]
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage:"* ]]
}

@test "unit — a deleted tracked file changes the hash" {
  local before after
  before="$(hash_now)"
  rm "$REPO/a.txt"
  after="$(hash_now)"
  [ "$before" != "$after" ]
}

@test "unit — recording the hash in the evidence file leaves the fingerprint unchanged (REUSE)" {
  local v h
  mkdir -p "$REPO/specs/999-reuse"
  v="$REPO/specs/999-reuse/25-verification.md"
  write_verification "$v" 0 none
  h="$(hash_now)"
  write_verification "$v" 0 "$h"
  [ "$(hash_now)" = "$h" ]
  cd "$REPO" || return 1
  run bash "$SCRIPT" --check "$v"
  [ "$status" -eq 0 ]
  [ "$output" = "REUSE $h" ]
}

@test "unit — a runs.jsonl telemetry append is excluded from the fingerprint" {
  local before
  before="$(hash_now)"
  printf '{"gate":"test-suite","outcome":"pass"}\n' > "$REPO/runs.jsonl"
  [ "$(hash_now)" = "$before" ]
}

@test "unit — the evidence exclusion does not hide a dirty tracked file" {
  local v before after
  mkdir -p "$REPO/specs/999-reuse"
  v="$REPO/specs/999-reuse/25-verification.md"
  write_verification "$v" 0 none
  before="$(hash_now)"
  printf 'dirty\n' >> "$REPO/a.txt"
  after="$(hash_now)"
  [ "$before" != "$after" ]
}

@test "unit — an unreadable verification file is exit 2 with nothing on stdout" {
  cd "$REPO" || return 1
  run --separate-stderr bash "$SCRIPT" --check "$TMPDIR_HELPER/absent.md"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"absent.md"* ]]
}

@test "unit — --help prints usage and exits 0" {
  run bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--print-hash"* ]]
}
