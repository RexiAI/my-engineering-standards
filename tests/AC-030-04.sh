#!/usr/bin/env bash
# tests/AC-030-04.sh — T4: agents/e2e-runner.md
# Scenarios from specs/030-e2e-skill-agent/20-acceptance/AC-030-04.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"
AG="agents/e2e-runner.md"

# AC-030-04-01 — Frontmatter has required fields
s_030_04_01() {
  require "AC-030-04-01" "$AG" || return 0
  # || true: an absent field makes fm_field's grep exit non-zero; under
  # set -e that would abort the whole file instead of reporting FAIL here
  # (precedent: tests/AC-030-01.sh).
  local d; d="$(fm_field "$AG" description 2>/dev/null || true)"
  if [ -n "$d" ]; then pass "AC-030-04-01: description present and non-empty"; else fail "AC-030-04-01: description missing or empty"; fi
  if [ "$(fm_field "$AG" mode)" = "subagent" ]; then pass "AC-030-04-01: mode is subagent"; else fail "AC-030-04-01: mode is not subagent"; fi
  if fm_of "$AG" | grep -qE '^permission:'; then pass "AC-030-04-01: permission block present"; else fail "AC-030-04-01: permission block missing"; fi
}

# AC-030-04-02 — Permission denies git push and git commit
s_030_04_02() {
  require "AC-030-04-02" "$AG" || return 0
  contains "AC-030-04-02" "$AG" '"git push\*": *deny' 'deny rule for git push*'
  contains "AC-030-04-02" "$AG" '"git commit\*": *deny' 'deny rule for git commit*'
}

# AC-030-04-03 — Permission denies edits outside allowed paths; .e2e/ read-only
s_030_04_03() {
  require "AC-030-04-03" "$AG" || return 0
  contains "AC-030-04-03" "$AG" '"tests/[^"]*": *allow' 'allow rule for tests/'
  contains "AC-030-04-03" "$AG" '"e2e\.config\.ts": *allow' 'allow rule for e2e.config.ts'
  contains "AC-030-04-03" "$AG" '"\*": *deny' 'catch-all deny outside allowed paths'
  if fm_of "$AG" | grep -E ': *allow' | grep -qE '"[^"]*\.e2e/'; then
    fail "AC-030-04-03: .e2e/ must be read-only but an allow rule covers it"
  else
    pass "AC-030-04-03: .e2e/ is not writable (read-only)"
  fi
  contains "AC-030-04-03" "$AG" '"\.e2e/[^"]*": *deny' 'explicit deny rule for .e2e/'
}

# AC-030-04-04 — No model key in frontmatter
s_030_04_04() {
  require "AC-030-04-04" "$AG" || return 0
  if fm_of "$AG" | grep -qE '^model:'; then fail "AC-030-04-04: frontmatter must not carry a model: key"; else pass "AC-030-04-04: no model: key in frontmatter"; fi
}

# AC-030-04-05 — Body has required sections
s_030_04_05() {
  require "AC-030-04-05" "$AG" || return 0
  # mktemp, not a fixed /tmp path: no cross-run collision (precedent:
  # u_030_07_no_secrets in this suite).
  local b; b="$(mktemp)"
  body_of "$AG" > "$b" || true
  contains_i "AC-030-04-05" "$b" '^#{1,6}.*role|^#{1,6}.*purpose' 'Role/Purpose section'
  contains_i "AC-030-04-05" "$b" '^#{1,6}.*(one rule|primary invariant)' 'the one rule / primary invariant section'
  contains_i "AC-030-04-05" "$b" 'author|maintain' 'author/maintainer duty steps'
  contains_i "AC-030-04-05" "$b" 'bug.?bash' 'bug-bash mode duty steps'
  contains_i "AC-030-04-05" "$b" '^#{1,6}.*stopping condition' 'stopping conditions section'
  contains_i "AC-030-04-05" "$b" 'output summary' 'output summary contract'
  rm -f "$b"
}

# AC-030-04-06 — Workflow vs Agent choice justified
s_030_04_06() {
  contains_i "AC-030-04-06" "$AG" 'workflow' 'workflow-vs-agent discussion'
  contains_i "AC-030-04-06" "$AG" 'cannot be (fully )?(pre-?defined|pre-?planned)|not a fixed (script|workflow)|only when steps' 'justification that steps cannot be predefined'
  contains_i "AC-030-04-06" "$AG" 'simplest|simplest thing' 'simplest-thing principle documented'
}

# AC-030-04-07 — Ground truth and stopping conditions
s_030_04_07() {
  contains "AC-030-04-07" "$AG" '\.e2e/failures/' 'reads .e2e/failures/ after every run'
  contains "AC-030-04-07" "$AG" 'report\.json' 'reads report.json after every run'
  contains_i "AC-030-04-07" "$AG" 'never (call|assume|declare)|must not assume' 'never assume green without checking output'
  contains_i "AC-030-04-07" "$AG" '(3|three)[^.]*fix rounds' 'max 3 fix rounds per failing test file'
  contains_i "AC-030-04-07" "$AG" 'budget[s]?[^.]*inner bound|inner bound' 'framework budgets as the inner bound'
  contains_i "AC-030-04-07" "$AG" 'until green[^.]*forbidden|forbidden[^.]*until green' 'the forbidden re-run phrasing is named'
  contains_i "AC-030-04-07" "$AG" 'counted attempt' 'every re-run is a counted attempt'
}

# AC-030-04-08 — Bug-bash mode bounds and confirmation gate + hygiene
s_030_04_08() {
  contains_i "AC-030-04-08" "$AG" 'persona[^.]*cap|cap[^.]*persona' 'persona count cap stated'
  contains "AC-030-04-08" "$AG" '[-][-]max-steps' 'per-persona --max-steps bound'
  contains "AC-030-04-08" "$AG" '[-][-]timeout' 'per-persona --timeout bound'
  contains "AC-030-04-08" "$AG" 'ASSERTION_FAILED' 'ASSERTION_FAILED confirmation gate'
  contains_i "AC-030-04-08" "$AG" 'explore[^.]*not[^.]*regression' 'explore findings are not regressions'
  not_contains_i "AC-030-04-08" "$AG" "$ID_PATTERNS" 'literal model/provider id patterns'
  not_contains_i "AC-030-04-08" "$AG" 'password[[:space:]]*[:=]|token[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_./+-]{12,}' 'credential literals'
  no_forbidden_phrase "AC-030-04-08" "$AG" 'the forbidden phrasing as an instruction'
}

# unit — poka-yoke tool guidance present (absolute paths, single-file runs)
u_030_04_pokayoke() {
  contains_i "AC-030-04/u" "$AG" 'absolute path' 'absolute-path guidance'
  contains_i "AC-030-04/u" "$AG" 'single.file|one file at a time|npx e2e run' 'single-file run guidance'
}

# unit — transparency: plan and evidence must be surfaced
u_030_04_transparency() {
  contains_i "AC-030-04/u" "$AG" 'plan' 'plan surfaced'
  contains_i "AC-030-04/u" "$AG" 'evidence' 'per-run evidence surfaced'
}

# unit — no 'model:' key anywhere at line start in the whole file (ADR 0003 hygiene)
u_030_04_no_model_line() {
  not_contains "AC-030-04/u" "$AG" '^model:' 'any top-level model: line'
}

main_dispatch "030_04" "${1:-all}"
finish "AC-030-04"
