#!/bin/bash
# check-code-principles-blame.sh — Scratch-repo blame-scoping tests for
# check-code-principles.sh (spec 011). Proves the observable -BaseRef behavior
# from the 20-acceptance scenarios with real throwaway scratch git repos:
# pre-existing debt in a touched file WARNs (exit 0), diff-introduced
# violations FAIL (exit 1), judgment gates stay warn-only under the default
# blocking set, and the blocking set is configurable.
#
# Scenario traceability (the AC-011-01 / AC-011-02 / AC-011-03 IDs below are
# the tests for the specs/011-design-gate-blame-scoping 20-acceptance files):
#   AC-011-01-01  -BaseRef accepted, blame scoping applied, no unknown-option exit 2
#   AC-011-01-02  unknown -X option still exits 2 with "Unknown option"
#   AC-011-01-03  pre-existing finding in touched file -> WARN, exit 0
#   AC-011-01-04  diff-introduced finding -> FAIL, exit 1
#   AC-011-01-05  overlap tested against the whole method span -> FAIL, exit 1
#   AC-011-01-06  without -BaseRef the gate categories/severities are unchanged
#   AC-011-01-07  unresolvable ref / non-git tree -> error to stderr, exit 2
#   AC-011-01-08  files with no diff overlap are not evaluated
#   AC-011-01-09  a file added entirely by the diff is fully diff-introduced
#   AC-011-02-01  pre-existing bad class touched by one line -> exit 0, WARN
#   AC-011-02-02  diff-introduced violation -> exit 1, FAIL
#   AC-011-02-03  violation in a brand-new file -> exit 1
#   AC-011-02-04  diff-introduced judgment-gate finding -> WARN, exit 0
#   AC-011-02-05  legacy invocation without -BaseRef keeps pre-011 behavior
#   AC-011-02-06  the blame-scoping tests run in self-ci
#   AC-011-03-01  default blocking set documented in the script header
#   AC-011-03-02  judgment gates warn-only even when diff-introduced
#   AC-011-03-03  blocking set configurable via --blocking / env var
#   AC-011-03-04  unknown gate name in override -> exit 2
#   AC-011-03-05  property-tests presence gate is not blame-scoped
#   AC-011-03-06  --warn-as-error promotes the new blame WARNs to failures
#   AC-011-03-07  no naming or test-delta gates are added
#   AC-011-03-08  blocking set + severity mapping documented in the skill
#
# Usage:
#   bash scripts/tests/check-code-principles-blame.sh
# Exit codes:
#   0 — every case passes
#   1 — at least one case failed
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/check-code-principles.sh"
CI="$ROOT/.github/workflows/self-ci.yml"
SKILL="$ROOT/skills/check-principles/SKILL.md"

PASS=0
FAIL_COUNT=0
RUN_RC=0

ok() { PASS=$((PASS + 1)); echo "PASS $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo "FAIL $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out"
ERR="$TMP/err"

# run_check DIR [args...] — run the check script in DIR, capture stdout/stderr/rc
run_check() {
  local dir="$1"
  shift
  if ( cd "$dir" && bash "$SCRIPT" "$@" >"$OUT" 2>"$ERR" ); then
    RUN_RC=0
  else
    RUN_RC=$?
  fi
}

init_repo() { git -C "$1" init -q; }

commit_all() { # commit_all DIR MSG
  git -C "$1" add -A
  git -C "$1" -c user.name=blame-test -c user.email=blame-test@example.invalid commit -qm "$2"
}

head_sha() { git -C "$1" rev-parse HEAD; }

# A method with cyclomatic complexity 7 (>6) — the violation shape used by
# every fixture. Appended inside an already-open class body.
write_complex_method() { # write_complex_method FILE
  cat >> "$1" <<'EOF'
  int complex(int a, int b, int c, int d, int e) {
    int r = 0;
    if (a > 1) r++;
    if (b > 1) r++;
    if (c > 1) r++;
    if (d > 1) r++;
    if (e > 1) r++;
    if (a + b > 2) r++;
    return r;
  }
EOF
}

# ── Fixture r1: legacy complexity violation, one-line touch outside the span ─
r1="$TMP/r1"; mkdir -p "$r1/src"; init_repo "$r1"
cat > "$r1/src/Legacy.java" <<'EOF'
class Legacy {
  int simple(int a, int b) {
    return a + b;
  }

  int complex(int a, int b, int c, int d, int e) {
    int r = 0;
    if (a > 1) r++;
    if (b > 1) r++;
    if (c > 1) r++;
    if (d > 1) r++;
    if (e > 1) r++;
    if (a + b > 2) r++;
    return r;
  }
}
EOF
commit_all "$r1" base
R1_BASE=$(head_sha "$r1")
printf '// one-line touch\n' >> "$r1/src/Legacy.java"

echo "== AC-011-01 / AC-011-02 pre-existing vs diff-introduced =="

run_check "$r1" -BaseRef "$R1_BASE"
if [ "$RUN_RC" -eq 0 ] && ! grep -q "Unknown option" "$ERR" \
   && grep -q "WARN" "$OUT" && grep -q "Cyclomatic complexity" "$OUT" \
   && ! grep -qE 'FAIL.*Cyclomatic complexity' "$OUT"; then
  ok "AC-011-01-01 / AC-011-01-03 / AC-011-02-01 -BaseRef accepted; pre-existing complexity in touched file reported WARN, exit 0"
else
  bad "AC-011-01-01 / AC-011-01-03 / AC-011-02-01 pre-existing complexity in touched file -> WARN, exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-01-06 / AC-011-02-05 legacy invocation (no -BaseRef) =="

run_check "$r1"
if [ "$RUN_RC" -eq 1 ] && grep -q "FAIL" "$OUT" && grep -q "Cyclomatic complexity" "$OUT"; then
  ok "AC-011-01-06 / AC-011-02-05 without -BaseRef: full-tree classification keeps pre-011 severity (complexity FAIL, exit 1)"
else
  bad "AC-011-01-06 / AC-011-02-05 without -BaseRef: complexity FAIL, exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-03-06 --warn-as-error promotes blame WARNs =="

run_check "$r1" -BaseRef "$R1_BASE" --warn-as-error
if [ "$RUN_RC" -eq 1 ]; then
  ok "AC-011-03-06 -BaseRef + --warn-as-error promotes the pre-existing WARN to a failure (exit 1)"
else
  bad "AC-011-03-06 -BaseRef + --warn-as-error -> exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-01-04 / AC-011-02-02 diff-introduced complexity =="

r2="$TMP/r2"; mkdir -p "$r2/src"; init_repo "$r2"
cat > "$r2/src/Clean.java" <<'EOF'
class Clean {
  int simple(int a, int b) {
    return a + b;
  }
}
EOF
commit_all "$r2" base
R2_BASE=$(head_sha "$r2")
cat > "$r2/src/Clean.java" <<'EOF'
class Clean {
  int simple(int a, int b) {
    return a + b;
  }

EOF
write_complex_method "$r2/src/Clean.java"
printf '}\n' >> "$r2/src/Clean.java"

run_check "$r2" -BaseRef "$R2_BASE"
if [ "$RUN_RC" -eq 1 ] && grep -q "FAIL" "$OUT" && grep -q "Cyclomatic complexity" "$OUT"; then
  ok "AC-011-01-04 / AC-011-02-02 diff-introduced complexity -> FAIL, exit 1"
else
  bad "AC-011-01-04 / AC-011-02-02 diff-introduced complexity -> FAIL, exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-01-05 overlap tested against the whole method span =="

r3="$TMP/r3"; mkdir -p "$r3/src"; init_repo "$r3"
cat > "$r3/src/Legacy.java" <<'EOF'
// legacy
class Legacy {
  int simple(int a, int b) {
    return a + b;
  }

  // padding
  // padding
  // padding
  int complex(int a, int b, int c, int d, int e) {
    int r = 0;
    if (a > 1) r++;
    if (b > 1) r++;
    if (c > 1) r++;
    if (d > 1) r++;
    if (e > 1) r++;
    if (a + b > 2) r++;
    // padding
    // padding
    // padding
    // padding
    // padding
    // padding
    // padding
    return r;
    // padding
    // padding
  }
}
EOF
commit_all "$r3" base
R3_BASE=$(head_sha "$r3")
# edit a line inside the legacy method's span (line 25)
sed -i '25s/return r;/return r + 1;/' "$r3/src/Legacy.java"
if grep -q 'return r + 1;' "$r3/src/Legacy.java"; then
  run_check "$r3" -BaseRef "$R3_BASE"
  if [ "$RUN_RC" -eq 1 ] && grep -q "FAIL" "$OUT" && grep -q "Cyclomatic complexity" "$OUT"; then
    ok "AC-011-01-05 edit inside the legacy method span -> diff-introduced FAIL, exit 1"
  else
    bad "AC-011-01-05 edit inside the legacy method span -> FAIL, exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
  fi
else
  bad "AC-011-01-05 fixture setup: line 25 edit did not apply (span fixture broken)"
fi

echo "== AC-011-01-08 files with no diff overlap are not evaluated =="

r4="$TMP/r4"; mkdir -p "$r4/src"; init_repo "$r4"
cat > "$r4/src/A.java" <<'EOF'
class A {
  int simple(int a, int b) {
    return a + b;
  }
}
EOF
cat > "$r4/src/B.java" <<'EOF'
class B {

EOF
write_complex_method "$r4/src/B.java"
printf '}\n' >> "$r4/src/B.java"
commit_all "$r4" base
R4_BASE=$(head_sha "$r4")
printf '// touch A only\n' >> "$r4/src/A.java"

run_check "$r4" -BaseRef "$R4_BASE"
if [ "$RUN_RC" -eq 0 ] && ! grep -q "B.java" "$OUT"; then
  ok "AC-011-01-08 untouched file B's legacy finding is not evaluated (no B.java in output), exit 0"
else
  bad "AC-011-01-08 untouched file B not reported (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-01-09 / AC-011-02-03 brand-new file is fully diff-introduced =="

r5="$TMP/r5"; mkdir -p "$r5/src"; init_repo "$r5"
cat > "$r5/src/Old.java" <<'EOF'
class Old {
  int simple(int a, int b) {
    return a + b;
  }
}
EOF
commit_all "$r5" base
R5_BASE=$(head_sha "$r5")
cat > "$r5/src/New.java" <<'EOF'
class New {

EOF
write_complex_method "$r5/src/New.java"
printf '}\n' >> "$r5/src/New.java"

run_check "$r5" -BaseRef "$R5_BASE"
if [ "$RUN_RC" -eq 1 ] && grep -q "FAIL" "$OUT" && grep -q "New.java" "$OUT"; then
  ok "AC-011-01-09 / AC-011-02-03 violation in a brand-new file -> FAIL, exit 1"
else
  bad "AC-011-01-09 / AC-011-02-03 brand-new file violation -> FAIL, exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-01-07 tooling failures =="

run_check "$r1" -BaseRef not-a-real-ref-9x
if [ "$RUN_RC" -eq 2 ] && [ -s "$ERR" ]; then
  ok "AC-011-01-07 unresolvable base ref -> stderr error, exit 2"
else
  bad "AC-011-01-07 unresolvable base ref -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

mkdir -p "$TMP/nogit/src"
cat > "$TMP/nogit/src/NoGit.java" <<'EOF'
class NoGit {
  int simple(int a, int b) {
    return a + b;
  }
}
EOF
run_check "$TMP/nogit" -BaseRef HEAD
if [ "$RUN_RC" -eq 2 ] && [ -s "$ERR" ]; then
  ok "AC-011-01-07 non-git directory -> stderr error, exit 2"
else
  bad "AC-011-01-07 non-git directory -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

echo "== AC-011-01-02 unknown option =="

run_check "$TMP/nogit" -Zzz
if [ "$RUN_RC" -eq 2 ] && grep -q "Unknown option" "$ERR"; then
  ok "AC-011-01-02 unknown -Zzz option -> 'Unknown option' to stderr, exit 2"
else
  bad "AC-011-01-02 unknown option -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

echo "== AC-011-02-04 / AC-011-03-02 judgment gate warn-only =="

r6="$TMP/r6"; mkdir -p "$r6/src/domain"; init_repo "$r6"
cat > "$r6/src/domain/Base.java" <<'EOF'
package com.example.domain;

public class Base {
}
EOF
commit_all "$r6" base
R6_BASE=$(head_sha "$r6")
cat > "$r6/src/domain/Thing.java" <<'EOF'
package com.example.domain;

import com.example.infrastructure.Repo;

public class Thing {
}
EOF

run_check "$r6" -BaseRef "$R6_BASE"
if [ "$RUN_RC" -eq 0 ] && grep -q "DIP" "$OUT" && grep -q "WARN" "$OUT" \
   && ! grep -qE 'FAIL.*DIP' "$OUT"; then
  ok "AC-011-02-04 / AC-011-03-02 diff-introduced DIP (judgment gate) -> WARN, no FAIL, exit 0"
else
  bad "AC-011-02-04 / AC-011-03-02 diff-introduced DIP -> WARN, no FAIL, exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-03-03 configurable blocking set =="

r7="$TMP/r7"; mkdir -p "$r7/src"; init_repo "$r7"
cat > "$r7/src/Seed.java" <<'EOF'
class Seed {
  int simple(int a, int b) {
    return a + b;
  }
}
EOF
commit_all "$r7" base
R7_BASE=$(head_sha "$r7")
# two brand-new files with an identical 4-line block -> diff-introduced DRY
for f in Aaa.java Zzz.java; do
  name="${f%.java}"
  cat > "$r7/src/$f" <<EOF
class $name {
  void work() {
    int a = 1;
    int b = 2;
    int c = 3;
    int d = 4;
  }
}
EOF
done

run_check "$r7" -BaseRef "$R7_BASE"
if [ "$RUN_RC" -eq 0 ] && grep -q "duplication" "$OUT" && grep -q "WARN" "$OUT" \
   && ! grep -qE 'FAIL.*duplication' "$OUT"; then
  ok "AC-011-03-03 diff-introduced DRY stays WARN under the default blocking set (exit 0)"
else
  bad "AC-011-03-03 DRY default set -> WARN, exit 0 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

run_check "$r7" -BaseRef "$R7_BASE" --blocking complexity,property-tests,dry
if [ "$RUN_RC" -eq 1 ] && grep -q "FAIL" "$OUT" && grep -q "duplication" "$OUT"; then
  ok "AC-011-03-03 --blocking complexity,property-tests,dry promotes diff-introduced DRY to FAIL, exit 1"
else
  bad "AC-011-03-03 --blocking ...dry -> FAIL, exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

if ( cd "$r7" && PRINCIPLES_BLOCKING_GATES=complexity,property-tests,dry bash "$SCRIPT" -BaseRef "$R7_BASE" >"$OUT" 2>"$ERR" ); then
  RUN_RC=0
else
  RUN_RC=$?
fi
if [ "$RUN_RC" -eq 1 ] && grep -q "FAIL" "$OUT" && grep -q "duplication" "$OUT"; then
  ok "AC-011-03-03 PRINCIPLES_BLOCKING_GATES env var equivalent -> FAIL, exit 1"
else
  bad "AC-011-03-03 PRINCIPLES_BLOCKING_GATES env var -> FAIL, exit 1 (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-03-04 unknown gate in override =="

run_check "$r1" --blocking bogus
if [ "$RUN_RC" -eq 2 ] && grep -q "unknown gate name in blocking set: 'bogus'" "$ERR"; then
  ok "AC-011-03-04 --blocking bogus -> stderr names the unknown gate, exit 2"
else
  bad "AC-011-03-04 --blocking bogus -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

if ( cd "$r1" && PRINCIPLES_BLOCKING_GATES=bogus bash "$SCRIPT" >"$OUT" 2>"$ERR" ); then
  RUN_RC=0
else
  RUN_RC=$?
fi
if [ "$RUN_RC" -eq 2 ] && grep -q "unknown gate name in blocking set: 'bogus'" "$ERR"; then
  ok "AC-011-03-04 PRINCIPLES_BLOCKING_GATES=bogus -> exit 2"
else
  bad "AC-011-03-04 PRINCIPLES_BLOCKING_GATES=bogus -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

run_check "$r1" --blocking ""
if [ "$RUN_RC" -eq 2 ] && [ -s "$ERR" ]; then
  ok "AC-011-03-04 empty --blocking value -> stderr error, exit 2"
else
  bad "AC-011-03-04 empty --blocking value -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

echo "== AC-011-03-07 no naming / test-delta gates =="

run_check "$r1" --blocking naming,complexity
if [ "$RUN_RC" -eq 2 ] && grep -q "unknown gate name in blocking set: 'naming'" "$ERR" \
   && grep -q "complexity, dry, yagni, solid, component-per-file, property-tests" "$ERR"; then
  ok "AC-011-03-07 'naming' is not a gate (unknown, exit 2); valid list names only real gates"
else
  bad "AC-011-03-07 --blocking naming -> exit 2 naming the gate (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

run_check "$r1" --blocking test-delta
if [ "$RUN_RC" -eq 2 ] && grep -q "unknown gate name in blocking set: 'test-delta'" "$ERR"; then
  ok "AC-011-03-07 'test-delta' is not a gate (unknown, exit 2)"
else
  bad "AC-011-03-07 --blocking test-delta -> exit 2 (rc=$RUN_RC, err=$(tr '\n' ' ' < "$ERR"))"
fi

echo "== AC-011-03-05 property-tests is a presence gate, never blame-scoped =="

r8="$TMP/r8"; mkdir -p "$r8/src"; init_repo "$r8"
cat > "$r8/AGENTS_PROJECT.md" <<'EOF'
# Project

Conformance tier: production
EOF
cat > "$r8/src/App.java" <<'EOF'
class App {
  int simple(int a, int b) {
    return a + b;
  }
}
EOF
commit_all "$r8" base
R8_BASE=$(head_sha "$r8")

run_check "$r8" -BaseRef "$R8_BASE"
if [ "$RUN_RC" -eq 1 ] && grep -q "Property tests" "$OUT" && grep -q "FAIL" "$OUT"; then
  ok "AC-011-03-05 property-tests FAILs at production tier with -BaseRef (presence check, not blame-scoped)"
else
  bad "AC-011-03-05 property-tests FAIL with -BaseRef (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

run_check "$r8"
if [ "$RUN_RC" -eq 1 ] && grep -q "Property tests" "$OUT" && grep -q "FAIL" "$OUT"; then
  ok "AC-011-03-05 property-tests FAILs identically without -BaseRef (classification unchanged)"
else
  bad "AC-011-03-05 property-tests FAIL without -BaseRef (rc=$RUN_RC, out=$(tr '\n' ' ' < "$OUT"))"
fi

echo "== AC-011-03-01 header documentation =="

if grep -q "Blocking set" "$SCRIPT" \
   && grep -q "Default blocking set: complexity,property-tests" "$SCRIPT" \
   && grep -q "warn-only" "$SCRIPT" \
   && grep -q -- "-BaseRef" "$SCRIPT"; then
  ok "AC-011-03-01 script header documents the blocking set, default complexity,property-tests, warn-only gates, -BaseRef"
else
  bad "AC-011-03-01 script header documents blocking set + default + warn-only + -BaseRef"
fi

echo "== AC-011-03-08 skill documentation =="

if grep -q -- "-BaseRef" "$SKILL" \
   && grep -q -- "--blocking" "$SKILL" \
   && grep -q "complexity,property-tests" "$SKILL" \
   && grep -qi "warn-only" "$SKILL"; then
  ok "AC-011-03-08 SKILL.md documents -BaseRef invocation, --blocking, default blocking set, warn-only judgment gates"
else
  bad "AC-011-03-08 SKILL.md documents -BaseRef / --blocking / default set / warn-only"
fi

echo "== AC-011-02-06 self-ci wiring =="

if [ -f "$CI" ] && grep -q "scripts/tests/check-code-principles-blame.sh" "$CI"; then
  ok "AC-011-02-06 self-ci.yml runs the blame-scoping test script"
else
  bad "AC-011-02-06 self-ci.yml must run scripts/tests/check-code-principles-blame.sh"
fi

echo ""
echo "blame tests: $PASS passed, $FAIL_COUNT failed"
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "check-code-principles-blame: $FAIL_COUNT case(s) failed!"
  exit 1
fi
echo "check-code-principles-blame: all cases pass."
