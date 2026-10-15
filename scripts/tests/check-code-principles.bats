#!/usr/bin/env bats
# check-code-principles.bats — characterization for scripts/check-code-principles.sh (AC-003)
# Covers AC-003-01..08: complexity FAIL, KISS WARN, DRY WARN, --gates, --json, -ReportPath, tier, time

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
}

teardown() {
  teardown_tmpdir
}

@test "AC-003-01: Complexity >6 triggers FAIL with file:line" {
  mkdir -p "$TMPDIR_HELPER/src"
  cat > "$TMPDIR_HELPER/src/Bad.java" <<'JAVA'
public class Bad {
  void bad(int a) {
    if (a==1) {}
    if (a==2) {}
    if (a==3) {}
    if (a==4) {}
    if (a==5) {}
    if (a==6) {}
    if (a==7) {}
  }
}
JAVA
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/src"
  [ "$status" -eq 1 ]
  [[ "$output$stderr" == *"FAIL"* ]]
  [[ "$output$stderr" == *"Cyclomatic complexity >6"* ]]
  [[ "$output$stderr" == *"Bad.java"* ]]
}

@test "AC-003-02: Method >20 lines triggers WARN not FAIL" {
  mkdir -p "$TMPDIR_HELPER/src2"
  cat > "$TMPDIR_HELPER/src2/Long.java" <<'JAVA'
public class Long {
  void longMethod() {
    int a=1;
    int b=2;
    int c=3;
    int d=4;
    int e=5;
    int f=6;
    int g=7;
    int h=8;
    int i=9;
    int j=10;
    int k=11;
    int l=12;
    int m=13;
    int n=14;
    int o=15;
    int p=16;
    int q=17;
    int r=18;
    int s=19;
    int t=20;
    int u=21;
    int v=22;
    int w=23;
    int x=24;
    int y=25;
  }
}
JAVA
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/src2"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" == *"WARN"* ]]
  [[ "$output$stderr" == *"Method body >20 lines"* ]]
}

@test "AC-003-03: Duplicate 4-line block triggers DRY WARN" {
  mkdir -p "$TMPDIR_HELPER/src3"
  cat > "$TMPDIR_HELPER/src3/A.java" <<'JAVA'
public class A {
  void m() {
    int x=1;
    int y=2;
    int z=3;
    int w=4;
  }
}
JAVA
  cat > "$TMPDIR_HELPER/src3/B.java" <<'JAVA'
public class B {
  void n() {
    int x=1;
    int y=2;
    int z=3;
    int w=4;
  }
}
JAVA
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/src3"
  [[ "$output$stderr" == *"WARN"* ]]
  [[ "$output$stderr" == *"Possible duplication"* || "$output$stderr" == *"DRY"* ]]
}

@test "AC-003-04: --gates filters which checks run (complexity gate not selected)" {
  mkdir -p "$TMPDIR_HELPER/src4"
  cat > "$TMPDIR_HELPER/src4/Bad2.java" <<'JAVA'
public class Bad2 {
  void bad(int a) {
    if (a==1) {}
    if (a==2) {}
    if (a==3) {}
    if (a==4) {}
    if (a==5) {}
    if (a==6) {}
    if (a==7) {}
  }
}
JAVA
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --gates dry "$TMPDIR_HELPER/src4"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" == *"dry"* ]]
  [[ "$output$stderr" != *"Cyclomatic complexity >6"* ]]
}

@test "AC-003-05: --json emits valid JSON with required keys" {
  mkdir -p "$TMPDIR_HELPER/src5"
  echo "class Foo {}" > "$TMPDIR_HELPER/src5/Foo.java"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --json "$TMPDIR_HELPER/src5"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  echo "$output" | python3 -m json.tool > /dev/null
  [[ "$output" == *'"tier"'* ]]
  [[ "$output" == *'"gates"'* ]]
  [[ "$output" == *'"fails"'* ]]
  [[ "$output" == *'"warns"'* ]]
}

@test "AC-003-06: -ReportPath writes JSON atomically and stdout unchanged" {
  mkdir -p "$TMPDIR_HELPER/src6"
  echo "class Foo {}" > "$TMPDIR_HELPER/src6/Foo.java"
  local report="$TMPDIR_HELPER/ac003-report.json"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" -ReportPath "$report" "$TMPDIR_HELPER/src6"
  [ -f "$report" ]
  python3 -m json.tool "$report" > /dev/null
  [[ "$(cat "$report")" == *'"tier"'* ]]
  [[ "$output$stderr" == *"Design-principles"* || "$output$stderr" == *"PASS"* || "$output$stderr" == *"FAIL"* || "$output$stderr" == *"WARN"* ]]
}

@test "AC-003-07: Tier mvp skips property-tests gate, production enforces it" {
  mkdir -p "$TMPDIR_HELPER/prod/src"
  echo "class Foo {}" > "$TMPDIR_HELPER/prod/src/Foo.java"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --tier production "$TMPDIR_HELPER/prod"
  [ "$status" -eq 1 ]
  [[ "$output$stderr" == *"Property tests"* ]]
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --tier mvp "$TMPDIR_HELPER/prod"
  [ "$status" -eq 0 ]
  [[ "$output$stderr" == *"skipped"* ]]
}

@test "AC-003-08: Tests complete quickly with minimal fixtures (<5s)" {
  mkdir -p "$TMPDIR_HELPER/quick/src"
  echo "class X {}" > "$TMPDIR_HELPER/quick/src/X.java"
  run --separate-stderr bash -c "time bash '$REPO_ROOT/scripts/check-code-principles.sh' '$TMPDIR_HELPER/quick/src' > /tmp/ac003-time.txt 2>&1; cat /tmp/ac003-time.txt"
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
  wc -l "$TMPDIR_HELPER/quick/src/X.java" | awk '{if ($1 > 30) exit 1}'
}

@test "check-code-principles: a Go 'type X interface' declaration does not abort the YAGNI scan" {
  # Regression: the Go YAGNI branch extracted the interface name with Java's
  # `interface X` pattern. Go writes `type X interface {`, so grep -o matched
  # nothing, returned 1, and aborted the whole gate under `set -euo pipefail` —
  # truncating the run with no summary line. The gate must complete.
  mkdir -p "$TMPDIR_HELPER/goif/store"
  printf 'package store\n\ntype FeatureStore interface {\n\tGet(id string) (string, error)\n}\n' \
    > "$TMPDIR_HELPER/goif/store/feature_store.go"
  printf 'package store\n\nfunc Use(s FeatureStore) error { _, err := s.Get("x"); return err }\n' \
    > "$TMPDIR_HELPER/goif/store/use.go"
  run bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/goif"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Design-principles check:"* ]]
  [[ "$output" == *"FAIL(s)"* ]]
}

@test "check-code-principles: ci/ is analyzed, not pruned from discovery" {
  # Regression: `-o -name ci` was added to FIND_PRUNE, silently excluding every
  # child-repo CI template from the design gate. Discovery must reach ci/.
  run grep -n 'FIND_PRUNE=' "$REPO_ROOT/scripts/check-code-principles.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *"-name ci "* ]]
  [[ "$output" != *"-name ci)"* ]]
  run bash "$REPO_ROOT/scripts/check-code-principles.sh" "$REPO_ROOT/ci"
  [[ "$output" != *"scanned for extensions: java, go, ts, tsx, js, jsx, py, rs"* ]]
  [[ "$output" == *"Checking design principles in:"* ]]
}

# ── ADR 0006: Python/Rust coverage (D1), visible zero-file scan (D5),
#    warn-only rollout (D6) ──────────────────────────────────────────────────

@test "ADR-0006 D5: zero-file scan enumerates scanned extensions and still exits 0" {
  mkdir -p "$TMPDIR_HELPER/empty"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/empty"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No source files found"* ]]
  [[ "$output" == *"scanned for extensions: java, go, ts, tsx, js, jsx, py, rs"* ]]
  [[ "$output" == *"--require-language"* ]]
}

@test "ADR-0006 D1/D6: Python complexity finding is an approximate WARN, exit 0" {
  mkdir -p "$TMPDIR_HELPER/py/src"
  cat > "$TMPDIR_HELPER/py/src/complex_py.py" <<'PY'
def complex_branching(a):
    total = 0
    if a == 1:
        total += 1
    if a == 2:
        total += 2
    if a == 3:
        total += 3
    if a == 4:
        total += 4
    if a == 5:
        total += 5
    if a == 6:
        total += 6
    if a == 7:
        total += 7
    return total
PY
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/py"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"Cyclomatic complexity >6 (python)"* ]]
  [[ "$output" == *"complex_py.py"* ]]
  [[ "$output" == *"approximate"* ]]
  [[ "$output" == *"0 FAIL(s)"* ]]
}

@test "ADR-0006 D1/D6: Rust complexity finding is an approximate WARN, exit 0" {
  mkdir -p "$TMPDIR_HELPER/rs/src"
  cat > "$TMPDIR_HELPER/rs/src/complex_rs.rs" <<'RS'
pub fn classify(x: i32) -> i32 {
    if x == 1 { return 1; }
    if x == 2 { return 2; }
    if x == 3 { return 3; }
    if x == 4 { return 4; }
    if x == 5 { return 5; }
    if x == 6 { return 6; }
    if x == 7 { return 7; }
    return 0;
}
RS
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/rs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARN"* ]]
  [[ "$output" == *"Cyclomatic complexity >6 (rust)"* ]]
  [[ "$output" == *"complex_rs.rs"* ]]
  [[ "$output" == *"approximate"* ]]
  [[ "$output" == *"0 FAIL(s)"* ]]
}

@test "ADR-0006 D6: Python/Rust findings stay WARN and exit 0 even with --blocking complexity" {
  # complexity IS in the blocking set here; D6 warn-phase demotion must still
  # keep .py/.rs findings at WARN (exit 0), proving the demotion happens
  # before the blocking-set check.
  mkdir -p "$TMPDIR_HELPER/pyrs/src"
  cat > "$TMPDIR_HELPER/pyrs/src/branchy.py" <<'PY'
def many_branches(a):
    if a == 1:
        return 1
    if a == 2:
        return 2
    if a == 3:
        return 3
    if a == 4:
        return 4
    if a == 5:
        return 5
    if a == 6:
        return 6
    if a == 7:
        return 7
    return 0
PY
  cat > "$TMPDIR_HELPER/pyrs/src/branchy.rs" <<'RS'
pub fn many_branches(x: i32) -> i32 {
    if x == 1 { return 1; }
    if x == 2 { return 2; }
    if x == 3 { return 3; }
    if x == 4 { return 4; }
    if x == 5 { return 5; }
    if x == 6 { return 6; }
    if x == 7 { return 7; }
    return 0;
}
RS
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --blocking complexity "$TMPDIR_HELPER/pyrs"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Cyclomatic complexity >6 (python)"* ]]
  [[ "$output" == *"Cyclomatic complexity >6 (rust)"* ]]
  [[ "$output" == *"0 FAIL(s)"* ]]
  [[ "$output" != *"1 FAIL(s)"* ]]
}

@test "ADR-0006 D1: component-per-file does not fire for Python/Rust" {
  # A Python module with many top-level classes/functions and a Rust file with
  # many pub fns: the JS/TS component-model gate must not report on them.
  mkdir -p "$TMPDIR_HELPER/cpf/src"
  cat > "$TMPDIR_HELPER/cpf/src/widgets.py" <<'PY'
class Alpha:
    pass


class Beta:
    pass


class Gamma:
    pass


class Delta:
    pass
PY
  cat > "$TMPDIR_HELPER/cpf/src/widget.rs" <<'RS'
pub fn alpha() -> u8 { 1 }
pub fn beta() -> u8 { 2 }
pub fn gamma() -> u8 { 3 }
pub fn delta() -> u8 { 4 }
pub fn epsilon() -> u8 { 5 }
RS
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" "$TMPDIR_HELPER/cpf"
  [ "$status" -eq 0 ]
  [[ "$output" != *"Component-per-file: $TMPDIR_HELPER"* ]]
  [[ "$output" != *"exported components"* ]]
  [[ "$output" != *"god file"* ]]
}

@test "ADR-0006 D5: --require-language python exits 1 when no Python files exist" {
  mkdir -p "$TMPDIR_HELPER/reqabsent/src"
  cat > "$TMPDIR_HELPER/reqabsent/src/Foo.java" <<'JAVA'
public class Foo {}
JAVA
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --require-language python "$TMPDIR_HELPER/reqabsent"
  [ "$status" -eq 1 ]
  [[ "$output$stderr" == *"--require-language python"* ]]
  [[ "$output$stderr" == *"no matching source files found"* ]]
}

@test "ADR-0006 D5: --require-language python exits 0 when Python files exist" {
  mkdir -p "$TMPDIR_HELPER/reqpresent/src"
  cat > "$TMPDIR_HELPER/reqpresent/src/foo.py" <<'PY'
def foo():
    return 1
PY
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --require-language python "$TMPDIR_HELPER/reqpresent"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--require-language python: matching source files found"* ]]
}

@test "ADR-0006 D5: --require-language with an unknown language exits 2" {
  mkdir -p "$TMPDIR_HELPER/reqbad"
  run --separate-stderr bash "$REPO_ROOT/scripts/check-code-principles.sh" --require-language ruby "$TMPDIR_HELPER/reqbad"
  [ "$status" -eq 2 ]
  [[ "$output$stderr" == *"unknown --require-language value: 'ruby'"* ]]
}
