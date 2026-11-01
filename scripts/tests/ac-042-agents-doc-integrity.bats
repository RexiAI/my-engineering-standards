#!/usr/bin/env bats
# Spec 042 — AGENTS.md document integrity: the repaired tag-bullet reference
# (AC-042-07) and the advisory/enforced split (AC-042-09).

load test_helper

AGENTS_MD="${REPO_ROOT}/AGENTS.md"
ADVISORY_SUFFIX='— *advisory* (see §Enforcement status)'

# bullets_of <block> — the markdown list items in a block.
bullets_of() {
  printf '%s\n' "$1" | grep '^- ' || true
}

@test "AC-042-07-01: the tag bullet cites the real document" {
  local bullet
  bullet="$(grep -F 'Never create git version tags' "$AGENTS_MD")"
  [ -n "$bullet" ]
  [[ "$bullet" == *'docs/CI_CD.md §Release Process'* ]]
  [[ "$bullet" != *'docs/CI_CD.md.md'* ]]
}

@test "AC-042-07-02: no doubled-extension reference remains" {
  local files hits
  files="$(cd "$REPO_ROOT" && git ls-files -- AGENTS.md README.md docs language-specific templates skills commands \
    | grep -E '\.md$')"
  [ -n "$files" ]
  hits="$(cd "$REPO_ROOT" && printf '%s\n' "$files" | while IFS= read -r f; do
    grep -lF -- 'docs/CI_CD.md.md' "$f" || true
  done)"
  [ -z "$hits" ]
}

@test "AC-042-09-01: the four affected bullets carry the advisory suffix" {
  local rules bullets marked
  rules="$(md_section "$AGENTS_MD" '## General Rules' 2 3)"
  bullets="$(bullets_of "$rules")"
  marked="$(printf '%s\n' "$bullets" | grep -cF -- "$ADVISORY_SUFFIX")"
  [ "$marked" -eq 4 ]
  [[ "$bullets" == *"controller → service → repository. $ADVISORY_SUFFIX"* ]]
  [[ "$bullets" == *"Business logic belongs in services, never in controllers or repositories. $ADVISORY_SUFFIX"* ]]
  [[ "$bullets" == *"check all external dependencies. $ADVISORY_SUFFIX"* ]]
  [[ "$bullets" == *"Use structured logging with trace IDs. $ADVISORY_SUFFIX"* ]]
}

@test "AC-042-09-02: an Enforcement status subsection names the advisory set" {
  local block
  run grep -cxF -- '### Enforcement status' "$AGENTS_MD"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  block="$(md_section "$AGENTS_MD" '### Enforcement status' 2 3)"
  [ -n "$block" ]
  [[ "$block" == *'reviewed in the PR'* ]]
  [[ "$block" == *'not enforced by a gate'* ]]
}

@test "AC-042-09-03: the advisory table has exactly three rows" {
  local block rows row
  block="$(md_section "$AGENTS_MD" '### Enforcement status' 2 3)"
  rows="$(printf '%s\n' "$block" | grep '^|' | grep -vE '^\|[-: |]+\|$' | tail -n +2)"
  [ "$(printf '%s\n' "$rows" | grep -c '^|')" -eq 3 ]
  [[ "$rows" == *'Layered architecture'* ]]
  [[ "$rows" == *'/health'* ]]
  [[ "$rows" == *'Structured logging'* ]]
  while IFS= read -r row; do
    [[ "$row" == *'| advisory |'* ]]
  done <<< "$rows"
}

@test "AC-042-09-04: the subsection states no check exists and that adding one is a new spec" {
  local block
  block="$(md_section "$AGENTS_MD" '### Enforcement status' 2 3)"
  [[ "$block" == *'no script check'* ]]
  [[ "$block" == *'new spec'* ]]
  [[ "$block" == *'`scripts/check-*.sh` gate are mechanically enforced'* ]]
  [[ "$block" == *'self-ci'* ]]
}

@test "AC-042-09-05: no false enforcement claim remains" {
  local bullets rule_line
  bullets="$(bullets_of "$(md_section "$AGENTS_MD" '## General Rules' 2 3)")"
  for rule_line in \
    "$(printf '%s\n' "$bullets" | grep -F 'Prefer layered architecture')" \
    "$(printf '%s\n' "$bullets" | grep -F 'Business logic belongs in services')" \
    "$(printf '%s\n' "$bullets" | grep -F 'check all external dependencies')" \
    "$(printf '%s\n' "$bullets" | grep -F 'Use structured logging with trace IDs')"; do
    [ -n "$rule_line" ]
    [[ "$rule_line" != *'scripts/check-'* ]]
    [[ "$rule_line" != *'self-ci'* ]]
    [[ "$rule_line" == *"$ADVISORY_SUFFIX" ]]
  done
  # The three bullets that legitimately claim mechanical enforcement are
  # unchanged and carry no advisory marker.
  local claim
  for claim in scripts/check-code-principles.sh scripts/check-orchestration.sh scripts/check-skills.sh; do
    rule_line="$(printf '%s\n' "$bullets" | grep -F -- "$claim")"
    [ -n "$rule_line" ]
    [[ "$rule_line" == *'mechanically'* ]]
    [[ "$rule_line" != *"$ADVISORY_SUFFIX" ]]
  done
}
