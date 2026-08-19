#!/bin/bash
# check-ci-sweeper.sh — Verify the CI Sweeper loop deliverables are present and
# carry the required content.
#
# The CI Sweeper loop (spec 017) is a prompts/docs + workflow spec: one skill
# (skills/ci-triage/SKILL.md), one event-driven workflow
# (.github/workflows/ci-sweeper.yml) reacting to a failing Self CI run, and this
# gate script. This script is the test carrier for the spec's acceptance
# scenarios: it cites every AC-017-NN-NN scenario ID and greps the required
# strings in the artifacts, so scripts/check-scenario-traceability.sh resolves
# them, and it exits 0 only when every content assertion holds.
#
# Checks:
#   1. skills/ci-triage/SKILL.md exists with repo-convention frontmatter and
#      carries the triage/classification content               (AC-017-01)
#   2. the skill carries the isolated fix flow, maker/checker split, max-3
#      bound, and escalation rules                              (AC-017-02)
#   3. .github/workflows/ci-sweeper.yml exists with the workflow_run trigger,
#      early exit on green, least-privilege permissions, and the headless
#      opencode sweep                                          (AC-017-03)
#   4. the skill carries the STATE.md CI Sweeper section contract and the cost
#      guidance                                                (AC-017-04)
#   5. this script exists/executable, cites every scenario ID, fails closed in
#      --self-test mode, and is wired into
#      .github/workflows/self-ci.yml                            (AC-017-05)
#
# Usage:
#   scripts/check-ci-sweeper.sh [ROOT_DIR]
#   scripts/check-ci-sweeper.sh --self-test
#   ROOT_DIR defaults to the current directory.
#
# Exit codes:
#   0 — every check passes
#   1 — one or more required artifacts/strings/references are missing
#
# Standards reference:
#   docs/LOOP_ENGINEERING.md (spec 016 — consumed by reference)
#   specs/017-ci-sweeper-loop/20-acceptance/ (AC-017-01 … AC-017-05)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# verify_grep <AC-ID> <file> <label> <pattern>...
#   Every <pattern> must appear (fixed-string match) in <file>. Emits one PASS
#   line carrying the scenario ID when all patterns are present, or one FAIL
#   line naming the missing patterns otherwise.
verify_grep() {
  local acid="$1" file="$2" label="$3"
  shift 3
  local missing=() pat
  for pat in "$@"; do
    grep -qF -- "$pat" "$file" || missing+=("$pat")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    pass "$acid: $label"
  else
    fail "$acid: $label — missing: ${missing[*]}"
  fi
}

# self_test — AC-017-05-03: prove the gate fails closed. Builds a temp fixture
# whose artifacts exist but are missing required strings (the skill lacks
# 'never auto-fix', the workflow lacks 'workflow_run'), runs this script
# against it, and requires a non-zero exit.
self_test() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/skills/ci-triage" "$tmp/.github/workflows"
  cat > "$tmp/skills/ci-triage/SKILL.md" <<'EOF'
---
name: ci-triage
description: fixture
---
# Fixture
EOF
  cat > "$tmp/.github/workflows/ci-sweeper.yml" <<'EOF'
name: CI Sweeper

permissions:
  contents: read
EOF
  cat > "$tmp/.github/workflows/self-ci.yml" <<'EOF'
name: Self CI
EOF
  if "$0" "$tmp" >/dev/null 2>&1; then
    fail "AC-017-05-03: --self-test — broken fixture passed, the gate does not fail closed"
    exit 1
  fi
  pass "AC-017-05-03: --self-test — gate fails closed on a broken fixture"
  exit 0
}

if [ "${1:-}" = "--self-test" ]; then
  self_test
fi

ROOT_DIR="${1:-.}"

SKILL="$ROOT_DIR/skills/ci-triage/SKILL.md"
WF="$ROOT_DIR/.github/workflows/ci-sweeper.yml"
SELF_CI="$ROOT_DIR/.github/workflows/self-ci.yml"

echo "Checking CI Sweeper loop deliverables in: $ROOT_DIR"
echo ""

# ── AC-017-01: the ci-triage skill exists and classifies ─────────────────────
if [ -f "$SKILL" ]; then
  verify_grep "AC-017-01-01" "$SKILL" "skill exists with repo-convention frontmatter" \
    "name: ci-triage" "description:" "license:" "allowed-tools:"
  verify_grep "AC-017-01-02" "$SKILL" "failing-log read grounded in this repo's CI" \
    'gh run view <RUN-ID> --log-failed' 'gh run list --workflow "Self CI"' \
    "Self CI" "Validate"
  verify_grep "AC-017-01-03" "$SKILL" "classification output: exactly one class + job/step + evidence" \
    "flake" "regression" "infra" "config" "job/step" "evidence"
  verify_grep "AC-017-01-04" "$SKILL" "decision guide distinguishes the four classes with flake criteria" \
    "flake" "regression" "infra" "config" \
    "seen before" "intermittent" "passed on retry with no code change"
  verify_grep "AC-017-01-05" "$SKILL" "flake rule: Watch, never auto-fix" \
    "**Watch**" "never auto-fix"
  verify_grep "AC-017-01-06" "$SKILL" "infra/config are not code defects, routed to escalation" \
    "runner OOM" "registry down" "secrets missing" "not code defects" "escalation"
else
  fail "AC-017-01-01: skills/ci-triage/SKILL.md is missing"
fi

echo ""

# ── AC-017-02: isolated fix flow and bounded remediation ─────────────────────
if [ -f "$SKILL" ]; then
  verify_grep "AC-017-02-01" "$SKILL" "minimal fix in an isolated worktree, never on swept branch/main" \
    "smallest change" "git worktree add" "never on the swept branch" 'never on `main`'
  verify_grep "AC-017-02-02" "$SKILL" "maker/checker split verified before any PR or comment" \
    "maker" "checker" "separate checking pass" "before any PR or comment" \
    "addresses the failure" "no unrelated changes" "make validate-all" "make lint"
  verify_grep "AC-017-02-03" "$SKILL" "max 3 attempts, recorded in loop-run-log.md, own circuit breaker" \
    "3 attempts" "loop-run-log.md" "circuit breaker" \
    "independent of spec 008's pipeline budget and 014's round counter"
  verify_grep "AC-017-02-04" "$SKILL" "exhaustion escalates with pruned context, never loops forever" \
    "escalates to a human" "failing job" "run link" "last log excerpt" "never loops forever"
  verify_grep "AC-017-02-05" "$SKILL" "escalation conditions enumerated" \
    "runner OOM" "more than 5 files" "core architecture" "security-sensitive" \
    "max attempts exceeded" "quarantine"
  verify_grep "AC-017-02-06" "$SKILL" "defers to an in-flight remediation of the same failure" \
    "STATE.md" "in-flight" "spec/NNN-slug"
else
  echo "  (skipped — AC-017-02 content lives in the missing skill)"
fi

echo ""

# ── AC-017-03: the workflow trigger, early exit, and permissions ──────────────
if [ -f "$WF" ]; then
  verify_grep "AC-017-03-01" "$WF" "workflow_run trigger on Self CI completed" \
    "workflow_run" "completed" "Self CI"
  verify_grep "AC-017-03-02" "$WF" "runs only on failure; green run is a no-op" \
    "conclusion == 'failure'" "no-op"
  verify_grep "AC-017-03-03" "$WF" "failing-run context captured and passed into the sweep" \
    "workflow_run.id" "head_sha" "head_branch" \
    "SWEEPER_RUN_ID" "SWEEPER_HEAD_SHA" "SWEEPER_HEAD_BRANCH"
  verify_grep "AC-017-03-04" "$WF" "headless opencode run loads the ci-triage skill" \
    "opencode run" "ci-triage"
  verify_grep "AC-017-03-05" "$WF" "least-privilege permissions declared" \
    "contents: read" "actions: read" "issues: write"
  BROADER=()
  for bad in "contents: write" "pull-requests: write" "packages: write" \
             "id-token: write" "gh pr merge" "--merge" "auto-merge"; do
    grep -qF -- "$bad" "$WF" && BROADER+=("$bad")
  done
  if [ "${#BROADER[@]}" -eq 0 ]; then
    pass "AC-017-03-05: no merge, push-to-main, or tag-creation capability; no auto-merge step"
  else
    fail "AC-017-03-05: workflow grants broader capability — contains: ${BROADER[*]}"
  fi
  verify_grep "AC-017-03-06" "$WF" "activation constraint and L1 readiness documented" \
    'after merging to `main`' "report-only" "L1" "must not auto-fix unattended"
else
  fail "AC-017-03-01: .github/workflows/ci-sweeper.yml is missing"
fi

echo ""

# ── AC-017-04: STATE.md CI Sweeper section contract and cost guidance ─────────
if [ -f "$SKILL" ]; then
  verify_grep "AC-017-04-01" "$SKILL" "STATE.md CI Sweeper section fields defined" \
    "CI Sweeper" "last run" "failing commit SHA" "failing job" \
    "attempt count" "worktree/PR link" "outcome"
  verify_grep "AC-017-04-02" "$SKILL" "prune rule: updated each run, resolved removed, in-flight retained" \
    "updated on each run" "resolved failures are removed" "in-flight failures are retained"
  verify_grep "AC-017-04-03" "$SKILL" "state files are spec 016's, operative after 016, L1 until then" \
    "STATE.md" "loop-run-log.md" "spec 016's" "consumed by reference" \
    "operative only after 016" "never runs unattended"
  verify_grep "AC-017-04-04" "$SKILL" "cost guidance: early exit, no-op run, token estimate" \
    "exits early when CI is green" "no-op run" "no code change" "tokens_estimate"
else
  echo "  (skipped — AC-017-04 content lives in the missing skill)"
fi

echo ""

# ── AC-017-05: this script, its scenario citations, and the self-ci wiring ───
if [ -x "$ROOT_DIR/scripts/check-ci-sweeper.sh" ]; then
  pass "AC-017-05-01: scripts/check-ci-sweeper.sh exists and is executable"
else
  fail "AC-017-05-01: scripts/check-ci-sweeper.sh is missing or not executable"
fi

SCENARIO_IDS=(AC-017-01-01 AC-017-01-02 AC-017-01-03 AC-017-01-04 AC-017-01-05 AC-017-01-06 \
  AC-017-02-01 AC-017-02-02 AC-017-02-03 AC-017-02-04 AC-017-02-05 AC-017-02-06 \
  AC-017-03-01 AC-017-03-02 AC-017-03-03 AC-017-03-04 AC-017-03-05 AC-017-03-06 \
  AC-017-04-01 AC-017-04-02 AC-017-04-03 AC-017-04-04 \
  AC-017-05-01 AC-017-05-02 AC-017-05-03 AC-017-05-04)
MISSING_IDS=()
for id in "${SCENARIO_IDS[@]}"; do
  grep -q -- "$id" "$0" || MISSING_IDS+=("$id")
done
if [ "${#MISSING_IDS[@]}" -eq 0 ]; then
  pass "AC-017-05-02: script cites every scenario ID (AC-017-01-01 … AC-017-05-04)"
else
  fail "AC-017-05-02: script does not cite: ${MISSING_IDS[*]}"
fi

if [ -f "$SELF_CI" ] && grep -q 'check-ci-sweeper.sh' "$SELF_CI"; then
  pass "AC-017-05-04: .github/workflows/self-ci.yml runs check-ci-sweeper.sh"
else
  fail "AC-017-05-04: .github/workflows/self-ci.yml does not run check-ci-sweeper.sh"
fi

echo ""

# ── Summary ─────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ CI sweeper check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: specs/017-ci-sweeper-loop/20-acceptance/"
  exit 1
else
  echo -e "${GREEN}✔ CI sweeper check: every check passed.${NC}"
  exit 0
fi
