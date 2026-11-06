#!/usr/bin/env bats
# Spec 042 — docs/CI_CD.md: the bootstrap example opens a pull request instead
# of pushing the default branch (AC-042-08).

load test_helper

CICD_MD="${REPO_ROOT}/docs/CI_CD.md"

# fenced_lines — keep only the lines inside ``` fences, dropping the fence
# markers themselves.
fenced_lines() {
  awk '/^```/ { fence = !fence; next } fence { print }'
}

# new_project_block — the fenced shell content under '### New Project' only.
new_project_block() {
  md_section "$CICD_MD" '### New Project' 3 3 | fenced_lines
}

@test "AC-042-08-01: the example branches before committing" {
  local block branch
  block="$(new_project_block)"
  [ -n "$block" ]
  [[ "$block" == *'git checkout -b'* ]]
  branch="$(printf '%s\n' "$block" | sed -nE 's/.*git checkout -b[[:space:]]+([^[:space:]]+).*/\1/p' | head -1)"
  [ -n "$branch" ]
  [ "$branch" != "main" ]
  [ "$branch" != "master" ]
}

@test "AC-042-08-02: the example pushes the feature branch with an upstream" {
  local block branch
  block="$(new_project_block)"
  branch="$(printf '%s\n' "$block" | sed -nE 's/.*git checkout -b[[:space:]]+([^[:space:]]+).*/\1/p' | head -1)"
  [ -n "$branch" ]
  [[ "$block" == *'git push -u origin'* ]]
  [[ "$block" == *"git push -u origin ${branch}"* ]]
}

@test "AC-042-08-03: the example opens a pull request" {
  local block
  block="$(new_project_block)"
  [ -n "$block" ]
  [[ "$block" == *'gh pr create'* ]]
}

@test "AC-042-08-04: no bare push or push to the default branch remains" {
  local block ci_only_line ci_only_body ci_only_fenced
  ! grep -qxF -- 'git push' "$CICD_MD"
  # No command in the file pushes main or master as a ref.
  local pushes
  pushes="$(grep -nE 'git[[:space:]]+push' "$CICD_MD" | grep -E '(^|[[:space:]])(main|master)([[:space:]]|$)' || true)"
  [ -z "$pushes" ]

  # The CI-only section is unchanged: still present, still heading its own
  # fenced init-ci example.
  block="$(new_project_block)"
  [ -n "$block" ]
  ci_only_line="$(grep -n '^### CI Only (already bootstrapped)$' "$CICD_MD" | cut -d: -f1)"
  [ -n "$ci_only_line" ]
  ci_only_body="$(md_section "$CICD_MD" '### CI Only (already bootstrapped)' 3 3)"
  [ -n "$ci_only_body" ]
  ci_only_fenced="$(printf '%s\n' "$ci_only_body" | fenced_lines)"
  [[ "$ci_only_fenced" == *'init-ci.sh'* ]]
}
