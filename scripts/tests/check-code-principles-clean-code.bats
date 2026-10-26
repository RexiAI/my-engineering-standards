#!/usr/bin/env bats
# check-code-principles-clean-code.bats — acceptance tests for spec 032,
# "Clean Code comment hygiene and naming gates".
#
# One test per scenario in specs/032-clean-code-comment-hygiene/20-acceptance/,
# named after the scenario's full AC ID so scripts/check-scenario-traceability.sh
# can resolve it. Fixtures are written to a per-test mktemp dir (never inside the
# repo tree), so nothing here is audited by the repo's own gate run.
#
# Fixture convention (from the scenario files): lines 1-5 of every fixture are
# padding, because the comment gate's allowlist never scans the first five lines
# of a file (Task 07). Anything under test therefore sits at line 6 or later.

load test_helper
bats_require_minimum_version 1.5.0

CHECKER="$REPO_ROOT/scripts/check-code-principles.sh"
SELFTEST="$REPO_ROOT/scripts/check-code-principles.selftest.sh"
BLAME="$REPO_ROOT/scripts/tests/check-code-principles-blame.sh"
CONSISTENCY="$REPO_ROOT/scripts/check-gate-consistency.sh"
ADR="$REPO_ROOT/docs/adr/0013-clean-code-comment-gates.md"
ADR_INDEX="$REPO_ROOT/docs/adr/README.md"
SKILL="$REPO_ROOT/skills/check-principles/SKILL.md"
CONVENTIONS="$REPO_ROOT/docs/CODING_CONVENTIONS.md"

OUTF=""
ERRF=""
RC=0

setup() {
  setup_tmpdir
  OUTF="$TMPDIR_HELPER/stdout"
  ERRF="$TMPDIR_HELPER/stderr"
  RC=0
}

teardown() {
  teardown_tmpdir
}

# cc [args...] — run the checker, capturing stdout/stderr; set RC.
cc() {
  if bash "$CHECKER" "$@" >"$OUTF" 2>"$ERRF"; then RC=0; else RC=$?; fi
}

# cc_env VAR=VALUE [args...] — run the checker with exactly one env var set.
cc_env() {
  local kv="$1"
  shift
  if env "$kv" bash "$CHECKER" "$@" >"$OUTF" 2>"$ERRF"; then RC=0; else RC=$?; fi
}

# sho <pattern> — 0 if the last run's stdout matches the extended regex.
sho() { grep -qE "$1" "$OUTF"; }

# sherr <pattern> — 0 if the last run's stderr matches the extended regex.
sherr() { grep -qE "$1" "$ERRF"; }

# count_sho <pattern> — number of matching stdout lines.
count_sho() { grep -cE "$1" "$OUTF" || true; }

# pad_slash / pad_hash — five padding lines (never scanned, see header note).
pad_slash() { printf '%s\n' '// pad one' '// pad two' '// pad three' '// pad four' '// pad five'; }
pad_hash() { printf '%s\n' '# pad one' '# pad two' '# pad three' '# pad four' '# pad five'; }

# section_of <file> <heading> — body of a `## <heading>` section (until the next
# level-2 heading; `###` subsections stay inside it).
section_of() {
  awk -v h="## $2" '
    /^## / { if (found) exit; if ($0 == h) { found = 1; next } }
    found { print }
  ' "$1"
}

# ── Task 01 — ADR 0013 ───────────────────────────────────────────────────────

@test "AC-032-01-01: the ADR exists with the mandated section shape" {
  [ -f "$ADR" ]
  head -1 "$ADR" | grep -qE '^# ADR 0013: .+'
  local heads first_five
  heads="$(grep -E '^## ' "$ADR")"
  first_five="$(printf '%s\n' "$heads" | head -5)"
  [ "$first_five" = "$(printf '%s\n' '## Status' '## Context' '## Decision' '## Consequences' '## Compliance')" ]
  local alt_line dec_line con_line
  alt_line="$(grep -nE '^### Alternatives Considered' "$ADR" | cut -d: -f1)"
  dec_line="$(grep -nE '^## Decision$' "$ADR" | cut -d: -f1)"
  con_line="$(grep -nE '^## Consequences$' "$ADR" | cut -d: -f1)"
  [ -n "$alt_line" ]
  [ "$dec_line" -lt "$alt_line" ]
  [ "$alt_line" -lt "$con_line" ]
  local status_first
  status_first="$(section_of "$ADR" Status | grep -v '^[[:space:]]*$' | head -1)"
  case "$status_first" in
    Proposed | Accepted) ;;
    *) return 1 ;;
  esac
}

@test "AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban" {
  [ -f "$ADR" ]
  local context decision
  context="$(section_of "$ADR" Context)"
  decision="$(section_of "$ADR" Decision)"

  printf '%s\n' "$context" | grep -qF 'Clean Code Ch.4'
  printf '%s\n' "$context" | grep -qiE 'endorse'
  printf '%s\n' "$context" | grep -qiE 'forbid'
  printf '%s\n' "$context" | grep -qF 'commented-out code'
  printf '%s\n' "$context" | grep -qiF 'redundant comment'
  printf '%s\n' "$context" | grep -qF 'TODO'
  printf '%s\n' "$context" | grep -qF 'divider'
  printf '%s\n' "$context" | grep -qF 'attribution'

  printf '%s\n' "$decision" | grep -qF 'comments'
  printf '%s\n' "$decision" | grep -qF 'naming'
  printf '%s\n' "$decision" | grep -qF 'null-discipline'
  printf '%s\n' "$decision" | grep -qF 'STRICT_CLEAN_CODE=1'
  printf '%s\n' "$decision" | grep -qF 'WARN by default'
  printf '%s\n' "$decision" | grep -qF 'docs/'
  printf '%s\n' "$decision" | grep -qF 'specs/'
  printf '%s\n' "$decision" | grep -qF 'agents/'
  printf '%s\n' "$decision" | grep -qF 'templates/'
  printf '%s\n' "$decision" | grep -qF 'node_modules/'

  # The rejected blanket ban row names its casualties.
  local ban_row
  ban_row="$(printf '%s\n' "$decision" | grep -iF 'blanket comment ban' | grep -F '|' | head -1)"
  [ -n "$ban_row" ]
  printf '%s' "$ban_row" | grep -qiF 'shebang'
  printf '%s' "$ban_row" | grep -qF 'shellcheck'
  printf '%s' "$ban_row" | grep -qiF 'usage header'
  printf '%s' "$ban_row" | grep -qF 'ponytail:'
  printf '%s' "$ban_row" | grep -qiE 'reject'

  # Supersession of spec 011's "no naming gate" assertion is recorded.
  grep -qF 'AC-011-03-07' "$ADR"
  grep -qiF 'superse' "$ADR"
}

@test "AC-032-01-03: the ADR is indexed and governance still passes" {
  [ -f "$ADR_INDEX" ]
  local row
  row="$(grep -E '^\| 0013 \|' "$ADR_INDEX" | head -1)"
  [ -n "$row" ]
  printf '%s' "$row" | grep -qF '0013-clean-code-comment-gates.md'
  [ -f "$ADR" ]
  printf '%s' "$row" | grep -qE '\| (Proposed|Accepted) \|[[:space:]]*$'
  grep -qxF '## Trust Tiers' "$REPO_ROOT/docs/GOVERNANCE.md"
  grep -qxF '## Model-Assignment Discipline' "$REPO_ROOT/docs/GOVERNANCE.md"
  grep -qxF '## ADR Requirement' "$REPO_ROOT/docs/GOVERNANCE.md"
  if ( cd "$REPO_ROOT" && bash scripts/check-governance.sh >"$OUTF" 2>"$ERRF" ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
}

# ── Task 02 — gate catalog registration ──────────────────────────────────────

@test "AC-032-02-01: the three new names are accepted by --gates and --blocking" {
  mkdir -p "$TMPDIR_HELPER/trivial/src"
  printf 'public class Thing { public int add(int a, int b) { return a + b; } }\n' \
    > "$TMPDIR_HELPER/trivial/src/Thing.java"
  local gates
  for gates in comments naming null-discipline comments,naming,null-discipline; do
    cc --gates "$gates" "$TMPDIR_HELPER/trivial"
    [ "$RC" -eq 0 ]
    ! sherr 'unknown gate'
    ! sherr 'Unknown option'
  done
  cc --blocking comments "$TMPDIR_HELPER/trivial"
  [ "$RC" -eq 0 ]
  ! sherr 'unknown gate'
  ! sherr 'Unknown option'
}

@test "AC-032-02-02: unknown and empty gate values still exit 2 and list all nine" {
  mkdir -p "$TMPDIR_HELPER/badgate/src"
  printf 'public class Thing {}\n' > "$TMPDIR_HELPER/badgate/src/Thing.java"
  local nine='complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline'

  cc --gates bogus "$TMPDIR_HELPER/badgate"
  [ "$RC" -eq 2 ]
  sherr "\(valid: ${nine}\)"

  cc --gates "" "$TMPDIR_HELPER/badgate"
  [ "$RC" -eq 2 ]
  sherr "complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline"

  cc --blocking bogus "$TMPDIR_HELPER/badgate"
  [ "$RC" -eq 2 ]
  sherr "unknown gate name in blocking set: 'bogus'"
  sherr "valid gates: ${nine}"

  cc --blocking "" "$TMPDIR_HELPER/badgate"
  [ "$RC" -eq 2 ]
  sherr "complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline"
}

@test "AC-032-02-03: a default run selects nine gates, a scoped run says so in the summary" {
  mkdir -p "$TMPDIR_HELPER/nine/src"
  printf 'public class Thing { public int add(int a, int b) { return a + b; } }\n' \
    > "$TMPDIR_HELPER/nine/src/Thing.java"

  cc --json "$TMPDIR_HELPER/nine"
  [ "$RC" -eq 0 ]
  python3 - "$OUTF" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
want = ["complexity", "dry", "yagni", "solid", "component-per-file",
        "property-tests", "comments", "naming", "null-discipline"]
assert doc["gates"] == want, doc["gates"]
PY

  cc "$TMPDIR_HELPER/nine"
  [ "$RC" -eq 0 ]
  ! sho '\(gates:'

  cc --gates comments,naming "$TMPDIR_HELPER/nine"
  [ "$RC" -eq 0 ]
  sho '\(gates: comments,naming\)'
}

@test "AC-032-02-04: help text documents the three gates, the allowlist, and the strict switch" {
  local script="$CHECKER"
  local header
  header="$(sed -n '1,/^set -euo pipefail$/p' "$script")"
  printf '%s\n' "$header" | grep -qF 'comments'
  printf '%s\n' "$header" | grep -qF 'naming'
  printf '%s\n' "$header" | grep -qF 'null-discipline'
  printf '%s\n' "$header" | grep -qF 'STRICT_CLEAN_CODE'
  # Blocking-class vs advisory rules are documented as such.
  printf '%s\n' "$header" | grep -qE 'commented-out code'
  printf '%s\n' "$header" | grep -qE 'restates the following line'
  printf '%s\n' "$header" | grep -qE 'TODO/FIXME'
  printf '%s\n' "$header" | grep -qE 'section-divider'
  printf '%s\n' "$header" | grep -qE 'attribution'
  printf '%s\n' "$header" | grep -qF 'blocking-class'
  printf '%s\n' "$header" | grep -qF 'advisory'
  # Allowlist categories.
  printf '%s\n' "$header" | grep -qiE 'first five lines'
  printf '%s\n' "$header" | grep -qF 'shellcheck'
  printf '%s\n' "$header" | grep -qF 'noqa'
  printf '%s\n' "$header" | grep -qF 'type: ignore'
  printf '%s\n' "$header" | grep -qF 'pragma'
  printf '%s\n' "$header" | grep -qF 'ponytail:'
  printf '%s\n' "$header" | grep -qF 'standards:allow-'
  printf '%s\n' "$header" | grep -qiE 'licence'
  printf '%s\n' "$header" | grep -qiE 'url'
  printf '%s\n' "$header" | grep -qiE 'public.api|public-API|doc block|doc-block'
  # naming / null-discipline never FAIL.
  printf '%s\n' "$header" | grep -qiE 'never .*FAIL'
  # Preserved literals and threshold.
  grep -qF 'Default blocking set: complexity,property-tests' "$script"
  grep -qF '> 6' "$script"
  ! grep -qF -- '--threshold' "$script"
  ! grep -qF -- '--complexity' "$script"
}

@test "AC-032-02-05: each new gate has its own dispatch block" {
  mkdir -p "$TMPDIR_HELPER/dispatch/src"
  printf 'public class Thing { public int add(int a, int b) { return a + b; } }\n' \
    > "$TMPDIR_HELPER/dispatch/src/Thing.java"
  cc --gates comments,naming,null-discipline "$TMPDIR_HELPER/dispatch"
  [ "$RC" -eq 0 ]
  sho '^--- Comments ---$'
  sho '^--- Naming ---$'
  sho '^--- Null discipline ---$'
  local n
  n="$(grep -cE 'PASS' "$OUTF" || true)"
  [ "$n" -ge 3 ]
  ! sho '^--- DRY ---$'
  ! sho '^--- YAGNI ---$'
  ! sho '^--- SOLID ---$'
  ! sho '^--- Component-per-file ---$'
  ! sho '^--- Property tests ---$'
}

# ── Task 03 — comment discovery ──────────────────────────────────────────────

@test "AC-032-03-01: shell files are scanned for comments" {
  mkdir -p "$TMPDIR_HELPER/shscan/src"
  cat > "$TMPDIR_HELPER/shscan/src/ok.sh" <<'SH'
#!/bin/bash
echo start
echo middle-one
echo middle-two
echo middle-three
# echo "alpha";
# echo "beta";
echo done
SH
  cc --gates comments "$TMPDIR_HELPER/shscan"
  [ "$RC" -eq 0 ]
  sho 'Comments: commented-out code'
  sho 'ok\.sh'
}

@test "AC-032-03-02: excluded directories are not scanned" {
  local base="$TMPDIR_HELPER/exclude"
  local d
  for d in src docs specs agents templates node_modules; do
    mkdir -p "$base/$d"
    cat > "$base/$d/a.sh" <<'SH'
#!/bin/bash
echo start
echo middle-one
echo middle-two
echo middle-three
# echo "alpha";
# echo "beta";
echo done
SH
  done
  cc --gates comments "$base"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Comments: commented-out code')" -eq 1 ]
  sho 'src/a\.sh'
  ! sho 'docs/a\.sh'
  ! sho 'specs/a\.sh'
  ! sho 'agents/a\.sh'
  ! sho 'templates/a\.sh'
  ! sho 'node_modules/a\.sh'
}

@test "AC-032-03-03: shell is not dragged into the existing gates" {
  mkdir -p "$TMPDIR_HELPER/shgates/src"
  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' 'branchy() {'
    printf '%s\n' '  if [ "$1" = 1 ]; then echo 1; fi'
    printf '%s\n' '  if [ "$1" = 2 ]; then echo 2; fi'
    printf '%s\n' '  if [ "$1" = 3 ]; then echo 3; fi'
    printf '%s\n' '  if [ "$1" = 4 ]; then echo 4; fi'
    printf '%s\n' '  if [ "$1" = 5 ]; then echo 5; fi'
    printf '%s\n' '  if [ "$1" = 6 ]; then echo 6; fi'
    printf '%s\n' '  if [ "$1" = 7 ]; then echo 7; fi'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/shgates/src/branchy.sh"
  cc --gates complexity "$TMPDIR_HELPER/shgates"
  [ "$RC" -eq 0 ]
  ! sho 'Cyclomatic complexity'
  ! sho 'KISS'
  cc --gates comments "$TMPDIR_HELPER/shgates"
  [ "$RC" -eq 0 ]
  ! sho 'Cyclomatic complexity'
  ! sho 'KISS'
}

@test "AC-032-03-04: the scanned-extension message names shell, and its test is updated" {
  mkdir -p "$TMPDIR_HELPER/nothing"
  cc "$TMPDIR_HELPER/nothing"
  [ "$RC" -eq 0 ]
  sho 'scanned for extensions: java, go, ts, tsx, js, jsx, py, rs, sh'
  grep -qF 'scanned for extensions: java, go, ts, tsx, js, jsx, py, rs, sh' \
    "$REPO_ROOT/scripts/tests/check-code-principles.bats"
}

# ── Task 04 — commented-out code ─────────────────────────────────────────────

@test "AC-032-04-01: two consecutive code-shaped comment lines produce one finding" {
  mkdir -p "$TMPDIR_HELPER/outcode/src"
  {
    pad_slash
    printf '%s\n' 'public class Ledger {'
    printf '%s\n' '  void total(int price, int quantity) {'
    printf '%s\n' '    int t = price * quantity;'
    printf '%s\n' '    // total = price * quantity;'
    printf '%s\n' '    // printTotal(total);'
    printf '%s\n' '    System.out.println(t);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/outcode/src/Ledger.java"
  cc --gates comments "$TMPDIR_HELPER/outcode"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Comments: commented-out code')" -eq 1 ]
  sho 'Ledger\.java:9'
}

@test "AC-032-04-02: a single code-shaped comment line is not a finding" {
  mkdir -p "$TMPDIR_HELPER/singlecode/src"
  {
    pad_slash
    printf '%s\n' 'public class Single {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    int t = 1;'
    printf '%s\n' '    // total = 1;'
    printf '%s\n' '    use(t);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/singlecode/src/Single.java"
  cc --gates comments "$TMPDIR_HELPER/singlecode"
  [ "$RC" -eq 0 ]
  ! sho 'Comments:'
}

@test "AC-032-04-03: two consecutive prose comment lines are not a finding" {
  mkdir -p "$TMPDIR_HELPER/prose/src"
  {
    pad_slash
    printf '%s\n' 'public class Prose {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // The totals are kept in cents to avoid rounding drift.'
    printf '%s\n' '    // See the billing note above for the historical reason.'
    printf '%s\n' '    int cents = 0;'
    printf '%s\n' '    use(cents);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/prose/src/Prose.java"
  cc --gates comments "$TMPDIR_HELPER/prose"
  [ "$RC" -eq 0 ]
  ! sho 'Comments:'

  mkdir -p "$TMPDIR_HELPER/blockcode/src"
  {
    pad_slash
    printf '%s\n' 'public class BlockCode {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    /*'
    printf '%s\n' '     * let x = 1;'
    printf '%s\n' '     * return x;'
    printf '%s\n' '     */'
    printf '%s\n' '    int y = 0;'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/blockcode/src/BlockCode.java"
  cc --gates comments "$TMPDIR_HELPER/blockcode"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Comments: commented-out code')" -eq 1 ]
}

# ── Task 05 — restating comment ──────────────────────────────────────────────

@test "AC-032-05-01: a token-subset comment produces a finding" {
  mkdir -p "$TMPDIR_HELPER/restate/src"
  {
    pad_slash
    printf '%s\n' 'public class Restate {'
    printf '%s\n' '  int total() {'
    printf '%s\n' '    // return total'
    printf '%s\n' '    return total;'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/restate/src/Restate.java"
  cc --gates comments "$TMPDIR_HELPER/restate"
  [ "$RC" -eq 0 ]
  sho 'Comments: comment restates the following line'
  sho 'Restate\.java:8'
}

@test "AC-032-05-02: an extra token in the comment suppresses the finding" {
  mkdir -p "$TMPDIR_HELPER/norestate/src"
  {
    pad_slash
    printf '%s\n' 'public class NoRestate {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // parse the config file'
    printf '%s\n' '    const parsed = parseConfig(file);'
    printf '%s\n' '    use(parsed);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/norestate/src/NoRestate.java"
  cc --gates comments "$TMPDIR_HELPER/norestate"
  [ "$RC" -eq 0 ]
  ! sho 'Comments: comment restates the following line'
}

@test "AC-032-05-03: short comments and non-adjacent comments do not fire" {
  mkdir -p "$TMPDIR_HELPER/shortrestate/src"
  {
    pad_slash
    printf '%s\n' 'public class ShortRestate {'
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
  } > "$TMPDIR_HELPER/shortrestate/src/ShortRestate.java"
  cc --gates comments "$TMPDIR_HELPER/shortrestate"
  [ "$RC" -eq 0 ]
  ! sho 'Comments: comment restates the following line'
}

# ── Task 06 — advisory comment findings ──────────────────────────────────────

@test "AC-032-06-01: TODO and FIXME without an issue reference warn" {
  mkdir -p "$TMPDIR_HELPER/todo/src"
  {
    pad_slash
    printf '%s\n' 'public class Retry {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // TODO: handle retry'
    printf '%s\n' '    use(1);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/todo/src/Retry.java"
  {
    pad_hash
    printf '%s\n' '# FIXME fix this before release'
    printf '%s\n' 'echo done'
  } > "$TMPDIR_HELPER/todo/src/cleanup.sh"
  cc --gates comments "$TMPDIR_HELPER/todo"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Comments: TODO/FIXME without an issue reference')" -eq 2 ]
}

@test "AC-032-06-02: an issue reference suppresses the TODO/FIXME finding" {
  mkdir -p "$TMPDIR_HELPER/todoref/src"
  {
    pad_slash
    printf '%s\n' '// TODO(#123): handle retry'
    printf '%s\n' '// TODO 456'
    printf '%s\n' '// FIXME https://example.com/i/7'
  } > "$TMPDIR_HELPER/todoref/src/Refs.java"
  cc --gates comments "$TMPDIR_HELPER/todoref"
  [ "$RC" -eq 0 ]
  ! sho 'Comments: TODO/FIXME without an issue reference'
}

@test "AC-032-06-03: section dividers and attributions warn" {
  local base="$TMPDIR_HELPER/advisory"
  mkdir -p "$base/src"
  { pad_slash; printf '%s\n' '// =========='; } > "$base/src/Divider.java"
  { pad_hash; printf '%s\n' '# ---------'; } > "$base/src/divider.sh"
  { pad_slash; printf '%s\n' '// @author Jane Doe'; } > "$base/src/Author.java"
  { pad_slash; printf '%s\n' '// Created by Jane Doe'; } > "$base/src/Created.java"
  { pad_slash; printf '%s\n' '// -- note'; } > "$base/src/Note.java"
  cc --gates comments "$base"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Comments: section-divider comment')" -eq 2 ]
  [ "$(count_sho 'Comments: attribution comment')" -eq 2 ]
  ! sho 'Note\.java.*(section-divider|attribution)'
}

@test "AC-032-06-04: advisory findings never become FAIL" {
  mkdir -p "$TMPDIR_HELPER/todostrict/src"
  {
    pad_slash
    printf '%s\n' 'public class Retry {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // TODO: handle retry'
    printf '%s\n' '    use(1);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/todostrict/src/Retry.java"
  {
    pad_hash
    printf '%s\n' '# FIXME fix this before release'
    printf '%s\n' 'echo done'
  } > "$TMPDIR_HELPER/todostrict/src/cleanup.sh"

  cc_env STRICT_CLEAN_CODE=1 --gates comments "$TMPDIR_HELPER/todostrict"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Comments: TODO/FIXME without an issue reference'
  ! sho 'FAIL.*Comments: TODO/FIXME without an issue reference'

  cc --gates comments --blocking comments "$TMPDIR_HELPER/todostrict"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Comments: TODO/FIXME without an issue reference'
  ! sho 'FAIL.*Comments: TODO/FIXME without an issue reference'
}

# ── Task 07 — the allowlist ──────────────────────────────────────────────────

@test "AC-032-07-01: the first five lines of a file are never scanned" {
  mkdir -p "$TMPDIR_HELPER/firstfive/src"
  cat > "$TMPDIR_HELPER/firstfive/src/head.sh" <<'SH'
#!/bin/bash
# ---------
set -e
# echo "alpha";
# echo "beta";
echo done
SH
  cc --gates comments "$TMPDIR_HELPER/firstfive"
  [ "$RC" -eq 0 ]
  ! sho 'Comments:'
}

@test "AC-032-07-02: tool directives are skipped per line, and do not disable the file" {
  local base="$TMPDIR_HELPER/directives"
  mkdir -p "$base/src"
  {
    pad_hash
    printf '%s\n' '# shellcheck disable=SC2086'
    printf '%s\n' '# shellcheck disable=SC2046'
    printf '%s\n' 'echo done'
  } > "$base/src/directives.sh"
  {
    pad_hash
    printf '%s\n' '# =========='
    printf '%s\n' 'echo done'
  } > "$base/src/plain.sh"
  {
    pad_hash
    printf '%s\n' '# noqa: E501'
    printf '%s\n' '# type: ignore'
    printf '%s\n' '# pragma: no cover'
    printf '%s\n' 'echo done'
  } > "$base/src/tools.sh"
  cc --gates comments "$base"
  [ "$RC" -eq 0 ]
  ! sho 'directives\.sh'
  [ "$(count_sho 'Comments: section-divider comment')" -eq 1 ]
  sho 'Comments: section-divider comment.*plain\.sh'
  ! sho 'tools\.sh'
}

@test "AC-032-07-03: ponytail and standards markers are preserved and skipped" {
  local base="$TMPDIR_HELPER/markers"
  mkdir -p "$base/src"
  {
    pad_hash
    printf '%s\n' '# ponytail: total = 200;'
    printf '%s\n' '# return total;'
  } > "$base/src/pony.sh"
  {
    pad_hash
    printf '%s\n' '# standards:allow-comment let total = 200;'
    printf '%s\n' '# return total;'
  } > "$base/src/allow.sh"
  cc --gates comments "$base"
  [ "$RC" -eq 0 ]
  ! sho 'Comments: commented-out code'
  ! sho 'pony\.sh'
  ! sho 'allow\.sh'
  # The markers themselves are untouched by this change.
  grep -qF 'ponytail:' "$base/src/pony.sh"
  grep -qF 'standards:allow-' "$base/src/allow.sh"
}

@test "AC-032-07-04: licence markers and URLs are skipped" {
  local base="$TMPDIR_HELPER/licence"
  mkdir -p "$base/src"
  {
    pad_hash
    printf '%s\n' '# Licensed under MIT;'
    printf '%s\n' '# return total;'
  } > "$base/src/lic.sh"
  {
    pad_hash
    printf '%s\n' '# https://example.com/let total = 5;'
    printf '%s\n' '# return total;'
  } > "$base/src/url.sh"
  {
    pad_hash
    printf '%s\n' '# SPDX-License-Identifier: MIT'
    printf '%s\n' '# Copyright 2026 Acme'
  } > "$base/src/spdx.sh"
  cc --gates comments "$base"
  [ "$RC" -eq 0 ]
  ! sho 'Comments:'
}

@test "AC-032-07-05: doc blocks attached to public API are skipped; private code is not" {
  local base="$TMPDIR_HELPER/docblock"
  mkdir -p "$base/src"
  {
    pad_slash
    printf '%s\n' '/// let x = compute();'
    printf '%s\n' '/// return x;'
    printf '%s\n' 'pub fn compute() -> i32 { 1 }'
  } > "$base/src/doc.rs"
  {
    pad_slash
    printf '%s\n' '/**'
    printf '%s\n' ' * let x = 1;'
    printf '%s\n' ' * return x;'
    printf '%s\n' ' */'
    printf '%s\n' 'public void compute() { }'
  } > "$base/src/Doc.java"
  {
    pad_slash
    printf '%s\n' '// total := a + b;'
    printf '%s\n' '// return total;'
    printf '%s\n' 'func Add(a, b int) int { return a + b }'
  } > "$base/src/doc.go"
  cc --gates comments "$base"
  [ "$RC" -eq 0 ]
  ! sho 'Comments:'

  local ctl="$TMPDIR_HELPER/docblockctl"
  mkdir -p "$ctl/src"
  {
    pad_slash
    printf '%s\n' '/**'
    printf '%s\n' ' * let x = 1;'
    printf '%s\n' ' * return x;'
    printf '%s\n' ' */'
    printf '%s\n' 'private void compute() { }'
  } > "$ctl/src/Private.java"
  {
    pad_slash
    printf '%s\n' '// let x = compute();'
    printf '%s\n' '// return x;'
    printf '%s\n' 'fn compute() -> i32 { 1 }'
  } > "$ctl/src/plain.rs"
  cc --gates comments "$ctl"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Comments: commented-out code')" -eq 2 ]
  sho 'Private\.java'
  sho 'plain\.rs'
}

# ── Task 08 — severity, rollout, report routing ──────────────────────────────

@test "AC-032-08-01: default classification is WARN with exit 0" {
  mkdir -p "$TMPDIR_HELPER/strict-off/src"
  {
    pad_slash
    printf '%s\n' 'public class Strict {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // total = price * quantity;'
    printf '%s\n' '    // printTotal(total);'
    printf '%s\n' '    use(total);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/strict-off/src/Strict.java"
  cc --gates comments "$TMPDIR_HELPER/strict-off"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Comments: commented-out code'
  ! sho 'FAIL.*Comments: commented-out code'
}

@test "AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules" {
  mkdir -p "$TMPDIR_HELPER/strict-on/src"
  {
    pad_slash
    printf '%s\n' 'public class Strict {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // total = price * quantity;'
    printf '%s\n' '    // printTotal(total);'
    printf '%s\n' '    use(total);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/strict-on/src/Strict.java"
  cc_env STRICT_CLEAN_CODE=1 --gates comments "$TMPDIR_HELPER/strict-on"
  [ "$RC" -eq 1 ]
  sho 'FAIL.*Comments: commented-out code'
}

@test "AC-032-08-03: --blocking comments promotes without the environment switch" {
  mkdir -p "$TMPDIR_HELPER/blocking-comments/src"
  {
    pad_slash
    printf '%s\n' 'public class Strict {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // total = price * quantity;'
    printf '%s\n' '    // printTotal(total);'
    printf '%s\n' '    use(total);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/blocking-comments/src/Strict.java"
  cc --gates comments --blocking comments "$TMPDIR_HELPER/blocking-comments"
  [ "$RC" -eq 1 ]
  sho 'FAIL.*Comments: commented-out code'
}

@test "AC-032-08-04: only the literal value 1 promotes, and advisory rules never promote" {
  mkdir -p "$TMPDIR_HELPER/strict-values/src"
  {
    pad_slash
    printf '%s\n' 'public class Strict {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // total = price * quantity;'
    printf '%s\n' '    // printTotal(total);'
    printf '%s\n' '    use(total);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/strict-values/src/Strict.java"
  local v
  for v in 0 true ''; do
    cc_env "STRICT_CLEAN_CODE=$v" --gates comments "$TMPDIR_HELPER/strict-values"
    [ "$RC" -eq 0 ]
    sho 'WARN.*Comments: commented-out code'
  done

  mkdir -p "$TMPDIR_HELPER/strict-advisory/src"
  {
    pad_slash
    printf '%s\n' 'public class Retry {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // TODO: handle retry'
    printf '%s\n' '    use(1);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/strict-advisory/src/Retry.java"
  cc_env STRICT_CLEAN_CODE=1 --gates comments "$TMPDIR_HELPER/strict-advisory"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Comments: TODO/FIXME without an issue reference'
}

@test "AC-032-08-05: Python and Rust findings stay WARN under the strict switch" {
  mkdir -p "$TMPDIR_HELPER/strict-py/src"
  {
    pad_hash
    printf '%s\n' '# total = price * quantity;'
    printf '%s\n' '# printTotal(total);'
    printf '%s\n' 'total = 0'
  } > "$TMPDIR_HELPER/strict-py/src/strict_comments.py"
  cc_env STRICT_CLEAN_CODE=1 --gates comments "$TMPDIR_HELPER/strict-py"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Comments: commented-out code'
  ! sho 'FAIL.*Comments: commented-out code'
}

@test "AC-032-08-06: --json and -ReportPath carry the classification" {
  mkdir -p "$TMPDIR_HELPER/jsonout/src"
  {
    pad_slash
    printf '%s\n' 'public class Strict {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    // total = price * quantity;'
    printf '%s\n' '    // printTotal(total);'
    printf '%s\n' '    use(total);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/jsonout/src/Strict.java"

  cc --gates comments --json "$TMPDIR_HELPER/jsonout"
  [ "$RC" -eq 0 ]
  python3 - "$OUTF" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc["fails"] == [], doc["fails"]
hits = [w for w in doc["warns"] if "Comments: commented-out code" in w["message"]]
assert len(hits) == 1, doc["warns"]
assert hits[0]["file"], hits[0]
assert hits[0]["line"], hits[0]
PY

  cc_env STRICT_CLEAN_CODE=1 --gates comments --json "$TMPDIR_HELPER/jsonout"
  [ "$RC" -eq 1 ]
  python3 - "$OUTF" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
hits = [f for f in doc["fails"] if "Comments: commented-out code" in f["message"]]
assert len(hits) == 1, doc["fails"]
assert hits[0]["file"] and hits[0]["line"], hits[0]
PY

  local report="$TMPDIR_HELPER/report.json"
  cc --gates comments -ReportPath "$report" "$TMPDIR_HELPER/jsonout"
  [ "$RC" -eq 0 ]
  [ -f "$report" ]
  python3 - "$report" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert doc["fails"] == [], doc["fails"]
hits = [w for w in doc["warns"] if "Comments: commented-out code" in w]
assert len(hits) == 1, doc["warns"]
PY

  cc_env STRICT_CLEAN_CODE=1 --gates comments -ReportPath "$report" "$TMPDIR_HELPER/jsonout"
  [ "$RC" -eq 1 ]
  python3 - "$report" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
hits = [f for f in doc["fails"] if "Comments: commented-out code" in f]
assert len(hits) == 1, doc["fails"]
assert doc["warns"] == [] or all("commented-out code" not in w for w in doc["warns"]), doc["warns"]
PY
}

# ── Task 09 — naming gate ────────────────────────────────────────────────────

@test "AC-032-09-01: single-character identifiers fire, loop counters do not" {
  mkdir -p "$TMPDIR_HELPER/naming-single/src"
  {
    pad_slash
    printf '%s\n' 'public class Counters {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    int x = 1;'
    printf '%s\n' '    int j = 2;'
    printf '%s\n' '    for (int i = 0; i < 3; i++) { use(i); }'
    printf '%s\n' '    for (int k = 0; k < 3; k++) { use(k); }'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-single/src/Counters.java"
  cc --gates naming "$TMPDIR_HELPER/naming-single"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Naming: single-character identifier')" -eq 1 ]
  sho 'Naming: single-character identifier.*Counters\.java:8'
}

@test "AC-032-09-02: noise words fire at word boundaries only" {
  mkdir -p "$TMPDIR_HELPER/naming-noise/src"
  {
    pad_slash
    printf '%s\n' 'public class Models {'
    printf '%s\n' '}'
    printf '%s\n' 'class UserManager {'
    printf '%s\n' '}'
    printf '%s\n' 'class Data {'
    printf '%s\n' '}'
    printf '%s\n' 'class Managerial {'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-noise/src/Models.java"
  cc --gates naming "$TMPDIR_HELPER/naming-noise"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Naming: noise word in type name')" -eq 2 ]
  sho 'Naming: noise word in type name \(UserManager\)'
  sho 'Naming: noise word in type name \(Data\)'
  ! sho 'Managerial'
}

@test "AC-032-09-03: encoded identifiers fire, ordinary camelCase does not" {
  mkdir -p "$TMPDIR_HELPER/naming-encoded/src"
  {
    pad_slash
    printf '%s\n' 'public class Names {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    String strName = "a";'
    printf '%s\n' '    int iCount = 1;'
    printf '%s\n' '    int index = 2;'
    printf '%s\n' '    use(strName + iCount + index);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-encoded/src/Names.java"
  cc --gates naming "$TMPDIR_HELPER/naming-encoded"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Naming: encoded identifier')" -eq 2 ]
  sho 'Naming: encoded identifier \(strName\)'
  sho 'Naming: encoded identifier \(iCount\)'
  ! sho 'encoded identifier \(index\)'
}

@test "AC-032-09-04: boolean flag parameters fire, other booleans do not" {
  mkdir -p "$TMPDIR_HELPER/naming-bool/src"
  {
    pad_slash
    printf '%s\n' 'public class Flags {'
    printf '%s\n' '  void save(boolean hasAccess) {'
    printf '%s\n' '    use(hasAccess);'
    printf '%s\n' '  }'
    printf '%s\n' '  void load(boolean access) {'
    printf '%s\n' '    use(access);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-bool/src/Flags.java"
  {
    pad_slash
    printf '%s\n' 'export function save(hasAccess: boolean): void {'
    printf '%s\n' '  use(hasAccess);'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-bool/src/flags.ts"
  cc --gates naming "$TMPDIR_HELPER/naming-bool"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Naming: boolean flag parameter')" -eq 2 ]
  ! sho 'boolean flag parameter \(access\)'
}

@test "AC-032-09-05: more than three parameters fires at four, not at three" {
  mkdir -p "$TMPDIR_HELPER/naming-params/src"
  {
    pad_slash
    printf '%s\n' 'public class Params {'
    printf '%s\n' '  void three(int a, int b, int c) {'
    printf '%s\n' '    use(a);'
    printf '%s\n' '  }'
    printf '%s\n' '  void four(int a, int b, int c, int d) {'
    printf '%s\n' '    use(a);'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-params/src/Params.java"
  cc --gates naming "$TMPDIR_HELPER/naming-params"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Naming: more than three parameters')" -eq 1 ]
  sho 'Naming: more than three parameters \(four\)'
}

@test "AC-032-09-06: naming never emits FAIL and never scans shell" {
  mkdir -p "$TMPDIR_HELPER/naming-strict/src"
  {
    pad_slash
    printf '%s\n' 'public class Counters {'
    printf '%s\n' '  void go() {'
    printf '%s\n' '    int x = 1;'
    printf '%s\n' '    int j = 2;'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/naming-strict/src/Counters.java"
  {
    pad_hash
    printf '%s\n' 'x=1'
    printf '%s\n' 'y=2'
  } > "$TMPDIR_HELPER/naming-strict/src/vars.sh"
  cc_env STRICT_CLEAN_CODE=1 --gates naming --blocking naming "$TMPDIR_HELPER/naming-strict"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Naming: single-character identifier'
  ! sho 'FAIL.*Naming:'
  ! sho 'vars\.sh'
}

# ── Task 10 — null-discipline gate ───────────────────────────────────────────

@test "AC-032-10-01: return null is reported" {
  mkdir -p "$TMPDIR_HELPER/null-return/src"
  {
    pad_slash
    printf '%s\n' 'public class Finder {'
    printf '%s\n' '  String find() { return null; }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/null-return/src/Finder.java"
  {
    pad_slash
    printf '%s\n' 'export function f() { return null; }'
  } > "$TMPDIR_HELPER/null-return/src/finder.ts"
  cc --gates null-discipline "$TMPDIR_HELPER/null-return"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Null-discipline: return null')" -eq 2 ]
}

@test "AC-032-10-02: null arguments are reported; comparisons and assignments are not" {
  mkdir -p "$TMPDIR_HELPER/null-args/src"
  {
    pad_slash
    printf '%s\n' 'public class Discipline {'
    printf '%s\n' '  Object helper(Object o) { return o; }'
    printf '%s\n' '  void go(Object x, Object c) {'
    printf '%s\n' '    helper(null);'
    printf '%s\n' '    helper(1, null);'
    printf '%s\n' '    return x == null;'
    printf '%s\n' '    Object s = null;'
    printf '%s\n' '    return c ? this : null;'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/null-args/src/Discipline.java"
  cc --gates null-discipline "$TMPDIR_HELPER/null-args"
  [ "$RC" -eq 0 ]
  [ "$(count_sho 'Null-discipline: null argument')" -eq 2 ]
  [ "$(count_sho 'Null-discipline: return null')" -eq 0 ]
  [ "$(count_sho 'Null-discipline:')" -eq 2 ]
}

@test "AC-032-10-03: Python and Rust are not scanned" {
  mkdir -p "$TMPDIR_HELPER/null-langs/src"
  {
    pad_hash
    printf '%s\n' 'def f():'
    printf '%s\n' '    return None'
    printf '%s\n' 'helper(None)'
  } > "$TMPDIR_HELPER/null-langs/src/nulls.py"
  {
    pad_slash
    printf '%s\n' 'fn f() -> Option<u8> { None }'
  } > "$TMPDIR_HELPER/null-langs/src/nulls.rs"
  cc --gates null-discipline "$TMPDIR_HELPER/null-langs"
  [ "$RC" -eq 0 ]
  ! sho 'Null-discipline:'
}

@test "AC-032-10-04: null findings never become FAIL" {
  mkdir -p "$TMPDIR_HELPER/null-strict/src"
  {
    pad_slash
    printf '%s\n' 'public class Finder {'
    printf '%s\n' '  String find() { return null; }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/null-strict/src/Finder.java"
  cc_env STRICT_CLEAN_CODE=1 --gates null-discipline --blocking null-discipline \
    "$TMPDIR_HELPER/null-strict"
  [ "$RC" -eq 0 ]
  sho 'WARN.*Null-discipline: return null'
  ! sho 'FAIL.*Null-discipline:'
}

# ── Task 11 — catalog consumer sync ──────────────────────────────────────────

@test "AC-032-11-01: gate consistency passes with nine gates" {
  if ( cd "$REPO_ROOT" && bash "$CONSISTENCY" >"$OUTF" 2>"$ERRF" ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  sho 'Canonical gate list \(from check-code-principles\.sh\): complexity,dry,yagni,solid,component-per-file,property-tests,comments,naming,null-discipline'
  sho 'Check 4: gate count = 9 \(expected 9\)'
  sho 'PASS — 9 gates'
  ! sho 'FAIL —'
}

@test "AC-032-11-02: the blame suite reflects that naming is now a gate" {
  if ( cd "$REPO_ROOT" && bash "$BLAME" >"$OUTF" 2>"$ERRF" ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  [ "$(grep -cE '^FAIL' "$OUTF" || true)" -eq 0 ]
  ! grep -qF "unknown gate name in blocking set: 'naming'" "$BLAME"
  grep -qF "unknown gate name in blocking set: 'test-delta'" "$BLAME"
  grep -qF 'spec 032' "$BLAME"
  grep -qF 'complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline' "$BLAME"
  grep -qF 'AC-011-03-01' "$BLAME"
  grep -qF 'AC-011-03-08' "$BLAME"
}

@test "AC-032-11-03: CODING_CONVENTIONS documents the new gates" {
  local design
  design="$(section_of "$CONVENTIONS" 'Design Principles')"
  printf '%s\n' "$design" | grep -qF 'comments'
  printf '%s\n' "$design" | grep -qF 'naming'
  printf '%s\n' "$design" | grep -qF 'null-discipline'
  printf '%s\n' "$design" | grep -qiF 'WARN by default'
  printf '%s\n' "$design" | grep -qF 'STRICT_CLEAN_CODE=1'
  printf '%s\n' "$design" | grep -qF 'docs/adr/0013-clean-code-comment-gates.md'
  grep -qF 'Comment the why, not the what' "$CONVENTIONS"
}

@test "AC-032-11-04: the check-principles skill lists all nine gates" {
  grep -qF 'comments' "$SKILL"
  grep -qF 'naming' "$SKILL"
  grep -qF 'null-discipline' "$SKILL"
  grep -qF 'STRICT_CLEAN_CODE' "$SKILL"
  ! grep -qF 'five gate categories' "$SKILL"
  grep -qE '^\| comments \|' "$SKILL"
  grep -qE '^\| naming \|' "$SKILL"
  grep -qE '^\| null-discipline \|' "$SKILL"
  grep -qF 'complexity,property-tests' "$SKILL"
  grep -qiF 'warn-only' "$SKILL"
  grep -qF -- '-BaseRef' "$SKILL"
  grep -qF -- '--blocking' "$SKILL"
}

# ── Task 12 — fixture proof, wiring, regression ──────────────────────────────

@test "AC-032-12-01: the selftest proves each new rule and each allowlist control" {
  if ( cd "$REPO_ROOT" && bash "$SELFTEST" >"$OUTF" 2>"$ERRF" ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  local group
  for group in comments-out-code comments-restate comments-advisory comments-allowlist \
    naming-heuristics null-discipline; do
    grep -qE "PASS.*${group}" "$OUTF"
  done
  grep -qE 'PASS.*AC-032-' "$OUTF"
  grep -qF 'AC-032-' "$SELFTEST"
  grep -qF 'mktemp -d' "$SELFTEST"
}

@test "AC-032-12-02: the new scenarios run as bats tests and are not vacuous" {
  local self="$REPO_ROOT/scripts/tests/check-code-principles-clean-code.bats"
  [ -f "$self" ]
  # One citing test per new-gate task (04-10).
  local t
  for t in 04 05 06 07 08 09 10; do
    grep -qE "@test \"AC-032-${t}-[0-9]{2}:" "$self"
  done
  # The non-recursive part of this scenario: the file is well-formed bats that
  # asserts, and the new-gate scenarios themselves pass when run as bats.
  if ( cd "$REPO_ROOT" && bash scripts/check-bats-assertions.sh >"$OUTF" 2>"$ERRF" ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  if bats --tap --filter '^AC-032-(0[4-9]|10)-' "$self" >"$OUTF" 2>"$ERRF"; then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  ! grep -q 'not ok' "$OUTF"
  # `make test-scripts` owns the glob that picks this file up.
  grep -qF 'bats --tap scripts/tests/*.bats' "$REPO_ROOT/Makefile"
}

@test "AC-032-12-03: the new gates cannot turn the repository red on day one" {
  if ( cd "$REPO_ROOT" && bash "$CHECKER" --gates comments,naming,null-discipline . >"$OUTF" 2>"$ERRF" ); then
    RC=0
  else
    RC=$?
  fi
  [ "$RC" -eq 0 ]
  ! sho 'FAIL.*(Comments|Naming|Null-discipline):'
  sho '^--- Comments ---$'
  sho '^--- Naming ---$'
  sho '^--- Null discipline ---$'
  local line
  line="$(grep -cE '(PASS|WARN).*(Comments|Naming|Null-discipline)' "$OUTF" || true)"
  [ "$line" -ge 3 ]
}

@test "AC-032-12-04: existing gate behavior is unchanged" {
  mkdir -p "$TMPDIR_HELPER/cc7/src"
  {
    pad_slash
    printf '%s\n' 'public class Cc7 {'
    printf '%s\n' '  void decide(int a, int b) {'
    printf '%s\n' '    if (a == 1) { use(1); }'
    printf '%s\n' '    if (a == 2) { use(2); }'
    printf '%s\n' '    if (a == 3) { use(3); }'
    printf '%s\n' '    if (a == 4) { use(4); }'
    printf '%s\n' '    if (a == 5) { use(5); }'
    printf '%s\n' '    if (a == 6) { use(6); }'
    printf '%s\n' '    if (a == 7) { use(7); }'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/cc7/src/Cc7.java"
  cc --gates complexity "$TMPDIR_HELPER/cc7"
  [ "$RC" -eq 1 ]
  sho 'Cyclomatic complexity >6'

  mkdir -p "$TMPDIR_HELPER/cc6/src"
  {
    pad_slash
    printf '%s\n' 'public class Cc6 {'
    printf '%s\n' '  void decide(int a) {'
    printf '%s\n' '    if (a == 1) { use(1); }'
    printf '%s\n' '    if (a == 2) { use(2); }'
    printf '%s\n' '    if (a == 3) { use(3); }'
    printf '%s\n' '    if (a == 4) { use(4); }'
    printf '%s\n' '    if (a == 5) { use(5); }'
    printf '%s\n' '  }'
    printf '%s\n' '}'
  } > "$TMPDIR_HELPER/cc6/src/Cc6.java"
  cc --gates complexity "$TMPDIR_HELPER/cc6"
  [ "$RC" -eq 0 ]
  ! sho 'Cyclomatic complexity'

  if ( cd "$REPO_ROOT" && bash "$SELFTEST" >/dev/null 2>&1 ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  if ( cd "$REPO_ROOT" && bash "$BLAME" >/dev/null 2>&1 ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  if ( cd "$REPO_ROOT" && bash "$CONSISTENCY" >/dev/null 2>&1 ); then RC=0; else RC=$?; fi
  [ "$RC" -eq 0 ]
  grep -qF '> 6' "$CHECKER"
  ! grep -qF -- '--threshold' "$CHECKER"
  ! grep -qF -- '--complexity' "$CHECKER"
}
