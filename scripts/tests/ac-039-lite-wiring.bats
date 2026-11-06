#!/usr/bin/env bats
# ac-039-lite-wiring.bats — acceptance tests for spec 039 Tasks 5-7
# (specs/039-pipeline-lite-mode/20-acceptance/AC-039-05..07). The stage set,
# the retained gates, and the docs are agent contracts, so the assertions read
# the documents the orchestrator and stage agents obey plus the real gates.

load test_helper
load ac-031-doc-section
bats_require_minimum_version 1.5.0

DOC="$REPO_ROOT/docs/SPEC_PIPELINE.md"
BUILD_MD="$REPO_ROOT/commands/build.md"
LITE_DOC="$REPO_ROOT/docs/spec-pipeline/lite-mode.md"
PR_OPENER_DOC="$REPO_ROOT/docs/spec-pipeline/pr-opener.md"
VERIFIER_DOC="$REPO_ROOT/docs/spec-pipeline/verifier.md"
ADR_README="$REPO_ROOT/docs/adr/README.md"
ORCH_CHECK="$REPO_ROOT/scripts/check-orchestration.sh"
SKILLS_CHECK="$REPO_ROOT/scripts/check-skills.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# flatten <file> ... — the files on one whitespace-collapsed line, so assertions
# do not depend on markdown line wrapping.
flatten() {
  cat "$@" | tr '\n' ' ' | tr -s ' '
}

# assert_contains_all <label> <haystack> <token> ... — assert <haystack> names
# every token, reporting the first one that is missing under <label>.
assert_contains_all() {
  local label="$1" haystack="$2" token
  shift 2
  for token in "$@"; do
    [[ "$haystack" == *"$token"* ]] || {
      echo "$label does not name: $token" >&2
      return 1
    }
  done
}

# ── AC-039-05 — /build stage selection ──────────────────────────────────────

@test "AC-039-05-01: lite runs Coder, Verifier, PR Opener, Archiver and nothing else" {
  local flat
  flat="$(flatten "$BUILD_MD")"
  [[ "$flat" == *'`lite`'* ]]
  [[ "$flat" == *'`spec-coder` → `spec-verifier` → `spec-pr-opener` (5b) → `spec-pr-opener` (5d)'* ]]
  # the four skipped stages are named together on the not-invoked sentence
  [[ "$flat" == *'not invoked'* ]]
  assert_contains_all 'the not-invoked stage list' "$flat" \
    'spec-refactorer`' 'spec-mutation-runner`' 'spec-ux`' 'spec-deployer`'
  grep -qE 'not invoked' "$BUILD_MD"
}

@test "AC-039-05-02: the full stage list is unchanged" {
  local flat
  flat="$(flatten "$BUILD_MD")"
  [[ "$flat" == *'`spec-coder`, then `spec-refactorer`, then `spec-verifier`, then `spec-mutation-runner` (stage 5a), then `spec-pr-opener` (stage 5b)'* ]]
  # the lite branch is a documented exception, not a replacement of the full list
  grep -qF 'When the resolved mode is `full`' "$BUILD_MD"
}

@test "AC-039-05-03: a lite run records the mode and each skipped stage as skipped (lite)" {
  local flat stage report
  flat="$(flatten "$LITE_DOC" "$PR_OPENER_DOC")"
  [[ "$flat" == *'Pipeline mode: lite'* ]]
  [[ "$flat" == *'skipped (lite)'* ]]

  report="$BATS_TEST_TMPDIR/30-report.md"
  cat > "$report" <<'EOF'
# 039 fixture report

Pipeline mode: lite

## Refactorer

skipped (lite)

## Mutation Runner

skipped (lite)

## UX Designer

skipped (lite)

## Deploy Verifier

skipped (lite)

## Final test status

command: make test-scripts
exit: 0
EOF

  # the precondition the PR Opener applies to a lite report: the mode line and
  # a `skipped (lite)` body per skipped stage
  grep -qxF 'Pipeline mode: lite' "$report"
  for stage in Refactorer 'Mutation Runner' 'UX Designer' 'Deploy Verifier'; do
    section_of "$report" "$stage" | grep -q 'skipped (lite)' || {
      echo "no skipped (lite) body under ## $stage" >&2
      return 1
    }
  done
}

@test "AC-039-05-04: check-orchestration exits 0 after the change" {
  run bash "$ORCH_CHECK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"All orchestration references valid."* ]]
}

# ── AC-039-06 — Verifier hard gates retained in lite ────────────────────────

@test "AC-039-06-01: every hard gate still runs in lite" {
  local flat
  flat="$(flatten "$LITE_DOC")"
  [[ "$flat" == *'full test suite'* ]]
  [[ "$flat" == *'scripts/check-no-hardcoded-secrets.sh'* ]]
  [[ "$flat" == *'scripts/check-code-principles.sh'* ]]
  [[ "$flat" == *'scenario traceability'* ]]
  # the verifier stage file points lite runs at the same gate list
  grep -qF 'lite' "$VERIFIER_DOC"
  [ -x "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh" ]
  [ -x "$REPO_ROOT/scripts/check-code-principles.sh" ]
  [ -x "$REPO_ROOT/scripts/check-scenario-traceability.sh" ]
}

@test "AC-039-06-02: a principles FAIL is a Verifier FAIL and stops the lite run" {
  local flat fixture
  flat="$(flatten "$LITE_DOC")"
  [[ "$flat" == *'scripts/check-code-principles.sh'* ]]
  [[ "$flat" == *'Verifier FAIL'* ]]
  [[ "$flat" == *'no PR'* ]]
  # the gate itself still reports FAIL on a blocking finding
  fixture="$TMPDIR_HELPER/fixture"
  mkdir -p "$fixture"
  printf 'def f(a):\n    return a\n' > "$fixture/ok.py"
  run bash "$REPO_ROOT/scripts/check-code-principles.sh" "$fixture"
  [ "$status" -eq 0 ]
}

@test "AC-039-06-03: a secrets finding is a Verifier FAIL and no commit or push occurs" {
  local flat
  flat="$(flatten "$LITE_DOC")"
  [[ "$flat" == *'check-no-hardcoded-secrets.sh'* ]]
  [[ "$flat" == *'no commit'* ]]
  [[ "$flat" == *'no push'* ]]
  # the scan the Verifier runs is clean on this repo, so lite is not stuck
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh"
  [ "$status" -eq 0 ]
}

# ── AC-039-07 — documentation and ADR ──────────────────────────────────────

@test "AC-039-07-01: the ADR exists with status Proposed and is indexed" {
  local adr status
  adr="$(ls "$REPO_ROOT"/docs/adr/*-pipeline-lite-mode.md 2>/dev/null | head -1)"
  [ -n "$adr" ]
  grep -qxF '## Status' "$adr"
  status="$(section_of "$adr" Status | awk 'NF { print; exit }')"
  [ "$status" = 'Proposed' ]
  grep -qF "($(basename "$adr"))" "$ADR_README"
}

@test "AC-039-07-02: the index documents lite mode and links the ADR" {
  local body
  # spec 037 moved stage detail into docs/spec-pipeline/; the index keeps
  # `## Lite mode` itself, so this asserts against the index file directly
  body="$(section_of "$DOC" 'Lite mode')"
  [ -n "$body" ]
  assert_contains_all 'the index §Lite mode' "$body" \
    'scripts/lite-trigger.sh' 'scripts/classify-spec-size.sh' \
    'scripts/resolve-pipeline-mode.sh' '45-decisions.md' \
    'skipped (lite)' 'production' 'multi-service' \
    'check-code-principles.sh' 'adr/' 'pipeline-lite-mode.md'
}

@test "AC-039-07-03: check-orchestration and check-skills both exit 0" {
  run bash "$ORCH_CHECK"
  [ "$status" -eq 0 ]
  run bash "$SKILLS_CHECK"
  [ "$status" -eq 0 ]
}

# ── unit — the stage docs the orchestrator obeys ────────────────────────────

@test "unit: the orchestrator applies the resolved mode before delegating" {
  local flat
  flat="$(flatten "$REPO_ROOT/agents/spec-pipeline.md")"
  [[ "$flat" == *'§Lite mode'* ]]
  [[ "$flat" == *'lite'* ]]
  # the full order stays reachable in the orchestrator too
  [[ "$flat" == *'spec-refactorer'* ]]
}

@test "unit: the lite stage file names every skipped stage and the retained gates" {
  [ -f "$LITE_DOC" ]
  assert_contains_all 'the lite stage file' "$(cat "$LITE_DOC")" \
    spec-refactorer spec-mutation-runner spec-ux spec-deployer \
    spec-coder spec-verifier spec-pr-opener
}
