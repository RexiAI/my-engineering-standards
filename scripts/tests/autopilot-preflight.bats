#!/usr/bin/env bats
# autopilot-preflight.bats — acceptance tests for spec 035 Task 8
# (specs/035-autopilot-mode/20-acceptance/AC-035-preflight.md).
# Offline-safe: `gh` is a stub on PATH (no live GitHub), tokens are literals,
# and the optional judgment backend is exercised only against a loopback
# address that refuses instantly.

load test_helper
bats_require_minimum_version 1.5.0

PREFLIGHT="$REPO_ROOT/scripts/autopilot-preflight.sh"

setup() {
  setup_tmpdir
  REPO="$TMPDIR_HELPER/repo"
  STUB="$TMPDIR_HELPER/bin"
  mkdir -p "$REPO" "$STUB"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email "test@example.com"
  git -C "$REPO" config user.name "Test"
  printf 'seed\n' > "$REPO/README.md"
  git -C "$REPO" add README.md
  git -C "$REPO" commit -qm seed

  cat > "$STUB/gh" <<'SH'
#!/bin/sh
# offline gh stub — success unless GH_STUB_EXIT says otherwise
exit "${GH_STUB_EXIT:-0}"
SH
  chmod +x "$STUB/gh"
}

teardown() { teardown_tmpdir; }

run_ok() {
  run --separate-stderr env PATH="$STUB:$PATH" GITHUB_TOKEN=tok GH_TOKEN=tok \
    bash "$PREFLIGHT" --root "$REPO" "$@"
}

@test "AC-035-24 — a tree dirty only inside specs/<slug>/ passes" {
  mkdir -p "$REPO/specs/001-x"
  printf '# informal\n' > "$REPO/specs/001-x/00-informal.md"
  run_ok 001-x
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "AC-035-25 — gh auth, GITHUB_TOKEN, and GH_TOKEN are required and fail fast" {
  run --separate-stderr env PATH="$STUB:$PATH" GH_STUB_EXIT=1 GITHUB_TOKEN=tok GH_TOKEN=tok \
    bash "$PREFLIGHT" --root "$REPO" 001-missing
  [ "$status" -ne 0 ]
  [[ "$stderr" == preflight:* ]]
  [[ "$stderr" == *"gh auth"* ]]
  # must not continue to later checks
  [[ "$stderr" != *"001-missing"* ]]

  run --separate-stderr env PATH="$STUB:$PATH" GITHUB_TOKEN= GH_TOKEN=tok \
    bash "$PREFLIGHT" --root "$REPO" 001-missing
  [ "$status" -ne 0 ]
  [[ "$stderr" == preflight:* ]]
  [[ "$stderr" == *"GITHUB_TOKEN"* ]]
  [[ "$stderr" != *"001-missing"* ]]

  run --separate-stderr env PATH="$STUB:$PATH" GITHUB_TOKEN=tok GH_TOKEN= \
    bash "$PREFLIGHT" --root "$REPO" 001-missing
  [ "$status" -ne 0 ]
  [[ "$stderr" == preflight:* ]]
  [[ "$stderr" == *"GH_TOKEN"* ]]
  [[ "$stderr" != *"001-missing"* ]]
}

@test "AC-035-26 — a named slug whose spec folder does not exist fails with a reason" {
  run_ok 042-absent
  [ "$status" -ne 0 ]
  [[ "$stderr" == preflight:* ]]
  [[ "$stderr" == *"042-absent"* ]]
}

@test "AC-035-27 — the judgment backend is optional and never fails preflight" {
  mkdir -p "$REPO/specs/001-x"
  printf '# informal\n' > "$REPO/specs/001-x/00-informal.md"
  # unconfigured
  run_ok 001-x
  [ "$status" -eq 0 ]

  # explicitly configured but unreachable: warning, still exit 0
  run --separate-stderr env PATH="$STUB:$PATH" GITHUB_TOKEN=tok GH_TOKEN=tok \
    JUDGMENT_BACKEND=local JUDGMENT_API_URL=http://127.0.0.1:1 \
    bash "$PREFLIGHT" --root "$REPO" 001-x
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"judgment backend"* ]]
}

@test "unit — a dirty path outside the current spec folder fails, and so does a non-repo" {
  printf 'dirty\n' >> "$REPO/README.md"
  run_ok 001-x
  [ "$status" -ne 0 ]
  [[ "$stderr" == preflight:* ]]
  [[ "$stderr" == *"README.md"* ]]

  local plain="$TMPDIR_HELPER/plain"
  mkdir -p "$plain"
  run --separate-stderr env PATH="$STUB:$PATH" GITHUB_TOKEN=tok GH_TOKEN=tok \
    bash "$PREFLIGHT" --root "$plain"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"git"* ]]
}
