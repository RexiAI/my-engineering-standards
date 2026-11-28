#!/bin/bash
# check-pr-size-gate.sh — Verify the PR size gate and review-gated auto-merge
# deliverables are present and carry the required content (spec 045).
#
# There is no application code in this spec: the deliverable is four shell
# scripts, three reusable workflows, a self-hosted caller, the agent's verdict
# contract, the init-ci wiring, and the documentation. This script is the
# spec's test carrier for the artifact-shaped scenarios — every AC-045-NN
# group it enforces is cited below, and scripts/tests/pr-size-gate*.bats cover
# the behavioural ones.
#
# Checks:
#   AC-045-01  ADR 0030 exists with the template section set; index row present
#   AC-045-02  pr-size-gate.sh exists, executable, counts changed/excluded
#   AC-045-03  pr-size-gate.sh classifies tier/automerge/override
#   AC-045-04  agents/pr-review.md carries both Review-Verdict lines
#   AC-045-05  pr-review-verdict.sh exists, executable, prints verdict=
#   AC-045-06  pr-automerge-eligibility.sh exists, executable, prints eligible=
#   AC-045-07  ci-pr-size-gate.yml and ci-pr-review-verdict.yml are SHA-pinned,
#              read-only, pull_request_target-free reusables
#   AC-045-08  ci-pr-auto-merge.yml is a reusable with an automerge job, mode,
#              the squash-only auto-merge command, allow_auto_merge, no allowlist
#   AC-045-09  pr-automerge-notify.sh exists, executable, carries the marker
#   AC-045-10  init-ci.sh carries both flags; capabilities.tsv carries both rows
#   AC-045-11  self-ci runs this gate and the four bats files; report-only default
#   AC-045-12  AGENTS.md, GIT_WORKFLOW.md, CI_CD.md, branch-protection.md state
#              the rule, the tiers, the workflows/settings, and the prerequisites
#
# Usage:
#   scripts/check-pr-size-gate.sh [ROOT_DIR]
#   scripts/check-pr-size-gate.sh --self-test
#   ROOT_DIR defaults to the repository root containing this script.
#
# Exit codes:
#   0 — every check passes
#   1 — one or more artifacts/rules missing; a FAIL line is printed per violation
#   2 — tooling failure (no grep/find) or a bad --self-test fixture
#
# Standards reference:
#   specs/045-pr-size-gate-and-auto-merge/20-acceptance/
#   docs/CI_CD.md §PR Size Gate and Review-Gated Auto-Merge
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PIN="21046d96796467f8238d6d613ce3a552bf3fced0"
VIOLATIONS=0

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# verify_grep <AC-ID> <file> <label> <fixed-string>...
verify_grep() {
  local acid="$1" file="$2" label="$3"
  shift 3
  local missing=() pat
  if [ ! -f "$file" ]; then
    fail "$acid: $label — $file is missing"
    return 0
  fi
  for pat in "$@"; do
    grep -qF -- "$pat" "$file" || missing+=("$pat")
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    pass "$acid: $label"
  else
    fail "$acid: $label — missing: ${missing[*]}"
  fi
}

# verify_absent <AC-ID> <file> <label> <extended-regex>
verify_absent() {
  local acid="$1" file="$2" label="$3" re="$4"
  if [ ! -f "$file" ]; then
    fail "$acid: $label — $file is missing"
    return 0
  fi
  if grep -qE -- "$re" "$file"; then
    fail "$acid: $label — forbidden pattern '$re' present"
  else
    pass "$acid: $label"
  fi
}

# verify_artifact <AC-ID> <path> <label> — exists and is executable
verify_artifact() {
  local acid="$1" path="$2" label="$3" name
  name="$(basename "$path")"
  if [ ! -f "$path" ]; then
    fail "$acid: $label — required artifact $name is missing"
    return 0
  fi
  if [ ! -x "$path" ]; then
    fail "$acid: $label — required artifact $name is not executable"
    return 0
  fi
  pass "$acid: $label"
}

init_paths() { # init_paths <root>
  ROOT_DIR="$1"
  SIZE_GATE="$ROOT_DIR/scripts/pr-size-gate.sh"
  VERDICT="$ROOT_DIR/scripts/pr-review-verdict.sh"
  ELIGIBLE="$ROOT_DIR/scripts/pr-automerge-eligibility.sh"
  NOTIFY="$ROOT_DIR/scripts/pr-automerge-notify.sh"
  SIZE_WF="$ROOT_DIR/.github/workflows/ci-pr-size-gate.yml"
  VERDICT_WF="$ROOT_DIR/.github/workflows/ci-pr-review-verdict.yml"
  AUTOMERGE_WF="$ROOT_DIR/.github/workflows/ci-pr-auto-merge.yml"
  CALLER_WF="$ROOT_DIR/.github/workflows/pr-automerge.yml"
  AGENT="$ROOT_DIR/agents/pr-review.md"
  INIT_CI="$ROOT_DIR/scripts/init-ci.sh"
  CATALOG="$ROOT_DIR/scripts/capabilities.tsv"
  SELF_CI="$ROOT_DIR/.github/workflows/self-ci.yml"
  AGENTS_MD="$ROOT_DIR/AGENTS.md"
  GIT_WF="$ROOT_DIR/docs/GIT_WORKFLOW.md"
  CI_CD="$ROOT_DIR/docs/CI_CD.md"
  BRANCH_PROT="$ROOT_DIR/templates/branch-protection.md"
  ADR="$ROOT_DIR/docs/adr/0030-pr-size-gate-and-review-gated-auto-merge.md"
  ADR_INDEX="$ROOT_DIR/docs/adr/README.md"
}

check_adr() { # AC-045-01
  verify_grep AC-045-01 "$ADR" "ADR 0030 carries the template section set" \
    "## Title" "## Status" "## Context" "## Decision" "## Alternatives Considered" \
    "## Consequences" "## Compliance"
  verify_grep AC-045-01 "$ADR_INDEX" "ADR index carries the 0030 row" \
    "| 0030 |" "0030-pr-size-gate-and-review-gated-auto-merge.md"
}

check_size_gate_script() { # AC-045-02 / AC-045-03
  verify_artifact AC-045-02 "$SIZE_GATE" "pr-size-gate.sh exists and is executable"
  verify_grep AC-045-02 "$SIZE_GATE" "size gate reads numstat and diff, prints counts" \
    "--numstat-file" "--diff-file" "changed=" "excluded="
  verify_grep AC-045-03 "$SIZE_GATE" "size gate classifies tier, override, automerge" \
    "tier=" "override=" "automerge=" "--label-actor" "--codeowners"
}

check_pr_review_contract() { # AC-045-04
  verify_grep AC-045-04 "$AGENT" "pr-review contract carries both verdict lines" \
    "Review-Verdict: pass" "Review-Verdict: findings" "Reviewed-SHA: <head sha>"
  verify_grep AC-045-04 "$AGENT" "scope lock and permission block unchanged" \
    "auto-merge" "auto-apply" "describe" "improve" "edit:" "bash:"
}

check_verdict_script() { # AC-045-05
  verify_artifact AC-045-05 "$VERDICT" "pr-review-verdict.sh exists and is executable"
  verify_grep AC-045-05 "$VERDICT" "verdict parser prints verdict= and fails closed" \
    "--head-sha" "--comments-file" "verdict=malformed" "verdict=missing"
}

check_eligibility_script() { # AC-045-06
  verify_artifact AC-045-06 "$ELIGIBLE" "pr-automerge-eligibility.sh exists and is executable"
  verify_grep AC-045-06 "$ELIGIBLE" "predicate evaluates tier, verdict, exclusions, mode" \
    "--size-tier" "--review-verdict" "--changed-files" "--mode" "eligible=" "action="
}

check_required_check_workflows() { # AC-045-07
  verify_grep AC-045-07 "$SIZE_WF" "size workflow is a pinned read-only reusable" \
    "workflow_call" "pr-number" "base-sha" "head-sha" "base-ref" \
    "ref: $PIN" "contents: read" "pull-requests: read" "issues: read" \
    "gh pr view" "size-override" "exit \"\$rc\""
  verify_grep AC-045-07 "$VERDICT_WF" "verdict workflow is a pinned read-only reusable" \
    "workflow_call" "pr-number" "head-sha" "ref: $PIN" "contents: read" \
    "pull-requests: read" "pr-review-verdict.sh" "exit \"\$rc\""
  verify_absent AC-045-07 "$SIZE_WF" "size workflow never runs pull_request_target" 'pull_request_target'
  verify_absent AC-045-07 "$VERDICT_WF" "verdict workflow never runs pull_request_target" 'pull_request_target'
  verify_absent AC-045-07 "$SIZE_WF" "size workflow grants no write scope" '^[[:space:]]+[a-z-]+: write'
  verify_absent AC-045-07 "$VERDICT_WF" "verdict workflow grants no write scope" '^[[:space:]]+[a-z-]+: write'
}

check_automerge_workflow() { # AC-045-08
  verify_grep AC-045-08 "$AUTOMERGE_WF" "auto-merge reusable carries the decision and mode" \
    "workflow_call" "  automerge:" "vars.PR_AUTOMERGE_MODE" "MODE=\"report\"" \
    "allow_auto_merge" "pr-size-gate.sh" "pr-review-verdict.sh"
  verify_grep AC-045-08 "$AUTOMERGE_WF" "live arming uses native auto-merge with squash" \
    "gh pr merge --auto --squash" "contents: write" "pull-requests: write"
  verify_absent AC-045-08 "$AUTOMERGE_WF" "no direct merge strategy or admin merge" \
    'gh pr merge --(merge|rebase|admin)'
  verify_absent AC-045-08 "$AUTOMERGE_WF" "no per-repository allowlist" 'github\.repository(_owner)? =='
  verify_grep AC-045-08 "$CALLER_WF" "caller wires three SHA-pinned jobs" \
    "ci-pr-size-gate.yml@$PIN" "ci-pr-review-verdict.yml@$PIN" "ci-pr-auto-merge.yml@$PIN" \
    "needs: [pr-size, review-verdict]" "pull_request:"
  verify_absent AC-045-08 "$CALLER_WF" "caller never tracks a branch" 'uses: .*@(main|master)'
}

check_notify_script() { # AC-045-09
  verify_artifact AC-045-09 "$NOTIFY" "pr-automerge-notify.sh exists and is executable"
  verify_grep AC-045-09 "$NOTIFY" "notification renders the three outcomes and the marker" \
    "armed" "would-merge" "blocked-exclusion" "pr-automerge: "
}

check_init_ci_wiring() { # AC-045-10
  verify_grep AC-045-10 "$INIT_CI" "init-ci documents and parses both flags" \
    "[--with-pr-size-gate]" "[--with-pr-automerge]" \
    "WITH_PR_SIZE_GATE_FLAG=\"true\"" "WITH_PR_AUTOMERGE_FLAG=\"true\""
  verify_grep AC-045-10 "$CATALOG" "catalog carries both capability rows" \
    "|--with-pr-size-gate|no|none|{ci}|--with-pr-size-gate|" \
    "|--with-pr-automerge|no|none|{ci}|--with-pr-automerge|"
}

check_self_hosting() { # AC-045-11
  verify_grep AC-045-11 "$SELF_CI" "self-ci runs this gate and the four bats files" \
    "scripts/check-pr-size-gate.sh" \
    "scripts/tests/pr-size-gate.bats" \
    "scripts/tests/pr-review-verdict.bats" \
    "scripts/tests/pr-automerge-eligibility.bats" \
    "scripts/tests/pr-automerge-notify.bats"
  # The literal is assembled at runtime so this script's own pattern cannot
  # match itself (same technique as check-pr-review.sh's key-shape patterns).
  local live_assign="PR_AUTOMERGE_MODE""=live" live_hits
  live_hits="$(grep -rn --exclude-dir=tests --exclude="$(basename "$0")" \
    -F -- "$live_assign" \
    "$ROOT_DIR/.github" "$ROOT_DIR/scripts" "$ROOT_DIR/docs" "$ROOT_DIR/templates" "$AGENTS_MD" 2>/dev/null || true)"
  if [ -z "$live_hits" ]; then
    pass "AC-045-11: no committed file hardcodes the live auto-merge mode"
  else
    fail "AC-045-11: a committed file hardcodes the live auto-merge mode: $live_hits"
  fi
}

check_documentation() { # AC-045-12
  verify_grep AC-045-12 "$AGENTS_MD" "AGENTS.md states the auto-merge rule" \
    "native auto-merge" "pr-review" "never merges" "no-direct-push"
  verify_grep AC-045-12 "$GIT_WF" "GIT_WORKFLOW documents tiers, override, prerequisites" \
    "## PR Size and Auto-Merge" "200" "400" "size-override" "CODEOWNER" \
    "pr-size" "review-verdict" "no per-repo allowlist" "same behavior"
  verify_grep AC-045-12 "$CI_CD" "CI_CD documents the workflows, settings, exclusions" \
    "## PR Size Gate and Review-Gated Auto-Merge" "ci-pr-size-gate.yml" \
    "ci-pr-review-verdict.yml" "ci-pr-auto-merge.yml" "pr-size" "review-verdict" \
    "PR_AUTOMERGE_MODE" "exclusion" "comment"
  verify_grep AC-045-12 "$BRANCH_PROT" "branch protection lists contexts and prerequisites" \
    "pr-size" "review-verdict" "MUTATION_REQUIRED=true" "allow_auto_merge" "squash"
}

run_checks() { # run_checks <root> — sets VIOLATIONS, prints per-check lines
  VIOLATIONS=0
  init_paths "$1"

  echo "Checking PR size gate and auto-merge deliverables in: $1"
  echo ""

  check_adr
  check_size_gate_script
  check_pr_review_contract
  check_verdict_script
  check_eligibility_script
  check_required_check_workflows
  check_automerge_workflow
  check_notify_script
  check_init_ci_wiring
  check_self_hosting
  check_documentation

  echo ""
  [ "$VIOLATIONS" -eq 0 ]
}

if [ "${1:-}" = "--self-test" ]; then
  # Prove the gate fails closed: copy the real tree, confirm the baseline
  # passes, then remove a required artifact and confirm the gate catches it.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(dirname "$SCRIPT_DIR")"
  FIXTURE="$(mktemp -d)"
  trap 'rm -rf "$FIXTURE"' EXIT
  cp -a "$REPO_ROOT/scripts" "$REPO_ROOT/.github" "$REPO_ROOT/agents" \
    "$REPO_ROOT/docs" "$REPO_ROOT/templates" "$REPO_ROOT/AGENTS.md" \
    "$REPO_ROOT/opencode.json" "$FIXTURE/" 2>/dev/null || true

  FAILURES=0
  if run_checks "$FIXTURE" > /dev/null 2>&1; then
    echo "PASS baseline: unmodified fixture (copy of the real repo) passes clean"
  else
    echo "FAIL baseline: unmodified fixture did not pass"
    FAILURES=$((FAILURES + 1))
  fi

  rm -f "$FIXTURE/scripts/pr-review-verdict.sh"
  if run_checks "$FIXTURE" > "$FIXTURE/out" 2>&1; then
    echo "FAIL case 1: a missing required artifact was not caught (AC-045-11)"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS case 1: a missing required artifact is caught"
  fi

  echo ""
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}FAIL${NC} check-pr-size-gate --self-test: $FAILURES case(s) failed."
    exit 1
  fi
  echo -e "${GREEN}PASS${NC} check-pr-size-gate --self-test: baseline passes, a removed artifact is caught."
  exit 0
fi

if [ -n "${1:-}" ]; then
  TARGET_ROOT="$1"
else
  TARGET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

run_checks "$TARGET_ROOT" || true

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}FAIL${NC} PR size gate and auto-merge check: $VIOLATIONS violation(s). Fix before merging."
  echo "  Reference: docs/CI_CD.md §PR Size Gate and Review-Gated Auto-Merge, specs/045-pr-size-gate-and-auto-merge/20-acceptance/"
  exit 1
fi
echo -e "${GREEN}PASS${NC} PR size gate and auto-merge check: every check passed."
exit 0
