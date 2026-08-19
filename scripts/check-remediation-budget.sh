#!/bin/bash
# check-remediation-budget.sh — Verify the bounded remediation budget is
# documented in docs/SPEC_PIPELINE.md and encoded in the pipeline's prompts
# and orchestrator (spec 008).
#
# The pipeline's gate-failure loops are capped: max 3 fix attempts per phase,
# two independent phases (pre-PR and post-PR), with exhaustion stopping the
# pipeline and escalating to the human. This spec changes markdown prompts
# and docs only, so the check script is the test carrier — grep-based content
# assertions over the files the spec touches, so
# scripts/check-scenario-traceability.sh can resolve every AC-008-NN scenario
# to a real test.
#
# Checks (specs/008-remediation-budget/20-acceptance/):
#   1. docs/SPEC_PIPELINE.md documents both phases, max-3 budgets, the
#      independent-counter rule, exhaustion behavior, scoped re-verification,
#      the 30-report.md record, and the carve-out reconciliation (AC-008-01)
#   2. agents/spec-verifier.md encodes the per-phase cap, scoped
#      re-verification, and the attempt-index/phase record (AC-008-02)
#   3. agents/spec-coder.md and agents/spec-refactorer.md encode the re-fix
#      cap, unchanged frontmatter, no open-ended re-run phrasing (AC-008-03)
#   4. commands/build.md and agents/spec-pipeline.md run a bounded phase-1
#      loop, stop on the 3rd BLOCK with the escalation payload, still gate
#      stage-5 on a Verifier PASS, and only acknowledge phase 2 (AC-008-04)
#   5. agents/spec-mutation-runner.md requires the remediation record in
#      30-report.md, carried forward not invented (AC-008-05)
#   6. .github/workflows/self-ci.yml runs this script, and this script is
#      executable (AC-008-01 wiring + AC-008-04 no-new-infra)
#
# Usage:
#   scripts/check-remediation-budget.sh [ROOT_DIR]
#   ROOT_DIR defaults to the current directory (repo root when run from CI).
#
# Exit codes:
#   0 — every check passes
#   1 — one or more required strings are missing or a forbidden string appears
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Remediation budget
#   specs/008-remediation-budget/20-acceptance/ (AC-008-01 … AC-008-05)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
ROOT_DIR="${1:-.}"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

echo "Checking remediation budget encoding in: $ROOT_DIR"
echo ""

PIPELINE_DOC="$ROOT_DIR/docs/SPEC_PIPELINE.md"
VERIFIER="$ROOT_DIR/agents/spec-verifier.md"
CODER="$ROOT_DIR/agents/spec-coder.md"
REFACTORER="$ROOT_DIR/agents/spec-refactorer.md"
BUILD_CMD="$ROOT_DIR/commands/build.md"
ORCHESTRATOR="$ROOT_DIR/agents/spec-pipeline.md"
MUTATION_RUNNER="$ROOT_DIR/agents/spec-mutation-runner.md"
SELF_CI="$ROOT_DIR/.github/workflows/self-ci.yml"

# collapse_whitespace <file>
# Collapse the file's whitespace runs (including newlines) to single spaces,
# so assertions hold regardless of where markdown wraps lines.
collapse_whitespace() {
  tr '\n' ' ' < "$1" | sed 's/[[:space:]]\+/ /g' 2>/dev/null || true
}

# assert_contains <AC-ID> <description> <string> <file>
assert_contains() {
  local id="$1" desc="$2" needle="$3" file="$4"
  if printf '%s' "$(collapse_whitespace "$file")" | grep -qF -- "$needle"; then
    pass "$id: $desc"
  else
    fail "$id: $desc — missing string '$needle' in $file"
  fi
}

# assert_absent <AC-ID> <description> <string> <file>
assert_absent() {
  local id="$1" desc="$2" needle="$3" file="$4"
  if printf '%s' "$(collapse_whitespace "$file")" | grep -qF -- "$needle"; then
    fail "$id: $desc — forbidden string '$needle' present in $file"
  else
    pass "$id: $desc"
  fi
}

# require_file <AC-ID> <description> <file>
# Marks a violation when an input file is missing and skips the check's
# assertions — every check still reports, nothing aborts early.
require_file() {
  if [ -f "$3" ]; then
    return 0
  fi
  fail "$1: $2"
  return 1
}

# ── Check 1: docs/SPEC_PIPELINE.md remediation-budget section (AC-008-01) ─────
echo "── Check 1: docs/SPEC_PIPELINE.md (AC-008-01) ──"
if require_file "AC-008-01" "docs/SPEC_PIPELINE.md missing" "$PIPELINE_DOC"; then
  assert_contains "AC-008-01" "remediation-budget section present" "## Remediation budget" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "Phase 1 — Pre-PR loop named" "Phase 1 — Pre-PR loop" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "BLOCK hands back to Coder/Refactorer" "hands the failing fix back to the Coder (behavior failures) or the Refactorer (structural/complexity failures)" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "Phase 1 budget is max 3" "Phase 1 budget is **max 3**" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "Phase 2 — Post-PR loop named" "Phase 2 — Post-PR loop" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "Phase 2 budget is max 3" "budget is **max 3**" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "Phase 2 counter independent of Phase 1" "independent of **Phase 1**" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "exhaustion stops the pipeline" "Exhausting either budget stops the pipeline" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "emits failing gate IDs and last evidence" "failing gate IDs and the last evidence" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "escalates to the human" "escalates to the human" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "forbidden phrasing verbatim (AC-003)" "re-run until green is forbidden phrasing" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "scoped re-verification named" "scoped re-verification" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "re-runs only the failing gates" "re-runs only the failing gates" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "does not re-run the whole suite" "not the whole suite" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "30-report.md records phase and attempt count (AC-004)" "records which phase and attempt count each BLOCK was resolved at" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "reconciles with the carve-out halt rule" "triggers remediation up to the cap" "$PIPELINE_DOC"
  assert_contains "AC-008-01" "post-exhaustion stop is the halt" "post-exhaustion stop is the halt" "$PIPELINE_DOC"
  # Phase-2 policy only: the section must not describe CI-query/log mechanics.
  SECTION="$(awk '/^## Remediation budget/{f=1;next} /^## /{f=0} f' "$PIPELINE_DOC")"
  if printf '%s\n' "$SECTION" | grep -q 'curl'; then
    fail "AC-008-01: section must not describe CI-query mechanics — contains 'curl'"
  else
    pass "AC-008-01: section describes no CI-query mechanics (no 'curl')"
  fi
  if printf '%s\n' "$SECTION" | grep -q 'gh run'; then
    fail "AC-008-01: section must not describe CI-query mechanics — contains 'gh run'"
  else
    pass "AC-008-01: section describes no CI-query mechanics (no 'gh run')"
  fi
fi
echo ""

# ── Check 2: agents/spec-verifier.md (AC-008-02) ──────────────────────────────
echo "── Check 2: agents/spec-verifier.md (AC-008-02) ──"
if require_file "AC-008-02" "agents/spec-verifier.md missing" "$VERIFIER"; then
  assert_contains "AC-008-02" "stops relaying BLOCKs after 3" "stop relaying BLOCKs after 3" "$VERIFIER"
  assert_contains "AC-008-02" "cap is per phase" "per phase" "$VERIFIER"
  assert_contains "AC-008-02" "must not accept a 4th re-verification" "must not expect or accept a 4th re-verification of the same BLOCK" "$VERIFIER"
  assert_contains "AC-008-02" "reads its prior 25-verification.md" "read your prior" "$VERIFIER"
  assert_contains "AC-008-02" "re-runs only gates that previously failed" "re-run only the gates that previously failed" "$VERIFIER"
  assert_contains "AC-008-02" "records per-gate results for those gates" "record per-gate results for just those gates" "$VERIFIER"
  assert_contains "AC-008-02" "does not re-run the full suite" "do not re-run the whole suite" "$VERIFIER"
  assert_contains "AC-008-02" "records attempt index and phase (AC-004)" "re-verification attempt index and the phase" "$VERIFIER"
  assert_contains "AC-008-02" "does not fix anything itself" "Do not attempt to fix anything yourself" "$VERIFIER"
  assert_contains "AC-008-02" "final BLOCK names failing gate IDs and last evidence" "names the failing gate IDs and the last evidence" "$VERIFIER"
  assert_contains "AC-008-02" "final BLOCK states budget exhausted" "phase budget is exhausted" "$VERIFIER"
  assert_contains "AC-008-02" "frontmatter edits only 25-verification.md" '"specs/*/25-verification.md": allow' "$VERIFIER"
  assert_contains "AC-008-02" "frontmatter denies other edits" '"*": deny' "$VERIFIER"
  assert_contains "AC-008-02" "frontmatter denies commits and pushes" '"git push*": deny' "$VERIFIER"
  assert_absent  "AC-008-02" "no open-ended re-run phrasing" "re-run until green" "$VERIFIER"
fi
echo ""

# ── Check 3: agents/spec-coder.md + agents/spec-refactorer.md (AC-008-03) ─────
echo "── Check 3: fixer prompts (AC-008-03) ──"
if require_file "AC-008-03" "agents/spec-coder.md missing" "$CODER"; then
  assert_contains "AC-008-03" "Coder stops re-fixing after 3 attempts per BLOCK" "stop re-fixing after **3** attempts per BLOCK" "$CODER"
  assert_contains "AC-008-03" "Coder does not accept another re-fix request" "do not accept another re-fix request" "$CODER"
  assert_contains "AC-008-03" "Coder hands back with failing gate IDs and last evidence" "failing gate IDs and the last evidence" "$CODER"
  assert_contains "AC-008-03" "Coder frontmatter denies pushes" '"git push*": deny' "$CODER"
  assert_contains "AC-008-03" "Coder still forbids commit/push" "Do not commit or push" "$CODER"
  assert_absent  "AC-008-03" "Coder: no open-ended re-run phrasing" "re-run until green" "$CODER"
fi
if require_file "AC-008-03" "agents/spec-refactorer.md missing" "$REFACTORER"; then
  assert_contains "AC-008-03" "Refactorer at most 3 structural re-fixes per BLOCK" "**max 3** structural re-fixes per BLOCK" "$REFACTORER"
  assert_contains "AC-008-03" "Refactorer reports at cap, no further requests" "report and do not accept further re-fix requests" "$REFACTORER"
  assert_contains "AC-008-03" "Refactorer frontmatter denies pushes" '"git push*": deny' "$REFACTORER"
  assert_contains "AC-008-03" "Refactorer still forbids commit/push" "Do not commit or push" "$REFACTORER"
  assert_absent  "AC-008-03" "Refactorer: no open-ended re-run phrasing" "re-run until green" "$REFACTORER"
fi
echo ""

# ── Check 4: commands/build.md + agents/spec-pipeline.md (AC-008-04) ──────────
echo "── Check 4: orchestrator + /build command (AC-008-04) ──"
if require_file "AC-008-04" "commands/build.md missing" "$BUILD_CMD"; then
  assert_contains "AC-008-04" "build.md: BLOCK re-delegates failing fix" "re-delegate the failing fix back to" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: re-invokes Verifier for scoped re-verification" "re-invoke \`spec-verifier\` for scoped re-verification" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: at most 3 cycles" "at most **3** cycles" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: 3rd BLOCK stops the pipeline" "On the 3rd BLOCK" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: relays failing gate IDs and last evidence from 25-verification.md" "failing gate IDs and the last evidence from \`25-verification.md\`" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: escalates to the human" "escalate to the human" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: no 4th re-delegation" "no 4th re-delegation" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: stage-5 runs only after Verifier PASS" "PASS before stage-5" "$BUILD_CMD"
  assert_contains "AC-008-04" "build.md: phase-2 acknowledged with independent max-3 budget" "independent max-3 budget" "$BUILD_CMD"
  assert_absent  "AC-008-04" "build.md: no open-ended re-run phrasing" "re-run until green" "$BUILD_CMD"
  assert_absent  "AC-008-04" "build.md: no CI-query mechanics" "gh run" "$BUILD_CMD"
fi
if require_file "AC-008-04" "agents/spec-pipeline.md missing" "$ORCHESTRATOR"; then
  assert_contains "AC-008-04" "spec-pipeline.md: BLOCK re-delegates failing fix" "re-delegate the failing fix back to" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: routes behavior to Coder, structural to Refactorer" "behavior failures) or \`spec-refactorer\` (structural/complexity failures" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: up to 3 cycles" "up to **3** cycles" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: 3rd BLOCK stops the pipeline" "On the 3rd BLOCK" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: relays failing gate IDs and last evidence from 25-verification.md" "failing gate IDs and the last evidence from \`25-verification.md\`" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: escalates to the human" "escalate to the human" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: no 4th re-delegation" "no 4th re-delegation" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: stage-5 runs only after Verifier PASS" "unless the Verifier's verdict is PASS" "$ORCHESTRATOR"
  assert_contains "AC-008-04" "spec-pipeline.md: phase-2 acknowledged with independent max-3 budget" "independent max-3 budget" "$ORCHESTRATOR"
  assert_absent  "AC-008-04" "spec-pipeline.md: no open-ended re-run phrasing" "re-run until green" "$ORCHESTRATOR"
  assert_absent  "AC-008-04" "spec-pipeline.md: no CI-query mechanics" "gh run" "$ORCHESTRATOR"
fi
echo ""

# ── Check 5: agents/spec-mutation-runner.md (AC-008-05) ───────────────────────
echo "── Check 5: agents/spec-mutation-runner.md (AC-008-05) ──"
if require_file "AC-008-05" "agents/spec-mutation-runner.md missing" "$MUTATION_RUNNER"; then
  assert_contains "AC-008-05" "Report section requires a remediation record" "Remediation record" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "record states phase (1 or 2) and attempt count per BLOCK" "the phase (1 or 2) and the attempt count" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "record states none when no BLOCK occurred" "\`none\` when no BLOCK occurred" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "record carried from 25-verification.md" "record forward from \`25-verification.md\`" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "record carried from the orchestrator's loop summary" "orchestrator's loop summary" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "not invented or guessed" "never guessed or invented" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "missing attempt info reported, not fabricated" "no \`25-verification.md\` attempt information is present" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "missing info says so rather than fabricating" "rather than fabricating" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "Verifier's verdict carried forward" "Verifier's verdict (carried forward)" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "mutation score / tier skip reason kept" "skipped — \`<tier>\` tier" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "complexity summary kept" "Complexity summary carried from the Refactorer" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "equivalent mutants kept" "Every equivalent mutant" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "final test status kept" "Final test status" "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "frontmatter denies commits and pushes" '"git push*": deny' "$MUTATION_RUNNER"
  assert_contains "AC-008-05" "does not commit, push, or open a PR" "commit, push, or open a PR" "$MUTATION_RUNNER"
fi
echo ""

# ── Check 6: self-ci wiring + executable (AC-008-01 wiring, AC-008-04) ────────
echo "── Check 6: self-ci wiring (AC-008-01, AC-008-04) ──"
if [ -f "$SELF_CI" ] && grep -qF 'check-remediation-budget.sh' "$SELF_CI"; then
  pass "AC-008-01/AC-008-04: .github/workflows/self-ci.yml runs check-remediation-budget.sh"
else
  fail "AC-008-01/AC-008-04: .github/workflows/self-ci.yml does not run check-remediation-budget.sh"
fi
if [ -x "$ROOT_DIR/scripts/check-remediation-budget.sh" ]; then
  pass "AC-008-04: scripts/check-remediation-budget.sh exists and is executable"
else
  fail "AC-008-04: scripts/check-remediation-budget.sh is missing or not executable"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Remediation budget check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/SPEC_PIPELINE.md §Remediation budget"
  exit 1
else
  echo -e "${GREEN}✔ Remediation budget check: every check passed.${NC}"
fi
