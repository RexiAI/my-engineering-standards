#!/usr/bin/env bash
# tests/AC-030-01.sh — T1: skills/e2e-testing/SKILL.md structure & content
# One function per scenario from specs/030-e2e-skill-agent/20-acceptance/AC-030-01.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"
SK="skills/e2e-testing/SKILL.md"

# AC-030-01-01 — Frontmatter exists with required fields
s_030_01_01() {
  local fm; fm="$(fm_of "$SK" 2>/dev/null || true)"
  if printf '%s\n' "$fm" | grep -qE '^name:'; then pass "AC-030-01-01: frontmatter has name field"; else fail "AC-030-01-01: frontmatter missing name field"; fi
  if printf '%s\n' "$fm" | grep -qE '^description:'; then pass "AC-030-01-01: frontmatter has description field"; else fail "AC-030-01-01: frontmatter missing description field"; fi
}

# AC-030-01-02 — Name matches directory
s_030_01_02() {
  local n; n="$(fm_field "$SK" name 2>/dev/null || true)"
  if [ "$n" = "e2e-testing" ]; then pass "AC-030-01-02: name is exactly e2e-testing"; else fail "AC-030-01-02: name is '$n', expected 'e2e-testing'"; fi
}

# AC-030-01-03 — Name format valid (^[a-z0-9]+(-[a-z0-9]+)*$, <=64 chars)
s_030_01_03() {
  local n; n="$(fm_field "$SK" name 2>/dev/null || true)"
  if printf '%s' "$n" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$' && [ "${#n}" -le 64 ]; then
    pass "AC-030-01-03: name '$n' matches regex and length <=64"
  else
    fail "AC-030-01-03: name '$n' invalid format or length ${#n}"
  fi
}

# AC-030-01-04 — Description non-empty and within limit (>=1, <=1024)
s_030_01_04() {
  local d; d="$(fm_field "$SK" description 2>/dev/null || true)"
  if [ "${#d}" -ge 1 ] && [ "${#d}" -le 1024 ]; then
    pass "AC-030-01-04: description length ${#d} within 1..1024"
  else
    fail "AC-030-01-04: description length ${#d} outside 1..1024"
  fi
}

# AC-030-01-05 — Body line count within limit (<=500)
s_030_01_05() {
  require "AC-030-01-05" "$SK" || return 0
  local n; n="$(body_of "$SK" | grep -c '' || true)"
  if [ "$n" -le 500 ]; then pass "AC-030-01-05: body has $n lines (<=500)"; else fail "AC-030-01-05: body has $n lines (>500)"; fi
}

# AC-030-01-06 — Required body sections present (case-insensitive headings)
s_030_01_06() {
  require "AC-030-01-06" "$SK" || return 0
  local sec
  for sec in 'when to use' 'invocation' 'what it does' 'what it is not' 'exit codes'; do
    if body_of "$SK" | grep -qiE "^#{1,6}[[:space:]].*${sec}"; then
      pass "AC-030-01-06: heading for '$sec' present"
    else
      fail "AC-030-01-06: heading for '$sec' missing"
    fi
  done
  return 0
}

# AC-030-01-07 — Version pin and pre-1.0 warning present
s_030_01_07() {
  contains "AC-030-01-07" "$SK" '0\.17\.0' 'the version pin 0.17.0'
  contains_i "AC-030-01-07" "$SK" 'pre-1\.0|API may change' 'a pre-1.0 instability warning'
}

# AC-030-01-08 — Telemetry opt-out mandated
s_030_01_08() {
  contains "AC-030-01-08" "$SK" 'E2E_TELEMETRY_DISABLED' 'the telemetry opt-out variable'
}

# AC-030-01-09 — Act+expect golden rule stated (an act must be followed by expect or agent.assert)
s_030_01_09() {
  contains_i "AC-030-01-09" "$SK" 'golden rule' 'the golden rule marker'
  contains_i "AC-030-01-09" "$SK" 'act[^.]*([Ee]xpect|agent\.assert)' 'act followed by expect/agent.assert'
}

# AC-030-01-10 — Opaque Secret path taught, inline credentials forbidden
s_030_01_10() {
  contains "AC-030-01-10" "$SK" 'credentials\.user' 'the opaque Secret credentials.user path'
  contains_i "AC-030-01-10" "$SK" 'never[^.]*credential|do not[^.]*credential|no inline[^.]*credential|forbid[^.]*credential' 'a statement forbidding inline/hardcoded credentials'
}

# AC-030-01-11 — No literal model or provider ids
s_030_01_11() {
  not_contains_i "AC-030-01-11" "$SK" "$ID_PATTERNS" 'literal model/provider id patterns'
}

# AC-030-01-12 — No forbidden phrasing
s_030_01_12() {
  no_forbidden_phrase "AC-030-01-12" "$SK"
}

# unit — file starts with frontmatter delimiter on line 1
u_030_01_frontmatter_opens_line1() {
  if [ -f "$SK" ] && [ "$(head -1 "$SK")" = "---" ]; then pass "unit T1: frontmatter opens with '---' on line 1"; else fail "unit T1: first line is not '---'"; fi
}

# unit — whole file (not just body) stays within the 500-line spec limit
u_030_01_total_lines() {
  require "unit T1" "$SK" || return 0
  local n; n="$(wc -l < "$SK")"
  if [ "$n" -le 500 ]; then pass "unit T1: total file $n lines (<=500)"; else fail "unit T1: total file $n lines (>500)"; fi
}

# unit — description carries both a what and a when (trigger guidance per docs/AGENTS_AND_SKILLS.md)
u_030_01_description_what_when() {
  local d; d="$(fm_field "$SK" description 2>/dev/null || true)"
  if printf '%s' "$d" | grep -qiE 'use when|use it when|trigger' && [ "${#d}" -gt 40 ]; then
    pass "unit T1: description states what + when-to-use trigger"
  else
    fail "unit T1: description lacks a when-to-use trigger clause"
  fi
}

main_dispatch "030_01" "${1:-all}"
finish "AC-030-01"
