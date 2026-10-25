#!/bin/bash
# check-code-principles.selftest.sh — Hermetic regression net for
# scripts/check-code-principles.sh: one deliberately-bad fixture per gate,
# asserting the gate fires with the right severity, plus clean/near-miss
# controls asserting it does not fire. Fixtures live in `mktemp -d` scratch
# (never inside the repo), cleaned up by a trap.
#
# Covers (scenario traceability: the AC-012-01-NN IDs below are the tests for
# the 20-acceptance scenarios in specs/012-gate-selftests-telemetry/):
#   AC-012-01-01  cyclomatic complexity >6 fires as a FAIL
#   AC-012-01-02  complexity of exactly 6 does not fire (negative control)
#   AC-012-01-03  KISS method-body-length and parameter-count fire as WARNs
#   AC-012-01-04  DRY duplicate block fires as a WARN; similar-but-different does not
#   AC-012-01-05  YAGNI single-implementation interface FAILs; empty body WARNs
#   AC-012-01-06  SOLID sub-checks fire with their severities (SRP/OCP/LSP/ISP WARN, DIP FAIL)
#   AC-012-01-07  property-test gate FAILs at production tier when missing, passes when present
#   AC-012-01-08  a clean tree passes the full run (no false positives)
#   AC-012-01-09  a missing --gates flag is reported loudly, not mis-run
#   AC-012-01-10  selftest passes only when every fixture and control asserts correctly
#
# Also covers spec 032's three new gates (see the group sections near the end):
#   AC-032-04-01..03 / AC-032-08-02,05  comments: commented-out code, WARN and FAIL
#   AC-032-05-01..03                    comments: comment restates the next line
#   AC-032-06-01..04                    comments: TODO/FIXME, dividers, attributions
#   AC-032-07-01..05                    comments: every allowlist category
#   AC-032-09-01..06                    naming: five advisory heuristics
#   AC-032-10-01..04                    null-discipline: return null / null argument
#
# Invokes the checker as `bash "$CHECKER"` (robust regardless of the +x bit),
# with SOURCE_DIR pointed at each fixture dir. Exits 0 only if every fixture
# and control assertion passes; otherwise prints the failing fixture name, the
# actual output, and the expected assertion, and exits 1.
#
# Usage:
#   bash scripts/check-code-principles.selftest.sh
# Exit codes:
#   0 — every fixture/control assertion passes
#   1 — at least one assertion failed, or the checker lacks --gates (spec 007)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check-code-principles.sh"

PASS_COUNT=0
FAIL_COUNT=0

ok() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}PASS${NC} $1"; }
bad() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}FAIL${NC} $1"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# run_capture OUT ERR cmd... — captures stdout/stderr, sets RUN_RC
run_capture() {
  local out="$1" err="$2"
  shift 2
  if "$@" >"$out" 2>"$err"; then RUN_RC=0; else RUN_RC=$?; fi
}

# assert_finding NAME GATES EXPECTED SEVERITY [--tier X] — runs the checker
# against $TMP/$NAME with --gates GATES (and optional --tier), asserts (a) the
# expected finding appears in stdout, (b) the exit code matches the severity:
# FAIL findings exit 1, WARN findings exit 0 by default and exit 1 under
# --warn-as-error (proving the severity is WARN, not FAIL).
assert_finding() {
  local name="$1" gates="$2" expected="$3" sev="$4"
  shift 4
  local out="$TMP/$name.out" tier_args=()
  [ "${1:-}" = "--tier" ] && { tier_args=(--tier "$2"); shift 2; }
  run_capture "$out" "$TMP/$name.err" bash "$CHECKER" --gates "$gates" "${tier_args[@]}" "$TMP/$name"
  local rc=$RUN_RC
  case "$sev" in
    fail)
      [ "$rc" -eq 1 ] || { bad "AC-012-01-10 $name: expected FAIL exit 1, got $rc"; show_out "$out"; return 1; }
      ;;
    warn)
      [ "$rc" -eq 0 ] || { bad "AC-012-01-10 $name: expected WARN exit 0, got $rc"; show_out "$out"; return 1; }
      run_capture "$out" "$TMP/$name.werr" bash "$CHECKER" --gates "$gates" "${tier_args[@]}" --warn-as-error "$TMP/$name"
      [ "$RUN_RC" -eq 1 ] || { bad "AC-012-01-10 $name: WARN must exit 1 under --warn-as-error, got $RUN_RC"; show_out "$out"; return 1; }
      ;;
    *) bad "AC-012-01-10 $name: bad severity '$sev' in selftest"; return 1 ;;
  esac
  grep -q "$expected" "$out" || { bad "AC-012-01-10 $name: expected output to contain '$expected'"; show_out "$out"; return 1; }
  ok "AC-012-01-10 $name: '$expected' fires as $sev (exit $rc)"
  return 0
}

# assert_clean NAME GATES ABSENT [--tier X] — near-miss/clean control: exit 0
# and no finding matching ABSENT.
assert_clean() {
  local name="$1" gates="$2" absent="$3"
  shift 3
  local out="$TMP/$name.out" tier_args=()
  [ "${1:-}" = "--tier" ] && { tier_args=(--tier "$2"); shift 2; }
  run_capture "$out" "$TMP/$name.err" bash "$CHECKER" --gates "$gates" "${tier_args[@]}" "$TMP/$name"
  [ "$RUN_RC" -eq 0 ] || { bad "AC-012-01-10 $name: control expected exit 0, got $RUN_RC"; show_out "$out"; return 1; }
  if grep -q "$absent" "$out"; then
    bad "AC-012-01-10 $name: control must NOT contain '$absent'"
    show_out "$out"
    return 1
  fi
  ok "AC-012-01-10 $name: clean control exits 0, no '$absent' finding"
  return 0
}

show_out() {
  echo "  actual output:"
  sed 's/^/    /' "$1" 2>/dev/null | head -20 || true
}

# ── AC-012-01-09: probe --gates support (spec 007 ordering dependency) ───────
# Fixture isolation requires 007's --gates. If it is not merged yet, --gates
# errors with "Unknown option" / exit 2 — surface that loudly instead of
# silently mis-running the fixture table.
mkdir -p "$TMP/probe"
cat > "$TMP/probe/Probe.java" <<'EOF'
public class Probe {
  public int add(int a, int b) { return a + b; }
}
EOF
run_capture "$TMP/probe.out" "$TMP/probe.err" bash "$CHECKER" --gates complexity "$TMP/probe"
if [ "$RUN_RC" -eq 2 ] && grep -q "Unknown option: --gates" "$TMP/probe.err"; then
  echo -e "${RED}FAIL${NC} AC-012-01-09: check-code-principles.sh does not support --gates."
  echo "  This selftest requires spec 007's --gates flag for fixture isolation"
  echo "  (specs/007-verifier-discipline). Land 012 in the same batch as 007,"
  echo "  or re-run once 007's flags are merged."
  exit 1
fi
[ "$RUN_RC" -eq 0 ] || { echo -e "${RED}FAIL${NC} AC-012-01-09: --gates probe returned unexpected exit $RUN_RC"; cat "$TMP/probe.err"; exit 1; }
ok "AC-012-01-09: checker supports --gates (spec 007 merged)"

# ── Fixtures ─────────────────────────────────────────────────────────────────

# complexity: cc-bad (7 ifs, CC=8) FAIL; cc-clean (5 ifs, CC=6) no finding
mkdir -p "$TMP/cc-bad"
cat > "$TMP/cc-bad/CcBad.java" <<'EOF'
public class CcBad {
  public void decide(int a, int b, int c, int d) {
    if (a > 1) { System.out.println(1); }
    if (b > 1) { System.out.println(2); }
    if (c > 1) { System.out.println(3); }
    if (d > 1) { System.out.println(4); }
    if (a + b > 2) { System.out.println(5); }
    if (b + c > 2) { System.out.println(6); }
    if (c + d > 2) { System.out.println(7); }
  }
}
EOF
mkdir -p "$TMP/cc-clean"
cat > "$TMP/cc-clean/CcClean.java" <<'EOF'
public class CcClean {
  public void decide(int a, int b, int c, int d) {
    if (a > 1) { System.out.println(1); }
    if (b > 1) { System.out.println(2); }
    if (c > 1) { System.out.println(3); }
    if (d > 1) { System.out.println(4); }
    if (a + b > 2) { System.out.println(5); }
  }
}
EOF
# kiss-lines: 22-line body, no conditionals; kiss-params: 7 parameters
mkdir -p "$TMP/kiss-lines"
cat > "$TMP/kiss-lines/KissLines.java" <<'EOF'
public class KissLines {
  public void longBody() {
    int a = 1;
    int b = 2;
    int c = a + b;
    int d = c * 2;
    int e = d + 1;
    int f = e - 1;
    int g = f * 3;
    int h = g / 2;
    int i = h + 4;
    int j = i - 4;
    int k = j * 5;
    int l = k / 5;
    int m = l + 6;
    int n = m - 6;
    int o = n * 7;
    int p = o / 7;
    int q = p + 8;
    int r = q - 8;
    int s = r * 9;
    int t = s / 9;
    int u = t + 10;
    System.out.println(u);
  }
}
EOF
mkdir -p "$TMP/kiss-params"
cat > "$TMP/kiss-params/KissParams.java" <<'EOF'
public class KissParams {
  public void wide(int a, int b, int c, int d, int e, int f, int g) { System.out.println(a + b + c + d + e + f + g); }
}
EOF

# dry-bad: identical 4-line block in two files; dry-clean: differs in one line
mkdir -p "$TMP/dry-bad"
cat > "$TMP/dry-bad/DryOne.java" <<'EOF'
public class DryOne { public void go() {
int a = 1;
int b = 2;
int c = a + b;
use(c);
} }
EOF
cp "$TMP/dry-bad/DryOne.java" "$TMP/dry-bad/DryTwo.java"
sed -i 's/DryOne/DryTwo/' "$TMP/dry-bad/DryTwo.java"
mkdir -p "$TMP/dry-clean"
cat > "$TMP/dry-clean/DryOne.java" <<'EOF'
public class DryOne { public void go() {
int a = 1;
int b = 2;
int c = a + b;
use(c);
} }
EOF
cat > "$TMP/dry-clean/DryTwo.java" <<'EOF'
public class DryTwo { public void go() {
int a = 1;
int b = 2;
int c = a + b;
log(c);
} }
EOF

# yagni-single-impl: interface + exactly one implementation (WARN — spec 011 demoted YAGNI single-impl from FAIL)
mkdir -p "$TMP/yagni-single-impl"
cat > "$TMP/yagni-single-impl/Greeter.java" <<'EOF'
public interface Greeter { void greet(); }
EOF
cat > "$TMP/yagni-single-impl/HelloGreeter.java" <<'EOF'
public class HelloGreeter implements Greeter {
  public void greet() { System.out.println("hi"); }
}
EOF
# yagni-empty-body: `{ }` method body (WARN)
mkdir -p "$TMP/yagni-empty-body"
cat > "$TMP/yagni-empty-body/EmptyBody.java" <<'EOF'
public class EmptyBody {
  public void nothing() { }
}
EOF

# solid: srp (16 non-empty methods), ocp (4-case switch), lsp (3 instanceof),
# isp (7-method interface) WARN; dip (domain/ importing repository) WARN — spec 011 demoted DIP from FAIL.
# SRP/OCP fixtures avoid empty `{ }` bodies so they don't cross-trigger the
# YAGNI empty-body WARN.
mkdir -p "$TMP/srp"
{
  echo "public class GodFile {"
  for i in $(seq 1 16); do echo "  public void m$i() { System.out.println($i); }"; done
  echo "}"
} > "$TMP/srp/GodFile.java"
mkdir -p "$TMP/ocp"
cat > "$TMP/ocp/Dispatcher.java" <<'EOF'
public class Dispatcher {
  public void dispatch(int x) {
    switch (x) {
      case 1: System.out.println(1); break;
      case 2: System.out.println(2); break;
      case 3: System.out.println(3); break;
      case 4: System.out.println(4); break;
      default: System.out.println(0);
    }
  }
}
EOF
mkdir -p "$TMP/lsp"
cat > "$TMP/lsp/Router.java" <<'EOF'
public class Router {
  public void route(Object o) {
    if (o instanceof A) { System.out.println(1); }
    if (o instanceof B) { System.out.println(2); }
    if (o instanceof C) { System.out.println(3); }
  }
}
EOF
mkdir -p "$TMP/isp"
cat > "$TMP/isp/Worker.java" <<'EOF'
public interface Worker {
  void a();
  void b();
  void c();
  void d();
  void e();
  void f();
  void g();
}
EOF
mkdir -p "$TMP/dip/domain"
cat > "$TMP/dip/domain/OrderService.java" <<'EOF'
package com.example.domain;
import com.example.repository.OrderRepository;
public class OrderService {
  public void run() { System.out.println(1); }
}
EOF

# property-tests: prop-bad (Go source, no testing/quick) FAIL at production;
# prop-clean (_test.go using testing/quick) no finding
mkdir -p "$TMP/prop-bad"
cat > "$TMP/prop-bad/adder.go" <<'EOF'
package main
func add(a int, b int) int { return a + b }
EOF
mkdir -p "$TMP/prop-clean"
cat > "$TMP/prop-clean/adder_test.go" <<'EOF'
package main
import "testing"
import "testing/quick"
func TestAddProp(t *testing.T) { quick.Check(func(a int, b int) bool { return true }, nil) }
EOF

# clean-tree: small well-formed Java file, full run at default tier
mkdir -p "$TMP/clean-tree"
cat > "$TMP/clean-tree/CleanTree.java" <<'EOF'
public class CleanTree {
  public int add(int a, int b) { return a + b; }
}
EOF

# ── Run ──────────────────────────────────────────────────────────────────────
echo "== AC-012-01 complexity + KISS =="
assert_finding "cc-bad" "complexity" "Cyclomatic complexity >6" fail
assert_clean "cc-clean" "complexity" "Cyclomatic complexity"
assert_finding "kiss-lines" "complexity" "Method body >20 lines" warn
assert_finding "kiss-params" "complexity" "Method with >6 parameters" warn

echo "== AC-012-01 DRY =="
assert_finding "dry-bad" "dry" "Possible duplication" warn
assert_clean "dry-clean" "dry" "Possible duplication"

echo "== AC-012-01 YAGNI =="
assert_finding "yagni-single-impl" "yagni" "has exactly one implementation" warn
assert_finding "yagni-empty-body" "yagni" "Empty method body" warn

echo "== AC-012-01 SOLID =="
assert_finding "srp" "solid" "SRP: possible god file" warn
assert_finding "ocp" "solid" "OCP: type-dispatch switch" warn
assert_finding "lsp" "solid" "LSP:" warn
assert_finding "isp" "solid" "ISP: fat interface" warn
assert_finding "dip" "solid" "DIP: domain/engine code imports" warn
# srp/ocp fixtures must not additionally produce an empty-body WARN
run_capture "$TMP/srp.out" "$TMP/srp.err" bash "$CHECKER" --gates solid "$TMP/srp"
if grep -q "Empty method body" "$TMP/srp.out"; then
  bad "AC-012-01-06 srp: must not cross-trigger the YAGNI empty-body WARN"
else
  ok "AC-012-01-06 srp: no empty-body cross-trigger"
fi
run_capture "$TMP/ocp.out" "$TMP/ocp.err" bash "$CHECKER" --gates solid "$TMP/ocp"
if grep -q "Empty method body" "$TMP/ocp.out"; then
  bad "AC-012-01-06 ocp: must not cross-trigger the YAGNI empty-body WARN"
else
  ok "AC-012-01-06 ocp: no empty-body cross-trigger"
fi

echo "== AC-012-01 property tests (production tier) =="
assert_finding "prop-bad" "property-tests" "Property tests (go): no testing/quick" fail --tier production
assert_clean "prop-clean" "property-tests" "Property tests (go): no testing/quick" --tier production

echo "== AC-012-01 clean tree (full run, default tier) =="
run_capture "$TMP/clean-tree.out" "$TMP/clean-tree.err" bash "$CHECKER" "$TMP/clean-tree"
[ "$RUN_RC" -eq 0 ] || { bad "AC-012-01-08 clean-tree: expected exit 0, got $RUN_RC"; show_out "$TMP/clean-tree.out"; exit 1; }
if grep -qF "$(printf '\033[0;31mFAIL')" "$TMP/clean-tree.out" || grep -qF "$(printf '\033[1;33mWARN')" "$TMP/clean-tree.out"; then
  bad "AC-012-01-08 clean-tree: no FAIL or WARN lines expected"
  show_out "$TMP/clean-tree.out"
  exit 1
fi
ok "AC-012-01-08 clean-tree: full run exits 0 with no FAIL or WARN lines"

# ── Spec 032: clean-code comment hygiene and naming gates ────────────────────
# Fixture groups for the three gates spec 032 adds. Each group asserts both
# directions: the violating fixture reports the documented message at the
# documented severity, and the near-miss/allowlisted control reports nothing.
#
#   comments-out-code   AC-032-04-01..03, AC-032-08-01..05
#   comments-restate    AC-032-05-01..03
#   comments-advisory   AC-032-06-01..04
#   comments-allowlist  AC-032-07-01..05
#   naming-heuristics   AC-032-09-01..06
#   null-discipline     AC-032-10-01..04
#
# Every fixture below sits at line 6 or later in its file: lines 1-5 are never
# scanned (the first-five-lines allowlist).

cc_pad_slash() { printf '%s\n' '// pad one' '// pad two' '// pad three' '// pad four' '// pad five'; }
cc_pad_hash() { printf '%s\n' '# pad one' '# pad two' '# pad three' '# pad four' '# pad five'; }

# cc_out NAME GATES MODE — run the checker against $TMP/NAME; sets CC_RC.
cc_out() {
  local name="$1" gates="$2" mode="${3:-}"
  if [ "$mode" = strict ]; then
    if STRICT_CLEAN_CODE=1 bash "$CHECKER" --gates "$gates" "$TMP/$name" >"$TMP/$name.out" 2>"$TMP/$name.err"; then
      CC_RC=0
    else
      CC_RC=$?
    fi
  else
    if bash "$CHECKER" --gates "$gates" "$TMP/$name" >"$TMP/$name.out" 2>"$TMP/$name.err"; then
      CC_RC=0
    else
      CC_RC=$?
    fi
  fi
}

# assert_cc_warn GROUP AC NAME GATES REGEX [MODE] — exit 0 and a WARN line.
assert_cc_warn() {
  local group="$1" acid="$2" name="$3" gates="$4" expected="$5" mode="${6:-}"
  cc_out "$name" "$gates" "$mode"
  if [ "$CC_RC" -ne 0 ]; then
    bad "$group $acid $name: expected exit 0 (WARN), got $CC_RC"
    show_out "$TMP/$name.out"
    return 1
  fi
  if ! grep -qE "WARN.*${expected}" "$TMP/$name.out"; then
    bad "$group $acid $name: expected a WARN line matching '$expected'"
    show_out "$TMP/$name.out"
    return 1
  fi
  ok "$group $acid $name: WARN matches '$expected' (exit 0)"
}

# assert_cc_fail GROUP AC NAME GATES REGEX [MODE] — exit 1 and a FAIL line.
assert_cc_fail() {
  local group="$1" acid="$2" name="$3" gates="$4" expected="$5" mode="${6:-}"
  cc_out "$name" "$gates" "$mode"
  if [ "$CC_RC" -ne 1 ]; then
    bad "$group $acid $name: expected exit 1 (FAIL), got $CC_RC"
    show_out "$TMP/$name.out"
    return 1
  fi
  if ! grep -qE "FAIL.*${expected}" "$TMP/$name.out"; then
    bad "$group $acid $name: expected a FAIL line matching '$expected'"
    show_out "$TMP/$name.out"
    return 1
  fi
  ok "$group $acid $name: FAIL matches '$expected' (exit 1)"
}

# assert_cc_clean GROUP AC NAME GATES REGEX [MODE] — exit 0 and no matching line.
assert_cc_clean() {
  local group="$1" acid="$2" name="$3" gates="$4" absent="$5" mode="${6:-}"
  cc_out "$name" "$gates" "$mode"
  if [ "$CC_RC" -ne 0 ]; then
    bad "$group $acid $name: control expected exit 0, got $CC_RC"
    show_out "$TMP/$name.out"
    return 1
  fi
  if grep -qE "$absent" "$TMP/$name.out"; then
    bad "$group $acid $name: control must NOT match '$absent'"
    show_out "$TMP/$name.out"
    return 1
  fi
  ok "$group $acid $name: control exits 0 with no '$absent'"
}

# ── comments-out-code (AC-032-04, AC-032-08) ────────────────────────────────
mkdir -p "$TMP/cc-out-bad/src"
{
  cc_pad_slash
  printf '%s\n' 'public class OutBad {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    int t = 1;'
  printf '%s\n' '    // total = price * quantity;'
  printf '%s\n' '    // printTotal(total);'
  printf '%s\n' '    use(t);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-out-bad/src/OutBad.java"
mkdir -p "$TMP/cc-out-single/src"
{
  cc_pad_slash
  printf '%s\n' 'public class OutSingle {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    int t = 1;'
  printf '%s\n' '    // total = 1;'
  printf '%s\n' '    use(t);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-out-single/src/OutSingle.java"
mkdir -p "$TMP/cc-out-prose/src"
{
  cc_pad_slash
  printf '%s\n' 'public class OutProse {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    // The totals are kept in cents to avoid rounding drift.'
  printf '%s\n' '    // See the billing note above for the historical reason.'
  printf '%s\n' '    int cents = 0;'
  printf '%s\n' '    use(cents);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-out-prose/src/OutProse.java"
mkdir -p "$TMP/cc-out-block/src"
{
  cc_pad_slash
  printf '%s\n' 'public class OutBlock {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    /*'
  printf '%s\n' '     * let x = 1;'
  printf '%s\n' '     * return x;'
  printf '%s\n' '     */'
  printf '%s\n' '    int y = 0;'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-out-block/src/OutBlock.java"
mkdir -p "$TMP/cc-out-shell/src"
{
  cc_pad_hash
  printf '%s\n' '# echo "alpha";'
  printf '%s\n' '# echo "beta";'
  printf '%s\n' 'echo done'
} > "$TMP/cc-out-shell/src/out.sh"
mkdir -p "$TMP/cc-out-py/src"
{
  cc_pad_hash
  printf '%s\n' '# total = price * quantity;'
  printf '%s\n' '# printTotal(total);'
  printf '%s\n' 'total = 0'
} > "$TMP/cc-out-py/src/out.py"

echo "== AC-032 comments-out-code =="
assert_cc_warn comments-out-code AC-032-04-01 cc-out-bad comments 'Comments: commented-out code'
assert_cc_fail comments-out-code AC-032-08-02 cc-out-bad comments 'Comments: commented-out code' strict
assert_cc_clean comments-out-code AC-032-04-02 cc-out-single comments 'Comments:'
assert_cc_clean comments-out-code AC-032-04-03 cc-out-prose comments 'Comments:'
assert_cc_warn comments-out-code AC-032-04-03 cc-out-block comments 'Comments: commented-out code'
assert_cc_warn comments-out-code AC-032-03-01 cc-out-shell comments 'Comments: commented-out code'
# ADR 0006 D6: .py findings stay WARN even with the strict switch on.
assert_cc_warn comments-out-code AC-032-08-05 cc-out-py comments 'Comments: commented-out code' strict

# ── comments-restate (AC-032-05) ────────────────────────────────────────────
mkdir -p "$TMP/cc-restate-bad/src"
{
  cc_pad_slash
  printf '%s\n' 'public class RestateBad {'
  printf '%s\n' '  int total() {'
  printf '%s\n' '    // return total'
  printf '%s\n' '    return total;'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-restate-bad/src/RestateBad.java"
mkdir -p "$TMP/cc-restate-extra/src"
{
  cc_pad_slash
  printf '%s\n' 'public class RestateExtra {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    // parse the config file'
  printf '%s\n' '    const parsed = parseConfig(file);'
  printf '%s\n' '    use(parsed);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-restate-extra/src/RestateExtra.java"
mkdir -p "$TMP/cc-restate-short/src"
{
  cc_pad_slash
  printf '%s\n' 'public class RestateShort {'
  printf '%s\n' '  int a() {'
  printf '%s\n' '    // total'
  printf '%s\n' '    return total;'
  printf '%s\n' '  }'
  printf '%s\n' '  int b() {'
  printf '%s\n' '    // return total'
  printf '%s\n' ''
  printf '%s\n' '    return total;'
  printf '%s\n' '  }'
  printf '%s\n' '}'
  printf '%s\n' '    // return total'
} > "$TMP/cc-restate-short/src/RestateShort.java"

echo "== AC-032 comments-restate =="
assert_cc_warn comments-restate AC-032-05-01 cc-restate-bad comments 'Comments: comment restates the following line'
assert_cc_clean comments-restate AC-032-05-02 cc-restate-extra comments 'Comments: comment restates the following line'
assert_cc_clean comments-restate AC-032-05-03 cc-restate-short comments 'Comments: comment restates the following line'

# ── comments-advisory (AC-032-06) ───────────────────────────────────────────
mkdir -p "$TMP/cc-adv-todo/src"
{
  cc_pad_slash
  printf '%s\n' '// TODO: handle retry'
  printf '%s\n' 'int value = 0;'
} > "$TMP/cc-adv-todo/src/Retry.java"
mkdir -p "$TMP/cc-adv-fixme/src"
{
  cc_pad_hash
  printf '%s\n' '# FIXME fix this before release'
  printf '%s\n' 'echo done'
} > "$TMP/cc-adv-fixme/src/cleanup.sh"
mkdir -p "$TMP/cc-adv-refs/src"
{
  cc_pad_slash
  printf '%s\n' '// TODO(#123): handle retry'
  printf '%s\n' '// TODO 456'
  printf '%s\n' '// FIXME https://example.com/i/7'
} > "$TMP/cc-adv-refs/src/Refs.java"
mkdir -p "$TMP/cc-adv-divider/src"
{
  cc_pad_slash
  printf '%s\n' '// =========='
} > "$TMP/cc-adv-divider/src/Divider.java"
mkdir -p "$TMP/cc-adv-note/src"
{
  cc_pad_slash
  printf '%s\n' '// -- note'
} > "$TMP/cc-adv-note/src/Note.java"
mkdir -p "$TMP/cc-adv-author/src"
{
  cc_pad_slash
  printf '%s\n' '// @author Jane Doe'
} > "$TMP/cc-adv-author/src/Author.java"
mkdir -p "$TMP/cc-adv-created/src"
{
  cc_pad_slash
  printf '%s\n' '// Created by Jane Doe'
} > "$TMP/cc-adv-created/src/Created.java"

echo "== AC-032 comments-advisory =="
assert_cc_warn comments-advisory AC-032-06-01 cc-adv-todo comments 'Comments: TODO/FIXME without an issue reference'
assert_cc_warn comments-advisory AC-032-06-01 cc-adv-fixme comments 'Comments: TODO/FIXME without an issue reference'
assert_cc_clean comments-advisory AC-032-06-02 cc-adv-refs comments 'Comments: TODO/FIXME without an issue reference'
assert_cc_warn comments-advisory AC-032-06-03 cc-adv-divider comments 'Comments: section-divider comment'
assert_cc_clean comments-advisory AC-032-06-03 cc-adv-note comments 'Comments: (section-divider|attribution)'
assert_cc_warn comments-advisory AC-032-06-03 cc-adv-author comments 'Comments: attribution comment'
assert_cc_warn comments-advisory AC-032-06-03 cc-adv-created comments 'Comments: attribution comment'
# Advisory rules never promote, even with the strict switch on.
assert_cc_warn comments-advisory AC-032-06-04 cc-adv-todo comments 'Comments: TODO/FIXME without an issue reference' strict

# ── comments-allowlist (AC-032-07) ──────────────────────────────────────────
mkdir -p "$TMP/cc-allow-firstfive/src"
cat > "$TMP/cc-allow-firstfive/src/head.sh" <<'SH'
#!/bin/bash
# ---------
set -e
# echo "alpha";
# echo "beta";
echo done
SH
mkdir -p "$TMP/cc-allow-directives/src"
{
  cc_pad_hash
  printf '%s\n' '# shellcheck disable=SC2086'
  printf '%s\n' '# shellcheck disable=SC2046'
  printf '%s\n' 'echo done'
} > "$TMP/cc-allow-directives/src/directives.sh"
mkdir -p "$TMP/cc-allow-markers/src"
{
  cc_pad_hash
  printf '%s\n' '# noqa: E501 value = compute();'
  printf '%s\n' '# return value;'
} > "$TMP/cc-allow-markers/src/noqa.sh"
{
  cc_pad_hash
  printf '%s\n' '# type: ignore total = compute();'
  printf '%s\n' '# return total;'
} > "$TMP/cc-allow-markers/src/typeignore.sh"
{
  cc_pad_hash
  printf '%s\n' '# pragma: no cover total = compute();'
  printf '%s\n' '# return total;'
} > "$TMP/cc-allow-markers/src/pragma.sh"
{
  cc_pad_hash
  printf '%s\n' '# ponytail: total = 200;'
  printf '%s\n' '# return total;'
} > "$TMP/cc-allow-markers/src/ponytail.sh"
{
  cc_pad_hash
  printf '%s\n' '# standards:allow-comment let total = 200;'
  printf '%s\n' '# return total;'
} > "$TMP/cc-allow-markers/src/standards.sh"
{
  cc_pad_hash
  printf '%s\n' '# Licensed under MIT;'
  printf '%s\n' '# return total;'
} > "$TMP/cc-allow-markers/src/licence.sh"
{
  cc_pad_hash
  printf '%s\n' '# https://example.com/let total = 5;'
  printf '%s\n' '# return total;'
} > "$TMP/cc-allow-markers/src/url.sh"
{
  cc_pad_hash
  printf '%s\n' '# SPDX-License-Identifier: MIT'
  printf '%s\n' '# Copyright 2026 Acme'
} > "$TMP/cc-allow-markers/src/spdx.sh"
# Per-line suppression: the directive line is skipped, the plain violation is not.
mkdir -p "$TMP/cc-allow-mixed/src"
{
  cc_pad_hash
  printf '%s\n' '# shellcheck disable=SC2086'
  printf '%s\n' 'echo start'
  printf '%s\n' '# echo "alpha";'
  printf '%s\n' '# echo "beta";'
} > "$TMP/cc-allow-mixed/src/mixed.sh"
mkdir -p "$TMP/cc-allow-docblock/src"
{
  cc_pad_slash
  printf '%s\n' '/**'
  printf '%s\n' ' * let x = 1;'
  printf '%s\n' ' * return x;'
  printf '%s\n' ' */'
  printf '%s\n' 'public void compute() { }'
} > "$TMP/cc-allow-docblock/src/Public.java"
{
  cc_pad_slash
  printf '%s\n' '/// let x = compute();'
  printf '%s\n' '/// return x;'
  printf '%s\n' 'pub fn compute() -> i32 { 1 }'
} > "$TMP/cc-allow-docblock/src/doc.rs"
{
  cc_pad_slash
  printf '%s\n' '// total := a + b;'
  printf '%s\n' '// return total;'
  printf '%s\n' 'func Add(a, b int) int { return a + b }'
} > "$TMP/cc-allow-docblock/src/doc.go"
mkdir -p "$TMP/cc-allow-docblock-ctl/src"
{
  cc_pad_slash
  printf '%s\n' '/**'
  printf '%s\n' ' * let x = 1;'
  printf '%s\n' ' * return x;'
  printf '%s\n' ' */'
  printf '%s\n' 'private void compute() { }'
} > "$TMP/cc-allow-docblock-ctl/src/Private.java"
{
  cc_pad_slash
  printf '%s\n' '// let x = compute();'
  printf '%s\n' '// return x;'
  printf '%s\n' 'fn compute() -> i32 { 1 }'
} > "$TMP/cc-allow-docblock-ctl/src/plain.rs"

echo "== AC-032 comments-allowlist =="
assert_cc_clean comments-allowlist AC-032-07-01 cc-allow-firstfive comments 'Comments:'
assert_cc_clean comments-allowlist AC-032-07-02 cc-allow-directives comments 'Comments:'
assert_cc_clean comments-allowlist AC-032-07-02 cc-allow-markers comments 'Comments:'
assert_cc_warn comments-allowlist AC-032-07-03 cc-allow-mixed comments 'Comments: commented-out code'
assert_cc_clean comments-allowlist AC-032-07-05 cc-allow-docblock comments 'Comments:'
assert_cc_warn comments-allowlist AC-032-07-05 cc-allow-docblock-ctl comments 'Comments: commented-out code'

# ── naming-heuristics (AC-032-09) ───────────────────────────────────────────
mkdir -p "$TMP/cc-name-single/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Counters {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    int x = 1;'
  printf '%s\n' '    use(x);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-name-single/src/Counters.java"
mkdir -p "$TMP/cc-name-single-ok/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Loops {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    int j = 2;'
  printf '%s\n' '    for (int i = 0; i < 3; i++) { use(i); }'
  printf '%s\n' '    for (int k = 0; k < 3; k++) { use(k); }'
  printf '%s\n' '    use(j);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-name-single-ok/src/Loops.java"
mkdir -p "$TMP/cc-name-noise/src"
{
  cc_pad_slash
  printf '%s\n' 'class UserManager {'
  printf '%s\n' '}'
  printf '%s\n' 'class Data {'
  printf '%s\n' '}'
  printf '%s\n' 'class Managerial {'
  printf '%s\n' '}'
  printf '%s\n' 'class Information {'
  printf '%s\n' '}'
} > "$TMP/cc-name-noise/src/Models.java"
mkdir -p "$TMP/cc-name-encoded/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Names {'
  printf '%s\n' '  void go() {'
  printf '%s\n' '    String strName = "a";'
  printf '%s\n' '    int iCount = 1;'
  printf '%s\n' '    int index = 2;'
  printf '%s\n' '    int counter = 3;'
  printf '%s\n' '    use(strName + iCount + index + counter);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-name-encoded/src/Names.java"
mkdir -p "$TMP/cc-name-bool/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Flags {'
  printf '%s\n' '  void save(boolean hasAccess) {'
  printf '%s\n' '    use(hasAccess);'
  printf '%s\n' '  }'
  printf '%s\n' '  void load(boolean access) {'
  printf '%s\n' '    use(access);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-name-bool/src/Flags.java"
{
  cc_pad_slash
  printf '%s\n' 'export function save(hasAccess: boolean): void {'
  printf '%s\n' '  use(hasAccess);'
  printf '%s\n' '}'
} > "$TMP/cc-name-bool/src/flags.ts"
mkdir -p "$TMP/cc-name-params/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Params {'
  printf '%s\n' '  void three(int a, int b, int c) {'
  printf '%s\n' '    use(a);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-name-params/src/Params.java"
mkdir -p "$TMP/cc-name-params-bad/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Params {'
  printf '%s\n' '  void four(int a, int b, int c, int d) {'
  printf '%s\n' '    use(a);'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-name-params-bad/src/Params.java"
mkdir -p "$TMP/cc-name-shell/src"
{
  cc_pad_hash
  printf '%s\n' 'x=1'
  printf '%s\n' 'y=2'
} > "$TMP/cc-name-shell/src/vars.sh"

echo "== AC-032 naming-heuristics =="
assert_cc_warn naming-heuristics AC-032-09-01 cc-name-single naming 'Naming: single-character identifier'
assert_cc_clean naming-heuristics AC-032-09-01 cc-name-single-ok naming 'Naming: single-character identifier'
assert_cc_warn naming-heuristics AC-032-09-02 cc-name-noise naming 'Naming: noise word in type name'
assert_cc_clean naming-heuristics AC-032-09-02 cc-name-noise naming 'noise word in type name \((Managerial|Information)\)'
assert_cc_warn naming-heuristics AC-032-09-03 cc-name-encoded naming 'Naming: encoded identifier'
assert_cc_clean naming-heuristics AC-032-09-03 cc-name-encoded naming 'encoded identifier \(index\)'
assert_cc_warn naming-heuristics AC-032-09-04 cc-name-bool naming 'Naming: boolean flag parameter'
assert_cc_clean naming-heuristics AC-032-09-04 cc-name-bool naming 'boolean flag parameter \(access\)'
assert_cc_warn naming-heuristics AC-032-09-05 cc-name-params-bad naming 'Naming: more than three parameters'
assert_cc_clean naming-heuristics AC-032-09-05 cc-name-params naming 'Naming: more than three parameters'
assert_cc_clean naming-heuristics AC-032-09-06 cc-name-shell naming 'Naming:'
assert_cc_warn naming-heuristics AC-032-09-06 cc-name-single naming 'Naming: single-character identifier' strict

# ── null-discipline (AC-032-10) ─────────────────────────────────────────────
mkdir -p "$TMP/cc-null-return/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Finder {'
  printf '%s\n' '  String find() { return null; }'
  printf '%s\n' '}'
} > "$TMP/cc-null-return/src/Finder.java"
{
  cc_pad_slash
  printf '%s\n' 'export function f() { return null; }'
} > "$TMP/cc-null-return/src/finder.ts"
mkdir -p "$TMP/cc-null-arg/src"
{
  cc_pad_slash
  printf '%s\n' 'public class Discipline {'
  printf '%s\n' '  void go(Object x) {'
  printf '%s\n' '    helper(null);'
  printf '%s\n' '    helper(1, null);'
  printf '%s\n' '    return x == null;'
  printf '%s\n' '    Object s = null;'
  printf '%s\n' '    return x == null ? this : null;'
  printf '%s\n' '  }'
  printf '%s\n' '}'
} > "$TMP/cc-null-arg/src/Discipline.java"
mkdir -p "$TMP/cc-null-langs/src"
{
  cc_pad_hash
  printf '%s\n' 'def f():'
  printf '%s\n' '    return None'
  printf '%s\n' 'helper(None)'
} > "$TMP/cc-null-langs/src/nulls.py"
{
  cc_pad_slash
  printf '%s\n' 'fn f() -> Option<u8> { None }'
} > "$TMP/cc-null-langs/src/nulls.rs"

echo "== AC-032 null-discipline =="
assert_cc_warn null-discipline AC-032-10-01 cc-null-return null-discipline 'Null-discipline: return null'
assert_cc_warn null-discipline AC-032-10-02 cc-null-arg null-discipline 'Null-discipline: null argument'
assert_cc_clean null-discipline AC-032-10-02 cc-null-arg null-discipline 'Null-discipline: return null'
assert_cc_clean null-discipline AC-032-10-03 cc-null-langs null-discipline 'Null-discipline:'
assert_cc_warn null-discipline AC-032-10-04 cc-null-return null-discipline 'Null-discipline: return null' strict

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-code-principles selftest: $FAIL_COUNT assertion(s) failed, $PASS_COUNT passed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-code-principles selftest: $PASS_COUNT assertions passed.${NC}"
