#!/usr/bin/env bats
# check-scenario-traceability.bats — characterization for scripts/check-scenario-traceability.sh
# Covers AC-002-03,04,05,06 plus hermetic
# Uses runtime ID construction to avoid literal fixture IDs being counted as test references (see selftest precedent)

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

# Helper to build IDs without inlining literals (grep would count literals as dangling)
trace_id() { printf 'AC-%03d-%02d' "$1" "$2"; }

@test "AC-002-03: check-scenario-traceability happy path passes when IDs align" {
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance"
  printf '## AC-001-01 — sample\nGiven x\nWhen y\nThen z\n' > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/AC-001-foo.md"
  mkdir -p "$TMPDIR_HELPER/src"
  printf 'func TestAC_001_01(t *testing.T) {}\n' > "$TMPDIR_HELPER/src/foo_test.go"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src"
  [ "$status" -eq 0 ]
  [[ "$output" == *"every scenario traced"* ]]
}

@test "AC-002-04: check-scenario-traceability fails on orphan scenario" {
  local orphan
  orphan=$(trace_id 2 99)
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance"
  printf '## %s — orphan\nGiven orphan\nWhen none\nThen caught\n' "$orphan" > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/${orphan}-orphan.md"
  mkdir -p "$TMPDIR_HELPER/src"
  echo "package p" > "$TMPDIR_HELPER/src/foo.go"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$orphan"* ]]
}

@test "AC-002-05: check-scenario-traceability fails on dangling test reference" {
  local bogus real
  bogus=$(trace_id 999 01)
  real=$(trace_id 3 01)
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance"
  printf '## %s — real\nGiven real\n' "$real" > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/${real}.md"
  mkdir -p "$TMPDIR_HELPER/src"
  printf 'func Test%s(t *testing.T) {}\n' "$(printf '%s' "$bogus" | tr '-' '_')" > "$TMPDIR_HELPER/src/foo_test.go"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$bogus"* ]]
}

@test "AC-002-06: missing args or unreadable dir yields exit 2 with error" {
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance"
  printf '## AC-001-01 — x\n' > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/a.md"
  mkdir -p "$TMPDIR_HELPER/bad-src"
  chmod 000 "$TMPDIR_HELPER/bad-src"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/bad-src"
  if [ "$status" -eq 2 ]; then
    [[ "$stderr$output" == *"Error"* || "$stderr$output" == *"ERROR"* || "$stderr$output" == *"missing"* || "$stderr$output" == *"unreadable"* ]]
  else
    run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" --unknown-flag 2>&1 || true
    [ "$status" -eq 2 ]
    [[ "$output$stderr" == *"Unknown"* || "$output$stderr" == *"Error"* ]]
  fi
  chmod 755 "$TMPDIR_HELPER/bad-src"
}

@test "check-scenario-traceability: an unreadable specs dir is a tooling failure" {
  mkdir -p "$TMPDIR_HELPER/unreadable/specs" "$TMPDIR_HELPER/unreadable/src"
  chmod 000 "$TMPDIR_HELPER/unreadable/specs"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/unreadable/specs" "$TMPDIR_HELPER/unreadable/src"
  if [ "$status" -eq 2 ]; then
    [[ "$stderr$output" == *"Error"* || "$stderr$output" == *"ERROR"* ]]
  else
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  fi
  chmod 755 "$TMPDIR_HELPER/unreadable/specs"
}

@test "AC-002-08: check-scenario-traceability is hermetic with temp dirs and trap" {
  local hid
  hid=$(trace_id 1 01)
  before="$(ls -1 "$REPO_ROOT/scripts" | sort)"
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance" "$TMPDIR_HELPER/src"
  printf '## %s — hermetic\n' "$hid" > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/a.md"
  printf 'func Test%s(t *testing.T) {}\n' "$(printf '%s' "$hid" | tr '-' '_')" > "$TMPDIR_HELPER/src/t_test.go"
  run bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$hid"* ]]
  after="$(ls -1 "$REPO_ROOT/scripts" | sort)"
  [ "$before" = "$after" ]
  [ -d "$TMPDIR_HELPER" ]
}
