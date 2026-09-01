#!/usr/bin/env bats
# guard-env.bats — characterization tests for scripts/guard-env.sh
# Covers AC-002-07 (guard script preserves exit contract): 0 clean / 1 when the
# real env file is tracked or staged / 2 on usage error.

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  REPO="$TMPDIR_HELPER/r"
  mkdir -p "$REPO/config"
  git -C "$REPO" init -q 2>/dev/null || { mkdir -p "$REPO"; git -C "$REPO" init -q; }
  git -C "$REPO" config user.email t@e.st
  git -C "$REPO" config user.name Test
  echo ok > "$REPO/README.md"
  git -C "$REPO" add README.md
  git -C "$REPO" commit -qm init
}
teardown() { teardown_tmpdir; }

@test "AC-002-07: guard-env preserves exit contract — clean repo exits 0 with PASS" {
  run bash "$REPO_ROOT/scripts/guard-env.sh" "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PASS"* ]]
  [[ "$output" == *"no config/agent.local.env in the scanned set"* ]]
}

@test "guard-env: tracked config/agent.local.env exits 1 and names the path" {
  echo "TOKEN=x" > "$REPO/config/agent.local.env"
  git -C "$REPO" add -f config/agent.local.env
  git -C "$REPO" commit -qm leak
  run bash "$REPO_ROOT/scripts/guard-env.sh" "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"config/agent.local.env is tracked"* ]]
  [[ "$output" == *"git rm --cached"* ]]
}

@test "guard-env: --staged mode exits 1 when the real env file is staged only" {
  echo "TOKEN=x" > "$REPO/config/agent.local.env"
  git -C "$REPO" add -f config/agent.local.env
  run bash "$REPO_ROOT/scripts/guard-env.sh" --staged "$REPO"
  [ "$status" -eq 1 ]
  [[ "$output" == *"is staged"* ]]
  [[ "$output" == *"git reset"* ]]
}

@test "guard-env: --staged mode exits 0 when nothing sensitive is staged" {
  run bash "$REPO_ROOT/scripts/guard-env.sh" --staged "$REPO"
  [ "$status" -eq 0 ]
  [[ "$output" == *"staged mode"* ]]
}

@test "guard-env: two positional roots is a usage error (exit 2)" {
  run --separate-stderr bash "$REPO_ROOT/scripts/guard-env.sh" "$REPO" "$REPO"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage: guard-env.sh"* ]]
}
