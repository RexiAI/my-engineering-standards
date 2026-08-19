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

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo -e "${RED}✘ check-code-principles selftest: $FAIL_COUNT assertion(s) failed, $PASS_COUNT passed.${NC}"
  exit 1
fi
echo -e "${GREEN}✔ check-code-principles selftest: $PASS_COUNT assertions passed.${NC}"
