#!/usr/bin/env bats
# test-helper.bats — unit coverage for the shared helpers in test_helper.bash.
#
# md_section bounds every docs content assertion to one section. These cases pin
# that boundary: the helper exists so text in a *different* section can never
# satisfy an assertion, which makes "where does it stop" the contract under
# test, not an implementation detail.

load test_helper

setup() {
  setup_tmpdir
  DOC="$TMPDIR_HELPER/doc.md"
  cat > "$DOC" <<'MD'
# Title

## Wanted

body of the wanted section

### Nested under wanted

nested text

## Other

body of the other section
MD
}

teardown() { teardown_tmpdir; }

@test "test_helper md_section: a level-2 heading stops at the next level-2 heading" {
  run md_section "$DOC" '## Wanted'
  [ "$status" -eq 0 ]
  [[ "$output" == *'body of the wanted section'* ]]
  [[ "$output" == *'nested text'* ]]
  [[ "$output" != *'body of the other section'* ]]
  # The heading line itself is not part of the body.
  [[ "$output" != *'## Wanted'* ]]
}

@test "test_helper md_section: an explicit max-level also stops at a deeper heading" {
  run md_section "$DOC" '## Wanted' 2 3
  [ "$status" -eq 0 ]
  [[ "$output" == *'body of the wanted section'* ]]
  [[ "$output" != *'nested text'* ]]
  [[ "$output" != *'body of the other section'* ]]
}

@test "test_helper md_section: a level-3 heading stops at its parent level-2 heading" {
  run md_section "$DOC" '### Nested under wanted' 2 3
  [ "$status" -eq 0 ]
  [[ "$output" == *'nested text'* ]]
  [[ "$output" != *'body of the other section'* ]]
}

@test "test_helper md_section: an absent heading exits 1 with no output" {
  run md_section "$DOC" '## Not There'
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
