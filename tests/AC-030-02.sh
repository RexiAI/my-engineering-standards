#!/usr/bin/env bash
# tests/AC-030-02.sh — T2: skills/e2e-testing/references/*.md progressive disclosure
# Scenarios from specs/030-e2e-skill-agent/20-acceptance/AC-030-02.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"
SK="skills/e2e-testing/SKILL.md"
REF="skills/e2e-testing/references"
SETUP="$REF/setup.md"; WT="$REF/writing-tests.md"; RD="$REF/running-debugging.md"
BB="$REF/bug-bash.md"; CI="$REF/ci.md"; RN="$REF/mobile-rn.md"
ALL_REF_FILES=(setup.md writing-tests.md running-debugging.md bug-bash.md ci.md mobile-rn.md)

# AC-030-02-01 — All six reference files exist
s_030_02_01() {
  if [ ! -d "$REF" ]; then fail "AC-030-02-01: $REF directory missing"; return 0; fi
  pass "AC-030-02-01: $REF exists"
  local f
  for f in "${ALL_REF_FILES[@]}"; do exists "AC-030-02-01" "$REF/$f"; done
}

# AC-030-02-02 — Each reference file is referenced from SKILL.md
s_030_02_02() {
  local f
  for f in "${ALL_REF_FILES[@]}"; do contains "AC-030-02-02" "$SK" "references/${f}" "SKILL.md cites references/$f"; done
}

# AC-030-02-03 — No nested reference chains (no markdown links between reference files)
s_030_02_03() {
  local f other
  for f in "${ALL_REF_FILES[@]}"; do
    require "AC-030-02-03" "$REF/$f" || continue
    for other in "${ALL_REF_FILES[@]}"; do
      [ "$other" = "$f" ] && continue
      not_contains "AC-030-02-03" "$REF/$f" "\]\((\.\./)?([a-zA-Z0-9._-]+/)*${other}" "no relative link to reference file $other"
    done
    not_contains "AC-030-02-03" "$REF/$f" '\]\([^)]*references/' "no relative link through references/"
  done
}

# AC-030-02-04 — setup.md content coverage
s_030_02_04() {
  contains "AC-030-02-04" "$SETUP" '24\.8' 'Node 24.8 requirement'
  contains "AC-030-02-04" "$SETUP" '22\.22\.3' 'Node 22.22.3 requirement'
  contains_i "AC-030-02-04" "$SETUP" 'environment variable' 'model connectivity via environment variables'
  contains "AC-030-02-04" "$SETUP" 'E2E_TELEMETRY_DISABLED' 'telemetry opt-out'
  not_contains_i "AC-030-02-04" "$SETUP" "$ID_PATTERNS" 'literal model/provider id patterns'
}

# AC-030-02-05 — writing-tests.md content coverage
s_030_02_05() {
  contains_i "AC-030-02-05" "$WT" 'golden rule' 'the act+expect golden rule'
  contains_i "AC-030-02-05" "$WT" 'judge[^.]*does not see|judge[^.]*never sees|judge[^.]*isolat' 'actor/judge isolation (judge does not see actor steps)'
  contains "AC-030-02-05" "$WT" 'waitFor' 'waitFor coverage'
  contains "AC-030-02-05" "$WT" 'extract' 'extract coverage'
  contains "AC-030-02-05" "$WT" 'Secret' 'the opaque Secret pattern'
  contains_i "AC-030-02-05" "$WT" 'session' 'sessions coverage'
  not_contains_i "AC-030-02-05" "$WT" "$ID_PATTERNS" 'literal model/provider id patterns'
}

# AC-030-02-06 — running-debugging.md content coverage
s_030_02_06() {
  contains "AC-030-02-06" "$RD" 'npx e2e run tests/' 'single-file runs (npx e2e run tests/<file>)'
  contains "AC-030-02-06" "$RD" '\.e2e/failures/' 'the .e2e/failures/ directory'
  local i miss=""
  for i in 1 2 3 4 130; do grep -qE "\| *${i} *\|" "$RD" 2>/dev/null || miss="$miss $i"; done
  if [ -z "$miss" ]; then pass "AC-030-02-06: exit codes 1, 2, 3, 4, 130 all listed"; else fail "AC-030-02-06: exit codes missing:$miss"; fi
  contains "AC-030-02-06" "$RD" 'read-write' 'cache mode read-write'
  contains "AC-030-02-06" "$RD" 'read-only' 'cache mode read-only'
  contains "AC-030-02-06" "$RD" 'cache[^.]*off|`off`' 'cache mode off'
  contains "AC-030-02-06" "$RD" '[-][-]strict-cache' 'the --strict-cache flag'
  contains_i "AC-030-02-06" "$RD" 'never sleep|no sleep|sleep[^.]*forbidden' 'the never-sleep rule'
  no_forbidden_phrase "AC-030-02-06" "$RD"
}

# AC-030-02-07 — bug-bash.md content coverage
s_030_02_07() {
  contains_i "AC-030-02-07" "$BB" 'persona[^.]*cap|cap[^.]*persona|bounded parallelism' 'the persona count cap (bounded parallelism)'
  contains "AC-030-02-07" "$BB" '[-][-]max-steps' 'the --max-steps per-persona bound'
  contains "AC-030-02-07" "$BB" '[-][-]timeout' 'the --timeout per-persona bound'
  contains "AC-030-02-07" "$BB" 'ASSERTION_FAILED' 'the ASSERTION_FAILED confirmation gate'
  contains_i "AC-030-02-07" "$BB" 'explore[^.]*not[^.]*regression' 'explore findings are not regressions'
  not_contains_i "AC-030-02-07" "$BB" "$ID_PATTERNS" 'literal model/provider id patterns'
}

# AC-030-02-08 — ci.md and mobile-rn.md content coverage
s_030_02_08() {
  contains_i "AC-030-02-08" "$CI" 'workers[^.]*cores/2[^.]*1 in CI|cores/2' 'workers cores/2 local, 1 in CI'
  contains_i "AC-030-02-08" "$CI" 'retr[^.]*0[^.]*1' 'retries 0 local, 1 CI'
  contains "AC-030-02-08" "$CI" 'test\.only' 'test.only rejection'
  contains "AC-030-02-08" "$CI" 'ONLY_IN_CI' 'the ONLY_IN_CI marker'
  contains "AC-030-02-08" "$CI" 'read-only' 'replay cache read-only in CI'
  contains "AC-030-02-08" "$CI" '[-][-]strict-cache' '--strict-cache in CI'
  contains "AC-030-02-08" "$CI" '\.e2e/report\.json' 'the .e2e/report.json artifact'
  contains "AC-030-02-08" "$CI" 'junit\.xml' 'the junit.xml artifact'
  contains "AC-030-02-08" "$RN" '@e2e-dev/mobile' 'the @e2e-dev/mobile package'
  contains_i "AC-030-02-08" "$RN" 'iOS[^.]*simulator|simulator[^.]*iOS' 'iOS simulators'
  contains_i "AC-030-02-08" "$RN" 'Android[^.]*emulator|emulator[^.]*Android' 'Android emulators'
  local n; n="$(grep -cE '@e2e-dev/(kernel|eas)' "$RN" 2>/dev/null || true)"
  if [ "${n:-0}" -ge 1 ] && [ "${n:-0}" -le 1 ]; then
    pass "AC-030-02-08: kernel/eas mention is one line ($n)"
  else
    fail "AC-030-02-08: kernel/eas mention count $n — expected exactly one line"
  fi
  not_contains_i "AC-030-02-08" "$RN" "$ID_PATTERNS" 'literal model/provider id patterns in mobile-rn.md'
  not_contains_i "AC-030-02-08" "$CI" "$ID_PATTERNS" 'literal model/provider id patterns in ci.md'
}

# unit — every reference file is non-empty and titled
u_030_02_files_nonempty() {
  local f
  for f in "${ALL_REF_FILES[@]}"; do
    if [ -s "$REF/$f" ] && head -3 "$REF/$f" 2>/dev/null | grep -qE '^#'; then
      pass "unit T2: $f non-empty with a heading"
    else
      fail "unit T2: $f empty or headingless"
    fi
  done
}

# unit — no reference file carries secrets/tokens/credentials literals
u_030_02_no_secrets() {
  local f fp bad=""
  for f in "${ALL_REF_FILES[@]}"; do
    fp="$REF/$f"
    [ -f "$fp" ] || continue
    if grep -qiE '(api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_./+-]{12,}' "$fp"; then bad="$bad $fp"; fi
  done
  if [ -z "$bad" ]; then pass "unit T2: no credential literals in reference files"; else fail "unit T2: credential-shaped literal in:$bad"; fi
}

main_dispatch "030_02" "${1:-all}"
finish "AC-030-02"
