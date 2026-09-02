#!/usr/bin/env bats
# check-common.bats — characterization tests for scripts/check-common.sh
# Sourced-only library: json_escape, require_tools (exit 2 on a missing tool),
# finish_clean (exit 0 "nothing to check"), git_ignore_status / git_repo_usable
# (the three-way ignored / not-ignored / git-error distinction).

load test_helper
bats_require_minimum_version 1.5.0

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

@test "check-common: json_escape escapes backslash, quote, tab and newline" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; source '$REPO_ROOT/scripts/check-common.sh'; json_escape 'a\"b\\c'"
  [ "$status" -eq 0 ]
  [ "$output" = 'a\"b\\c' ]
}

@test "check-common: require_tools exits 2 with an ERROR line when a tool is absent" {
  run --separate-stderr bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/check-common.sh'; require_tools 'demo' definitely-not-a-real-tool-xyz"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"required tool 'definitely-not-a-real-tool-xyz' not found"* ]]
  [[ "$stderr" == *"cannot perform the demo check"* ]]
}

@test "check-common: require_tools returns without exiting when every tool is present" {
  run bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/check-common.sh'; require_tools 'demo' bash grep; echo REACHED"
  [ "$status" -eq 0 ]
  [ "$output" = "REACHED" ]
}

@test "check-common: finish_clean prints the human line and exits 0 when JSON is false" {
  run bash -c "set -euo pipefail; source '$REPO_ROOT/scripts/check-common.sh'; JSON=false; finish_clean 'nothing to check here'; echo UNREACHED"
  [ "$status" -eq 0 ]
  [ "$output" = "nothing to check here" ]
}

@test "check-common: json_escape is not redefined when gate-report-lib already defined it" {
  run bash -c "source '$REPO_ROOT/scripts/gate-report-lib.sh'; before=\$(declare -f json_escape); source '$REPO_ROOT/scripts/check-common.sh'; after=\$(declare -f json_escape); [ \"\$before\" = \"\$after\" ] && echo SAME"
  [ "$status" -eq 0 ]
  [ "$output" = "SAME" ]
}

# ── git_ignore_status: the three-way distinction ─────────────────────────────
# Collapsing exit 1 (a real content finding) into exit 128 (git could not run)
# is what made a corrupted submodule config get reported as "the credential
# files are not gitignored". Each outcome gets its own repo fixture below.

@test "check-common: git_ignore_status reports 'ignored' for a gitignored path" {
  repo="$TMPDIR_HELPER/ignored"
  mkdir -p "$repo/config"
  git -C "$repo" init -q
  printf 'config/agent.local.env\n' > "$repo/.gitignore"
  run bash -c "source '$REPO_ROOT/scripts/check-common.sh'; git_ignore_status '$repo' config/agent.local.env"
  [ "$status" -eq 0 ]
  [ "$output" = "ignored" ]
}

@test "check-common: git_ignore_status reports 'not-ignored' for a committable path" {
  repo="$TMPDIR_HELPER/notignored"
  mkdir -p "$repo/config"
  git -C "$repo" init -q
  run bash -c "source '$REPO_ROOT/scripts/check-common.sh'; git_ignore_status '$repo' config/agent.local.env"
  [ "$status" -eq 0 ]
  [ "$output" = "not-ignored" ]
}

@test "check-common: git_ignore_status reports 'git-error', not 'not-ignored', on a corrupted repo config" {
  # The exact corruption from the incident: core.bare=true alongside
  # core.worktree, which 'git worktree add' can produce in a submodule checkout.
  repo="$TMPDIR_HELPER/corrupt"
  mkdir -p "$repo/config"
  git -C "$repo" init -q
  git -C "$repo" config core.worktree "$repo"
  git -C "$repo" config core.bare true
  run bash -c "source '$REPO_ROOT/scripts/check-common.sh'; git_ignore_status '$repo' config/agent.local.env"
  [ "$status" -eq 0 ]
  [ "$output" = "git-error" ]
  [ "$output" != "not-ignored" ]
}

@test "check-common: git_ignore_status reports 'git-error' outside any repository" {
  plain="$TMPDIR_HELPER/plain"
  mkdir -p "$plain"
  run bash -c "source '$REPO_ROOT/scripts/check-common.sh'; git_ignore_status '$plain' config/agent.local.env"
  [ "$status" -eq 0 ]
  [ "$output" = "git-error" ]
}

# ── git_repo_usable: actionable diagnostic on the corrupted config ───────────

@test "check-common: git_repo_usable returns 0 on a healthy repo and prints nothing" {
  repo="$TMPDIR_HELPER/healthy"
  mkdir -p "$repo"
  git -C "$repo" init -q
  run --separate-stderr bash -c "source '$REPO_ROOT/scripts/check-common.sh'; git_repo_usable '$repo'"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "check-common: git_repo_usable names the cause and the fix on a corrupted repo config" {
  repo="$TMPDIR_HELPER/corrupt2"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config core.worktree "$repo"
  git -C "$repo" config core.bare true
  run --separate-stderr bash -c "source '$REPO_ROOT/scripts/check-common.sh'; git_repo_usable '$repo'"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"repo config is unusable"* ]]
  [[ "$stderr" == *"core.bare=true"* ]]
  [[ "$stderr" == *"core.worktree"* ]]
  [[ "$stderr" == *"git worktree add"* ]]
  [[ "$stderr" == *"core.bare false"* ]]
  [[ "$stderr" == *"worktree prune"* ]]
  # A tooling failure must never be phrased as a content finding.
  [[ "$stderr" != *"not gitignored"* ]]
  [[ "$stderr" != *"committable"* ]]
}
