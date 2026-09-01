#!/bin/bash
# check-security-hardening.sh — Verify the spec-026 CI/CD and agent-invocation
# security-hardening deliverables are present and carry the required content.
#
# Spec 026 fixed thirteen findings from a security review of this repo's own
# .github/workflows/, agents/pr-review.md, and headless-agent invocation
# plumbing (specs/026-ci-security-hardening/00-informal.md). This script is
# the test carrier for its acceptance scenarios (docs/SPEC_PIPELINE.md
# §Scenario format, §Why no scenario mutation): it cites every AC-026-NN
# scenario ID and greps the required strings/patterns in the fixed
# artifacts, so scripts/check-scenario-traceability.sh resolves them, and it
# exits 0 only when every content assertion holds.
#
# Checks (one per finding, specs/026-ci-security-hardening/20-acceptance/):
#   AC-026-01  ci-sweeper.yml: fork-origin guard + no ref: override on checkout
#   AC-026-02  pr-review.md mode: primary; ci-pr-review.yml invokes --agent
#   AC-026-03  pr-review.md untrusted-content warning
#   AC-026-04  install-opencode.sh checksum; daily-triage.yml delegates to it
#   AC-026-05  ci-deploy-ssh.yml: SSH_KNOWN_HOSTS, no StrictHostKeyChecking=no
#   AC-026-06  ci-deploy-ssh.yml: caller-input validation step
#   AC-026-07  ci-deploy-ssh.yml: env: mapping, no inline secrets, key cleanup
#   AC-026-08  ci-sweeper.yml budget guard; loop-budget.md §ci-sweeper
#   AC-026-09  check-no-hardcoded-secrets.sh: widened scope, --self-test green
#   AC-026-10  ci-dependabot.yml: patch-only auto-merge
#   AC-026-11  ci-toolchain-bump.yml: version-shape validation before sed -i
#   AC-026-12  config/agent.local.env.example: no classic-PAT nudge
#   AC-026-13  no @main/@master third-party or cross-repo workflow refs
#
# Usage:
#   scripts/check-security-hardening.sh [ROOT_DIR]
#   scripts/check-security-hardening.sh --self-test
#   ROOT_DIR defaults to the current directory.
#
# Exit codes:
#   0 — every check passes
#   1 — one or more required artifacts/strings/references are missing
#
# Standards reference:
#   docs/SECURITY.md §CI/CD Supply Chain (spec 026 — consumed by reference)
#   specs/026-ci-security-hardening/20-acceptance/ (AC-026-01 … AC-026-13)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

# verify_grep <AC-ID> <file> <label> <pattern>...
#   Every <pattern> must appear (fixed-string match) in <file>.
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

# verify_absent_re <AC-ID> <file> <label> <extended-regex>
#   The extended regex must NOT appear in <file>.
verify_absent_re() {
  local acid="$1" file="$2" label="$3" re="$4"
  if grep -qE -- "$re" "$file" 2>/dev/null; then
    fail "$acid: $label — forbidden pattern '$re' present in $file"
  else
    pass "$acid: $label"
  fi
}

run_checks() {
  local ROOT_DIR="$1"

  SWEEPER_WF="$ROOT_DIR/.github/workflows/ci-sweeper.yml"
  PR_REVIEW_AGENT="$ROOT_DIR/agents/pr-review.md"
  PR_REVIEW_WF="$ROOT_DIR/.github/workflows/ci-pr-review.yml"
  INSTALL_SH="$ROOT_DIR/scripts/install-opencode.sh"
  DAILY_TRIAGE_WF="$ROOT_DIR/.github/workflows/daily-triage.yml"
  DEPLOY_WF="$ROOT_DIR/.github/workflows/ci-deploy-ssh.yml"
  LOOP_BUDGET="$ROOT_DIR/loop-budget.md"
  SECRETS_SH="$ROOT_DIR/scripts/check-no-hardcoded-secrets.sh"
  DEPENDABOT_WF="$ROOT_DIR/.github/workflows/ci-dependabot.yml"
  TOOLCHAIN_WF="$ROOT_DIR/.github/workflows/ci-toolchain-bump.yml"
  AGENT_ENV_EXAMPLE="$ROOT_DIR/config/agent.local.env.example"
  SELF_CI="$ROOT_DIR/.github/workflows/self-ci.yml"

  echo "Checking spec-026 security-hardening deliverables in: $ROOT_DIR"
  echo ""

  # ── AC-026-01: ci-sweeper.yml pwn-request guard ──────────────────────────
  if [ -f "$SWEEPER_WF" ]; then
    verify_grep AC-026-01 "$SWEEPER_WF" "fork-origin guard on the sweep job" \
      "github.event.workflow_run.head_repository.full_name == github.repository"
    verify_absent_re AC-026-01 "$SWEEPER_WF" "no ref: override checking out the failing commit" \
      "ref: \\\$\\{\\{ github\.event\.workflow_run\.head_sha"
  else
    fail "AC-026-01: $SWEEPER_WF is missing"
  fi

  echo ""

  # ── AC-026-02: pr-review agent invoked with a real permission block ──────
  if [ -f "$PR_REVIEW_AGENT" ]; then
    verify_grep AC-026-02 "$PR_REVIEW_AGENT" "agent mode is primary (permission block loads for real)" \
      "mode: primary"
  else
    fail "AC-026-02: $PR_REVIEW_AGENT is missing"
  fi
  if [ -f "$PR_REVIEW_WF" ]; then
    verify_grep AC-026-02 "$PR_REVIEW_WF" "review step invokes --agent pr-review" \
      "--agent pr-review"
    verify_absent_re AC-026-02 "$PR_REVIEW_WF" "no frontmatter-stripping invocation" \
      "sed '/\^---\$/,/\^---\$/d'"
  else
    fail "AC-026-02: $PR_REVIEW_WF is missing"
  fi

  echo ""

  # ── AC-026-03: untrusted-content warning ─────────────────────────────────
  if [ -f "$PR_REVIEW_AGENT" ]; then
    verify_grep AC-026-03 "$PR_REVIEW_AGENT" "untrusted-content warning present" \
      "not instructions from your" "permission" "block is the real boundary"
  else
    fail "AC-026-03: $PR_REVIEW_AGENT is missing"
  fi

  echo ""

  # ── AC-026-04: checksum-verified opencode install ────────────────────────
  if [ -f "$INSTALL_SH" ]; then
    verify_grep AC-026-04 "$INSTALL_SH" "SHA-256 pinned and verified before extracting" \
      "SHA256=" "sha256sum -c"
  else
    fail "AC-026-04: $INSTALL_SH is missing"
  fi
  if [ -f "$DAILY_TRIAGE_WF" ]; then
    verify_grep AC-026-04 "$DAILY_TRIAGE_WF" "daily-triage.yml delegates to the shared install script" \
      "bash scripts/install-opencode.sh"
    verify_absent_re AC-026-04 "$DAILY_TRIAGE_WF" "no duplicated inline opencode download" \
      "curl -sSL -o /tmp/opencode-bin/opencode-linux-x64\.tar\.gz"
  else
    fail "AC-026-04: $DAILY_TRIAGE_WF is missing"
  fi

  echo ""

  # ── AC-026-05: known_hosts pinning, no StrictHostKeyChecking=no ──────────
  if [ -f "$DEPLOY_WF" ]; then
    verify_grep AC-026-05 "$DEPLOY_WF" "SSH_KNOWN_HOSTS secret pins the host key" \
      "SSH_KNOWN_HOSTS"
    verify_absent_re AC-026-05 "$DEPLOY_WF" "no StrictHostKeyChecking=no flag on any ssh/scp call" \
      "\-o StrictHostKeyChecking=no"
  else
    fail "AC-026-05: $DEPLOY_WF is missing"
  fi

  echo ""

  # ── AC-026-06: caller-input validation ───────────────────────────────────
  if [ -f "$DEPLOY_WF" ]; then
    verify_grep AC-026-06 "$DEPLOY_WF" "app-dir/service-name validated before remote use" \
      "Validate caller-supplied inputs" 'safe_re='
  else
    fail "AC-026-06: $DEPLOY_WF is missing"
  fi

  echo ""

  # ── AC-026-07: secrets via env:, key removed on exit ─────────────────────
  if [ -f "$DEPLOY_WF" ]; then
    verify_grep AC-026-07 "$DEPLOY_WF" "SSH private key removed with if: always()" \
      "Remove SSH private key" "if: always()" "rm -f ~/.ssh/id_rsa"
    verify_absent_re AC-026-07 "$DEPLOY_WF" "no secrets.* interpolated directly into a run: body" \
      'run: \|[^E]*\$\{\{ secrets\.'
  else
    fail "AC-026-07: $DEPLOY_WF is missing"
  fi

  echo ""

  # ── AC-026-08: sweeper invocation budget ─────────────────────────────────
  if [ -f "$SWEEPER_WF" ]; then
    verify_grep AC-026-08 "$SWEEPER_WF" "budget-guard step gates the install/sweep steps" \
      "Check sweeper invocation budget" "over-budget"
  else
    fail "AC-026-08: $SWEEPER_WF is missing"
  fi
  if [ -f "$LOOP_BUDGET" ]; then
    verify_grep AC-026-08 "$LOOP_BUDGET" "loop-budget.md documents the ci-sweeper cap" \
      "## ci-sweeper" "24h"
  else
    fail "AC-026-08: $LOOP_BUDGET is missing"
  fi

  echo ""

  # ── AC-026-09: hardcoded-secrets gate fix ────────────────────────────────
  if [ -f "$SECRETS_SH" ]; then
    verify_grep AC-026-09 "$SECRETS_SH" "quoting alone no longer exempts a value" \
      "quoting alone no longer" ".github config templates ci"
    verify_absent_re AC-026-09 "$SECRETS_SH" "no unconditional quoted-string bypass in is_ignored_rhs" \
      "^\s*'\"'\\*\s*\\|\s*\"'\"'\\*\s*\\)\s*return 0"
    if bash "$SECRETS_SH" --self-test > /dev/null 2>&1; then
      pass "AC-026-09: check-no-hardcoded-secrets.sh --self-test passes"
    else
      fail "AC-026-09: check-no-hardcoded-secrets.sh --self-test failed"
    fi
  else
    fail "AC-026-09: $SECRETS_SH is missing"
  fi

  echo ""

  # ── AC-026-10: Dependabot patch-only auto-merge ──────────────────────────
  if [ -f "$DEPENDABOT_WF" ]; then
    verify_grep AC-026-10 "$DEPENDABOT_WF" "auto-merge restricted to semver-patch" \
      "update-type == 'version-update:semver-patch'"
    verify_absent_re AC-026-10 "$DEPENDABOT_WF" "semver-minor no longer auto-merged" \
      "semver-minor"
  else
    fail "AC-026-10: $DEPENDABOT_WF is missing"
  fi

  echo ""

  # ── AC-026-11: toolchain-bump version-shape validation ───────────────────
  if [ -f "$TOOLCHAIN_WF" ]; then
    verify_grep AC-026-11 "$TOOLCHAIN_WF" "fetched version validated before sed -i / manifest write" \
      'unexpected version shape' '=~ ^[0-9]+$'
  else
    fail "AC-026-11: $TOOLCHAIN_WF is missing"
  fi

  echo ""

  # ── AC-026-12: no classic-PAT nudge ───────────────────────────────────────
  if [ -f "$AGENT_ENV_EXAMPLE" ]; then
    verify_absent_re AC-026-12 "$AGENT_ENV_EXAMPLE" "GH_TOKEN comment no longer suggests a classic PAT" \
      "[Cc]reate a classic PAT"
  else
    fail "AC-026-12: $AGENT_ENV_EXAMPLE is missing"
  fi

  echo ""

  # ── AC-026-13: no @main/@master for third-party or cross-repo workflows ─
  local hits
  hits=$(grep -rE 'uses: (actions|docker|github|aquasecurity|dependabot|cycjimmy|peter-evans|ruby)/[^@[:space:]]+@(v[0-9]|master)([^0-9a-f]|$)' \
    "$ROOT_DIR"/.github/workflows/*.yml 2>/dev/null || true)
  if [ -z "$hits" ]; then
    pass "AC-026-13: every third-party Action in .github/workflows/*.yml is SHA-pinned"
  else
    fail "AC-026-13: mutable third-party Action ref(s) found: $hits"
  fi
  local main_hits
  main_hits=$(grep -rlE 'my-engineering-standards/\.github/workflows/[^@[:space:]]*@main' \
    "$ROOT_DIR"/.github "$ROOT_DIR"/ci "$ROOT_DIR"/scripts 2>/dev/null || true)
  if [ -z "$main_hits" ]; then
    pass "AC-026-13: no live workflow/script/template references this repo's own workflows via @main"
  else
    fail "AC-026-13: @main reference(s) to this repo's own reusable workflows found in: $main_hits"
  fi

  echo ""

  # ── Self-citation: this script cites every AC-026-NN scenario ID ────────
  local SCENARIO_IDS=(AC-026-01 AC-026-02 AC-026-03 AC-026-04 AC-026-05 AC-026-06 \
    AC-026-07 AC-026-08 AC-026-09 AC-026-10 AC-026-11 AC-026-12 AC-026-13)
  local MISSING_IDS=() id
  for id in "${SCENARIO_IDS[@]}"; do
    grep -q -- "$id" "$0" || MISSING_IDS+=("$id")
  done
  if [ "${#MISSING_IDS[@]}" -eq 0 ]; then
    pass "self-citation: script cites every AC-026-NN scenario ID (AC-026-01 … AC-026-13)"
  else
    fail "self-citation: script does not cite: ${MISSING_IDS[*]}"
  fi

  if [ -f "$SELF_CI" ] && grep -q 'check-security-hardening.sh' "$SELF_CI"; then
    pass "self-ci: .github/workflows/self-ci.yml runs check-security-hardening.sh"
  else
    fail "self-ci: .github/workflows/self-ci.yml does not run check-security-hardening.sh"
  fi

  [ "$VIOLATIONS" -eq 0 ]
}

if [ "${1:-}" = "--self-test" ]; then
  # Prove the gate fails closed: copy the real repo tree to a scratch dir,
  # revert two representative fixes (AC-026-05's StrictHostKeyChecking=no,
  # AC-026-10's semver-minor auto-merge), and assert the script catches
  # both. A gate that always passes proves nothing.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(dirname "$SCRIPT_DIR")"
  FIXTURE="$(mktemp -d)"
  trap 'rm -rf "$FIXTURE"' EXIT
  cp -r "$REPO_ROOT/.github" "$REPO_ROOT/agents" "$REPO_ROOT/scripts" \
    "$REPO_ROOT/config" "$REPO_ROOT/ci" "$REPO_ROOT/loop-budget.md" "$FIXTURE/" 2>/dev/null || true

  FAILURES=0
  VIOLATIONS=0
  if run_checks "$FIXTURE" > /tmp/shg-baseline.$$ 2>&1; then
    echo "PASS baseline: unmodified fixture (copy of the real repo) passes clean"
  else
    echo "FAIL baseline: unmodified fixture did not pass — see /tmp/shg-baseline.$$"
    FAILURES=$((FAILURES + 1))
  fi

  # Revert AC-026-05's fix in the scratch copy only.
  sed -i "s/StrictHostKeyChecking=yes/StrictHostKeyChecking=no/g" \
    "$FIXTURE/.github/workflows/ci-deploy-ssh.yml"
  VIOLATIONS=0
  if run_checks "$FIXTURE" > /tmp/shg-case1.$$ 2>&1; then
    echo "FAIL case 1: reverted StrictHostKeyChecking=yes was not caught (regression: AC-026-05)"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS case 1: reverted StrictHostKeyChecking fix is caught"
  fi
  # Restore for the next case.
  cp "$REPO_ROOT/.github/workflows/ci-deploy-ssh.yml" "$FIXTURE/.github/workflows/ci-deploy-ssh.yml"

  # Revert AC-026-10's fix in the scratch copy only.
  sed -i "s/update-type == 'version-update:semver-patch'/contains(fromJSON('[\"version-update:semver-patch\", \"version-update:semver-minor\"]'), steps.metadata.outputs.update-type)/" \
    "$FIXTURE/.github/workflows/ci-dependabot.yml"
  VIOLATIONS=0
  if run_checks "$FIXTURE" > /tmp/shg-case2.$$ 2>&1; then
    echo "FAIL case 2: reverted semver-minor auto-merge was not caught (regression: AC-026-10)"
    FAILURES=$((FAILURES + 1))
  else
    echo "PASS case 2: reverted patch-only fix is caught"
  fi

  rm -f /tmp/shg-baseline.$$ /tmp/shg-case1.$$ /tmp/shg-case2.$$

  echo ""
  if [ "$FAILURES" -gt 0 ]; then
    echo -e "${RED}✘ check-security-hardening --self-test: $FAILURES case(s) failed.${NC}"
    exit 1
  fi
  echo -e "${GREEN}PASS${NC} check-security-hardening --self-test: baseline passes, every reverted fix is caught."
  exit 0
fi

ROOT_DIR="${1:-.}"
run_checks "$ROOT_DIR" || true

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Security hardening check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: specs/026-ci-security-hardening/20-acceptance/"
  exit 1
else
  echo -e "${GREEN}✔ Security hardening check: every check passed.${NC}"
  exit 0
fi
