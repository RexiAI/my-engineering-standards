#!/usr/bin/env bash
# tests/AC-030-05.sh — T5: doc wiring (docs/TESTING.md + AGENTS.md)
# Scenarios from specs/030-e2e-skill-agent/20-acceptance/AC-030-05.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"
TESTING="docs/TESTING.md"
AGENTS_MD="AGENTS.md"

# AC-030-05-01 — docs/TESTING.md has an agentic E2E section pointing at the skill,
# with existing Playwright guidance preserved
s_030_05_01() {
  contains_i "AC-030-05-01" "$TESTING" 'agentic e2e' 'the agentic E2E section'
  contains_i "AC-030-05-01" "$TESTING" '(standard|the standard)[^.]{0,160}(TS|Node|React Native)|TypeScript[/ ]Node[^.]{0,80}standard' 'statement that it is the standard for TS/Node and React Native child repos'
  contains "AC-030-05-01" "$TESTING" 'skills/e2e-testing/SKILL\.md' 'pointer to skills/e2e-testing/SKILL.md'
  contains "AC-030-05-01" "$TESTING" 'Playwright' 'Playwright guidance preserved for repos not adopting e2e'
}

# AC-030-05-02 — AGENTS.md Reading the Standards line added
s_030_05_02() {
  # mktemp scratch, consistent with the rest of the suite's temp usage
  local t; t="$(mktemp)"
  awk '/^## Reading the Standards/{f=1} f && /^## / && $0 !~ /Reading the Standards/{exit} f' "$AGENTS_MD" > "$t" || true
  contains "AC-030-05-02" "$t" 'skills/e2e-testing/SKILL\.md' 'the e2e-testing skill line inside Reading the Standards'
  contains_i "AC-030-05-02" "$t" 'before writing or running E2E tests' 'the before-writing-or-running trigger'
  contains_i "AC-030-05-02" "$t" 'TS/Node' 'TS/Node child repo wording'
  contains_i "AC-030-05-02" "$t" 'RN|React Native' 'RN child repo wording'
  rm -f "$t"
}

# AC-030-05-03 — No literal model ids added to docs (diff from pre-task state,
# per the scenario's first alternative; HEAD is the pre-task state while the
# spec is uncommitted)
s_030_05_03() {
  local added
  added="$(git diff -U0 HEAD -- "$TESTING" "$AGENTS_MD" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
  if printf '%s' "$added" | grep -qiE "$ID_PATTERNS"; then
    fail "AC-030-05-03: literal model/provider id patterns were ADDED by this task"
  else
    pass "AC-030-05-03: no literal model/provider ids added in the diff"
  fi
  # belt-and-braces second alternative from the scenario: direct file scan
  not_contains_i "AC-030-05-03" "$TESTING" "$ID_PATTERNS" 'literal model/provider id patterns in docs/TESTING.md'
  not_contains_i "AC-030-05-03" "$AGENTS_MD" "$ID_PATTERNS" 'literal model/provider id patterns in AGENTS.md'
}

# unit — the new TESTING.md section still keeps the pre-existing E2E section
u_030_05_preserves_existing_sections() {
  contains "AC-030-05/u" "$TESTING" '^## E2E Tests' 'the pre-existing E2E Tests heading'
  contains "AC-030-05/u" "$TESTING" 'Maestro' 'the pre-existing React Native (Maestro) guidance'
}

main_dispatch "030_05" "${1:-all}"
finish "AC-030-05"
