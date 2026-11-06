#!/usr/bin/env bats
# ac-041-doc-section-refs.bats — acceptance tests for spec 041 Task 1
# (specs/041-pipeline-token-savings/20-acceptance/AC-041-coding-conventions-sections.md).
#
# Every negative case runs against a scratch ROOT under $TMPDIR_HELPER — the
# checker takes an optional ROOT argument for exactly that reason, so the real
# agents/ tree is never rewritten by a test.

load test_helper
bats_require_minimum_version 1.5.0

CHECK="$REPO_ROOT/scripts/check-doc-section-refs.sh"
DOC_REL="docs/CODING_CONVENTIONS.md"

setup() {
  setup_tmpdir
  mkdir -p "$TMPDIR_HELPER/root/agents" "$TMPDIR_HELPER/root/commands" \
           "$TMPDIR_HELPER/root/docs"
}
teardown() { teardown_tmpdir; }

# fixture_doc <root> [extra-heading...] — a minimal conventions doc with the
# headings the fixture agents below reference.
fixture_doc() {
  local root="$1"
  shift
  {
    printf '# Coding conventions\n'
    printf '## Naming\n\nname things\n'
    printf '## Design Principles\n\nkeep it simple\n'
    printf '## Logging\n\nlog at boundaries\n'
    local h
    for h in "$@"; do printf '## %s\n\nfixture section\n' "$h"; done
  } > "$root/$DOC_REL"
}

# fixture_agent <root> <name> <reference-line> — an agents/spec-*.md carrying
# one reference line at line 7.
fixture_agent() {
  local root="$1" name="$2" ref="$3"
  {
    printf '# %s\n\n' "$name"
    printf 'line two\nline three\nline four\nline five\n'
    printf '%s\n' "$ref"
  } > "$root/agents/$name"
}

@test "AC-041-01 — coder points at the seven named sections, not §Formatting" {
  local line anchors
  line="$(grep -m1 'docs/CODING_CONVENTIONS\.md' "$REPO_ROOT/agents/spec-coder.md")"
  for anchors in '§Naming' '§File Organization' '§Design Principles' \
                 '§Error Handling Philosophy' '§Logging' '§Exception Handling' \
                 '§Imports Ordering'; do
    [[ "$line" == *"$anchors"* ]]
  done
  [[ "$line" != *'§Formatting'* ]]
}

@test "AC-041-02 — refactorer points at §Design Principles only" {
  local line
  line="$(grep -m1 'docs/CODING_CONVENTIONS\.md' "$REPO_ROOT/agents/spec-refactorer.md")"
  [[ "$line" == *'docs/CODING_CONVENTIONS.md §Design Principles'* ]]
  [ "$(grep -o '§' <<< "$line" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "AC-041-03 — checker passes on the repo tree with one [OK] per scanned file" {
  local expected ok_lines
  expected=$(( $(ls "$REPO_ROOT"/agents/spec-*.md | wc -l) + $(ls "$REPO_ROOT"/commands/*.md | wc -l) ))
  run bash "$CHECK" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  ok_lines="$(grep -c '^\[OK\] ' <<< "$output")"
  [ "$ok_lines" -eq "$expected" ]
}

@test "AC-041-04 — a bare whole-file reference is a violation" {
  fixture_doc "$TMPDIR_HELPER/root"
  fixture_agent "$TMPDIR_HELPER/root" spec-x.md 'Follow docs/CODING_CONVENTIONS.md for the house style.'
  run bash "$CHECK" "$TMPDIR_HELPER/root"
  [ "$status" -eq 1 ]
  [[ "$output" == *"agents/spec-x.md:7"* ]]
  [[ "$output" == *"bare-reference"* ]]
}

@test "AC-041-05 — an anchor matching no heading is a violation" {
  fixture_doc "$TMPDIR_HELPER/root"
  fixture_agent "$TMPDIR_HELPER/root" spec-x.md 'Read docs/CODING_CONVENTIONS.md §Design Principals.'
  run bash "$CHECK" "$TMPDIR_HELPER/root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'§Design Principals'* ]]
  [[ "$output" == *"section-missing"* ]]
}

@test "AC-041-06 — an anchor matching two headings is ambiguous and fails" {
  fixture_doc "$TMPDIR_HELPER/root" 'Logging'
  fixture_agent "$TMPDIR_HELPER/root" spec-x.md 'Read docs/CODING_CONVENTIONS.md §Logging.'
  run bash "$CHECK" "$TMPDIR_HELPER/root"
  [ "$status" -eq 1 ]
  [[ "$output" == *'§Logging'* ]]
  [[ "$output" == *"section-ambiguous"* ]]
}

@test "AC-041-07 — --cost reports referenced-section bytes only" {
  local root="$TMPDIR_HELPER/root" doc="$TMPDIR_HELPER/root/$DOC_REL"
  # 100-byte preamble, ## Alpha exactly 100 bytes, ## Beta exactly 200 bytes.
  { head -c 99 /dev/zero | tr '\0' 'a'; printf '\n'
    printf '## Alpha\n'; head -c 90 /dev/zero | tr '\0' 'b'; printf '\n'
    printf '## Beta\n'; head -c 191 /dev/zero | tr '\0' 'c'; printf '\n'
  } > "$doc"
  [ "$(wc -c < "$doc")" -eq 400 ]
  fixture_agent "$root" spec-x.md 'Read docs/CODING_CONVENTIONS.md §Alpha.'
  printf 'Read docs/CODING_CONVENTIONS.md §Alpha again.\n' >> "$root/agents/spec-x.md"
  run bash "$CHECK" --cost "$root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cost agents/spec-x.md sections=1 bytes=100 file_bytes=400 ratio=0.25"* ]]
}

@test "AC-041-08 — a missing conventions doc is a tooling failure, not a pass" {
  rm -rf "$TMPDIR_HELPER/root/docs"
  run --separate-stderr bash "$CHECK" "$TMPDIR_HELPER/root"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"CODING_CONVENTIONS.md"* ]]
}

@test "unit — --cost still exits 0 when a reference violates the check" {
  fixture_doc "$TMPDIR_HELPER/root"
  fixture_agent "$TMPDIR_HELPER/root" spec-x.md 'Follow docs/CODING_CONVENTIONS.md without anchors.'
  run bash "$CHECK" --cost "$TMPDIR_HELPER/root"
  [ "$status" -eq 0 ]
  [[ "$output" != *"bare-reference"* ]]
}

@test "unit — -h prints usage and exits 0" {
  run bash "$CHECK" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--cost"* ]]
}

@test "unit — a file with no reference is still reported [OK]" {
  fixture_doc "$TMPDIR_HELPER/root"
  printf '# nothing to see\n' > "$TMPDIR_HELPER/root/commands/build.md"
  run bash "$CHECK" "$TMPDIR_HELPER/root"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] commands/build.md"* ]]
}
