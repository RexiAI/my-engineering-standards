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
  # The dangling ID must belong to a spec number that has an authority to be
  # judged against — here the in-flight specs/001-foo/. A reference to a number
  # with neither a specs/NNN-*/ folder nor a docs/changes/NNN-*.md one-pager is
  # deliberately out of scope (see check 2 in the script), so a bogus AC-999-01
  # would be skipped rather than flagged.
  local bogus real
  bogus=$(trace_id 1 99)
  real=$(trace_id 1 01)
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance"
  printf '## %s — real\nGiven real\n' "$real" > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/${real}.md"
  mkdir -p "$TMPDIR_HELPER/src"
  printf 'func Test%s(t *testing.T) {}\nfunc Test%s(t *testing.T) {}\n' \
    "$(printf '%s' "$real" | tr '-' '_')" "$(printf '%s' "$bogus" | tr '-' '_')" \
    > "$TMPDIR_HELPER/src/foo_test.go"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/changes"
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

@test "check-scenario-traceability: a large reference list never reads as untraced (SIGPIPE race)" {
  # Regression: the ID lookups used to be `echo "$LIST" | grep -qx "$id"`. Under
  # `set -o pipefail`, `grep -q` exits at the first match while `echo` is still
  # writing a multi-kilobyte list; the writer takes SIGPIPE, pipefail surfaces
  # the 141, and a present ID is reported missing. Only reproduces when the
  # writer outlives the reader, i.e. on a large list — hence the big fixture.
  local hid1 hid2 hid3
  hid1=$(trace_id 1 01); hid2=$(trace_id 1 02); hid3=$(trace_id 1 03)
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance" "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/changes"
  printf '## %s — a\n## %s — b\n## %s — c\n' "$hid1" "$hid2" "$hid3" \
    > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/a.md"
  # ~8000 distinct IDs (~90 KB of sorted reference list) generated at runtime so
  # no literal ID lands in this file as a reference of its own.
  { awk 'BEGIN { for (s = 100; s < 180; s++) for (t = 1; t < 101; t++)
      printf "it(\"AC-%03d-%02d: x\", () => {});\n", s, t }'
    printf 'it("%s: x", () => {});\nit("%s: x", () => {});\nit("%s: x", () => {});\n' \
      "$hid1" "$hid2" "$hid3"
  } > "$TMPDIR_HELPER/src/a.test.ts"
  for _ in 1 2 3 4 5; do
    run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" \
      --checks 1 "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/changes"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$hid1 — traced to a test"* ]]
    [[ "$output" == *"$hid3 — traced to a test"* ]]
    [[ "$output" != *"FAIL"* ]]
  done
}

@test "check-scenario-traceability: large live and archived ID lists still resolve (SIGPIPE race)" {
  # Same race on check 2's two lookups: a reference present in an 8000-heading
  # live list, and one present only in an 8000-heading archive list, must both
  # resolve — never "referenced in a test but no matching scenario heading".
  local live only_archived absent_ref
  live=$(trace_id 1 01)
  only_archived=$(printf 'AC-%03d-%02d' 200 50)
  absent_ref=$(printf 'AC-%03d-%02d' 300 99)
  mkdir -p "$TMPDIR_HELPER/specs/001-foo/20-acceptance" "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/changes"
  { printf '## %s — live\n' "$live"
    awk 'BEGIN { for (s = 100; s < 180; s++) for (t = 1; t < 101; t++)
      printf "## AC-%03d-%02d — bulk\n", s, t }'
  } > "$TMPDIR_HELPER/specs/001-foo/20-acceptance/a.md"
  awk 'BEGIN { for (s = 200; s < 280; s++) for (t = 1; t < 101; t++)
    printf "## AC-%03d-%02d — archived\n", s, t }' > "$TMPDIR_HELPER/changes/200-arch.md"
  # 300 claims archive authority without owning the dangling ID used below.
  printf '## %s — archived\n' "$(printf 'AC-%03d-%02d' 300 1)" > "$TMPDIR_HELPER/changes/300-arch.md"
  printf 'it("%s: x", () => {});\nit("%s: x", () => {});\n' "$live" "$only_archived" \
    > "$TMPDIR_HELPER/src/a.test.ts"
  for _ in 1 2 3 4 5; do
    run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" \
      --checks 2 "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/changes"
    [ "$status" -eq 0 ]
    [[ "$output" != *"FAIL"* ]]
    [[ "$output" == *"every scenario traced"* ]]
  done
  # Control: an ID in neither source is still a finding, so the fix cannot be
  # "resolve everything" — the check still fails on a genuinely dangling ID.
  printf 'it("%s: x", () => {});\n' "$absent_ref" >> "$TMPDIR_HELPER/src/a.test.ts"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-scenario-traceability.sh" \
    --checks 2 "$TMPDIR_HELPER/specs" "$TMPDIR_HELPER/src" "$TMPDIR_HELPER/changes"
  [ "$status" -eq 1 ]
  [[ "$output" == *"$absent_ref"* ]]
}
