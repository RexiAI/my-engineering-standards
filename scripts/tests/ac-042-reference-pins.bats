#!/usr/bin/env bats
# Spec 042 — docs/OFFICIAL_REFERENCES.md: Java, Go, and React Native pins.
# One test per acceptance scenario in
# specs/042-docs-security-hardening/20-acceptance/AC-042-06-*.md.

load test_helper

REFS_MD="${REPO_ROOT}/docs/OFFICIAL_REFERENCES.md"

# table_rows <file> <heading> — the '|'-prefixed rows of the section under
# <heading> (prose between the heading and the first row is skipped).
table_rows() {
  md_section "$1" "$2" | grep '^|'
}

@test "AC-042-06-01: Java is pinned at 21 with an Oracle authority link" {
  local row
  row="$(table_rows "$REFS_MD" '## Version pins' | grep -F '| Java |')"
  [ -n "$row" ]
  [[ "$row" == '| Java |'* ]]
  [[ "$row" == *21* ]]
  [[ "$row" == *docs.oracle.com* ]]
}

@test "AC-042-06-02: Go's pin is the module manifest, not a hardcoded version" {
  local row
  row="$(table_rows "$REFS_MD" '## Version pins' | grep -F '| Go |')"
  [ -n "$row" ]
  [[ "$row" == '| Go |'* ]]
  [[ "$row" == *go.mod* ]]
  [[ "$row" == *'`go`'*'`toolchain`'* ]]
  [[ "$row" == *go.dev* ]]
}

@test "AC-042-06-03: React Native is pinned at 0.88.1 with its runtime floors" {
  local row
  row="$(table_rows "$REFS_MD" '## Version pins' | grep -F '| React Native |')"
  [ -n "$row" ]
  [[ "$row" == '| React Native |'* ]]
  [[ "$row" == *0.88.1* ]]
  [[ "$row" == *'^22.13.0'* ]]
  [[ "$row" == *'^24.3.0'* ]]
  [[ "$row" == *'>= 26.0.0'* ]]
  [[ "$row" == *'^19.3.0'* ]]
  [[ "$row" == *registry.npmjs.org/react-native/0.88.1* ]]
}

@test "AC-042-06-04: existing rows are preserved and the new rows are dated" {
  local table stack
  table="$(table_rows "$REFS_MD" '## Version pins')"
  for stack in '| Angular |' '| Ionic Framework |' '| Capacitor |' '| NestJS |' '| FastAPI |' '| Rust |' '| Vercel CLI |'; do
    [[ "$table" == *"$stack"* ]]
  done

  local dated
  dated="$(grep -F '2026-11-01' "$REFS_MD" | grep -F '2026-10-15' | grep -F 'spec 042')"
  [ -n "$dated" ]

  local licences row
  licences="$(table_rows "$REFS_MD" '## Licences')"
  for stack in '| Java |' '| Go |' '| React Native |'; do
    row="$(printf '%s\n' "$licences" | grep -F -- "$stack")"
    [ -n "$row" ]
    [[ "$row" == *'| — |'* ]]
    [[ "$row" == *'Not reproduced — links only'* ]]
  done
}
