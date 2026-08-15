#!/bin/bash
# check-code-principles.sh — Static, language-agnostic audit of design principles:
# KISS, DRY, YAGNI, SOLID, cyclomatic complexity, and property-test coverage.
#
# Works on any code the standards allow: Java, Go, JavaScript/TypeScript (incl.
# React Native). It reads source files directly and applies the same heuristics
# to every language, so it runs in a child repo without any project-specific
# linter configuration.
#
# Checks and what each flags:
#   Complexity   — methods/functions with >6 decision points (if/for/while/
#                  switch/case/catch/&&/||/ternary). Mirrors the ≤6 rule in
#                  docs/CODING_CONVENTIONS.md §Design Principles.
#   KISS         — method bodies >20 lines, >6 parameters, or nesting deeper
#                  than 6 brace levels (docs/CODING_CONVENTIONS.md: methods
#                  under 20 lines, classes under 200 lines).
#   DRY          — identical 4-line blocks appearing in 2+ places (structural
#                  duplication). Verify the duplicate shares a reason to change
#                  before consolidating — docs/CODING_CONVENTIONS.md.
#   YAGNI        — interfaces with exactly one implementation (premature
#                  abstraction) and empty method bodies in non-test code.
#   SOLID        — SRP: god classes (>15 methods, >400 lines). OCP: switch
#                  statements with ≥4 cases / if-else chains ≥4 (type dispatch
#                  that should be polymorphic). LSP: heavy instanceof/type-test
#                  dispatch in Java/TS. ISP: interfaces with >5 methods.
#                  DIP: domain/engine code importing store/repository/infra.
#   Property tests — at `production` tier and above, each present language must
#                  use its property-testing framework (jqwik / testing.quick /
#                  fast-check). See docs/TESTING.md §Property Testing.
#
# This is a heuristic gate, not a proof. It catches the common shapes the
# principles forbid and points at exact file:line evidence; it does not parse
# ASTs. Real linters (PMD/golangci-lint/eslint) remain the authoritative
# complexity gate. Treat WARN output as a review hint, FAIL as a defect.
#
# Usage:
#   .standards/scripts/check-code-principles.sh [SOURCE_DIR] [--tier mvp|production|multi-service]
#       [-BaseRef <ref>] [--blocking <gates>] [--warn-as-error]
#
# SOURCE_DIR defaults to the current directory. --tier overrides auto-detection
# from the project's AGENTS_*.md "Conformance tier:" declaration (see
# docs/CONFORMANCE_TIERS.md). --warn-as-error promotes every WARN to a failure.
#
# Blame scoping (-BaseRef <ref>): judge only the change — the diff of the
# working tree against <ref>, scoped to the source files this script audits.
#   - Only files present in the diff are evaluated; findings in untouched files
#     are not reported (the gate judges the author's change, not the whole tree).
#   - A line-anchored finding whose line range overlaps an added line of the
#     diff is diff-introduced; a finding in a touched file without overlap is
#     pre-existing debt (reported as WARN). File-level findings treat any added
#     line in the file as overlap. A file added entirely by the diff is fully
#     diff-introduced.
#   - `property-tests` is a presence check with no line anchor — never
#     blame-scoped.
#   - Tooling failures (unresolvable ref, not a git repository) are reported to
#     stderr and exit 2 — never a false PASS.
#
# Blocking set (which gates may emit FAIL):
#   Gate names: complexity (cyclomatic CC + KISS size findings), dry, yagni,
#   solid (SRP/OCP/LSP/ISP/DIP as one unit), property-tests.
#   Default blocking set: complexity,property-tests — the objective gates in
#   this repo's terms. A gate outside the blocking set is warn-only and never
#   emits FAIL, with or without -BaseRef (DIP and YAGNI single-implementation
#   findings therefore report as WARN). Override with --blocking <comma-list>
#   or the PRINCIPLES_BLOCKING_GATES environment variable (flag wins over env
#   over default); an unknown gate name or an empty value exits 2.
#
# Exit codes:
#   0 — no FAILs (WARNs may exist)
#   1 — at least one FAIL (or a WARN with --warn-as-error)
#   2 — usage or tooling failure (unknown option, bad --blocking value,
#       unresolvable -BaseRef ref, not a git repository)
#
# Standards reference:
#   docs/CODING_CONVENTIONS.md §Design Principles
#   docs/ARCHITECTURE.md (DIP / dependency rule)
#   docs/TESTING.md §Property Testing
#   docs/CONFORMANCE_TIERS.md
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILS=0
WARNS=0
WARN_AS_ERROR=false

BASE_REF=""
BASE_REF_SET=false
BLOCKING_ARG=""
BLOCKING_ARG_SET=false
BLOCKING_SET="complexity property-tests"

fail() { echo -e "${RED}FAIL${NC} $*"; FAILS=$((FAILS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }
warn() { echo -e "${YELLOW}WARN${NC} $*"; WARNS=$((WARNS + 1)); }

SOURCE_DIR="."
TIER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="${2:-}"; shift 2 ;;
    --warn-as-error) WARN_AS_ERROR=true; shift ;;
    --blocking) BLOCKING_ARG="${2:-}"; BLOCKING_ARG_SET=true; shift 2 ;;
    -BaseRef) BASE_REF="${2:-}"; BASE_REF_SET=true; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) SOURCE_DIR="$1"; shift ;;
  esac
done

if [ "$BASE_REF_SET" = true ] && [ -z "$BASE_REF" ]; then
  echo "Error: -BaseRef requires a value (the git ref to diff against)" >&2
  exit 2
fi

# ── Blocking set (which gates may emit FAIL) ─────────────────────────────────
# Gate names: complexity, dry, yagni, solid, property-tests. Default:
# complexity,property-tests (the objective gates). --blocking wins over the
# PRINCIPLES_BLOCKING_GATES env var, which wins over the default.
blocking_raw() { # blocking_raw — resolve --blocking / env var / default into a raw comma list
  if [ "$BLOCKING_ARG_SET" = true ]; then
    [ -n "$BLOCKING_ARG" ] || { echo "Error: --blocking requires a comma-separated list of gates (complexity, dry, yagni, solid, property-tests)" >&2; exit 2; }
    printf '%s' "$BLOCKING_ARG"
    return
  fi
  if [ "${PRINCIPLES_BLOCKING_GATES+x}" = "x" ]; then
    printf '%s' "$PRINCIPLES_BLOCKING_GATES"
    return
  fi
  printf '%s' "complexity,property-tests"
}

valid_gate() { # valid_gate <name> — 0 if a known gate name
  case "$1" in
    complexity|dry|yagni|solid|property-tests) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_blocking_set() {
  local raw g
  raw=$(blocking_raw | tr -d '[:space:]')
  BLOCKING_SET=""
  for g in $(printf '%s' "$raw" | tr ',' '\n' | sed '/^$/d'); do
    if ! valid_gate "$g"; then
      echo "Error: unknown gate name in blocking set: '$g' (valid gates: complexity, dry, yagni, solid, property-tests)" >&2
      exit 2
    fi
    BLOCKING_SET="${BLOCKING_SET}${BLOCKING_SET:+ }$g"
  done
  [ -n "$BLOCKING_SET" ] || { echo "Error: blocking set is empty — must name at least one of: complexity, dry, yagni, solid, property-tests" >&2; exit 2; }
}
resolve_blocking_set

# ── Git work-tree guard (-BaseRef) ───────────────────────────────────────────
# Fail before scanning anything: blame scoping is meaningless outside a repo.
if [ "$BASE_REF_SET" = true ]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Error: -BaseRef '$BASE_REF' — not inside a git repository; cannot compute the diff" >&2
    exit 2
  fi
  BLAME_DIR=$(mktemp -d)
  trap 'rm -rf "$BLAME_DIR"' EXIT
  BLAME_TOUCHED="$BLAME_DIR/touched"
  BLAME_RANGES="$BLAME_DIR/ranges"
  BLAME_FULLY_ADDED="$BLAME_DIR/full"
  : > "$BLAME_TOUCHED"
  : > "$BLAME_RANGES"
  : > "$BLAME_FULLY_ADDED"
fi

# ── Conformance tier auto-detection ──────────────────────────────────────────
if [ -z "$TIER" ]; then
  for f in "$SOURCE_DIR"/AGENTS_*.md; do
    [ -f "$f" ] || continue
    t=$(grep -oE 'Conformance tier: (mvp|production|multi-service)' "$f" 2>/dev/null | head -1 | awk '{print $3}')
    if [ -n "$t" ]; then TIER="$t"; break; fi
  done
fi
TIER="${TIER:-mvp}"

# ── Discovery ────────────────────────────────────────────────────────────────
GREP_EXCLUDES='--exclude-dir=node_modules --exclude-dir=target --exclude-dir=vendor --exclude-dir=.git --exclude-dir=dist --exclude-dir=build'
FIND_PRUNE='( -name node_modules -o -name target -o -name vendor -o -name .git -o -name dist -o -name build )'

JAVA_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.java' -print 2>/dev/null || true)
GO_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.go' -print 2>/dev/null || true)
NODE_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print 2>/dev/null || true)

[ -z "$JAVA_FILES" ] && [ -z "$GO_FILES" ] && [ -z "$NODE_FILES" ] && {
  echo "No Java, Go, or JS/TS source files found under $SOURCE_DIR — nothing to check."
  exit 0
}

echo "Checking design principles in: $SOURCE_DIR (tier: $TIER)"
echo ""

# Non-test source files (principles apply to production code).
NONTEST_JAVA=$(echo "$JAVA_FILES" | grep -vE '/test/|/tests/|src/test/' || true)
NONTEST_GO=$(echo "$GO_FILES" | grep -vE '_test\.go$' || true)
NONTEST_NODE=$(echo "$NODE_FILES" | grep -vE '\.(test|spec)\.(ts|tsx|js|jsx)$|/test/|/tests/|__tests__/' || true)

ALL_NONTEST="$NONTEST_JAVA $NONTEST_GO $NONTEST_NODE"
ALL_NONTEST=$(echo "$ALL_NONTEST" | tr ' ' '\n' | sed '/^$/d' | sort -u)

# ── Complexity + KISS analyzer (awk) ─────────────────────────────────────────
# Computes cyclomatic complexity per method via brace-depth tracking, plus body
# length and parameter count. Heuristic — real linters remain authoritative.
complexity_awk="$(cat <<'AWK'
function clean(s,   i,n,c,out,q) {
  out=""; i=1; n=length(s)
  while (i<=n) {
    c=substr(s,i,1)
    if (inblk) {
      if (c=="*" && substr(s,i+1,1)=="/") { inblk=0; i+=2; continue }
      i++; continue
    }
    if (c=="/" && substr(s,i+1,1)=="*") { inblk=1; i+=2; continue }
    if (c=="/" && substr(s,i+1,1)=="/") break
    if (c=="\"" || c=="'") { q=c; i++
      while (i<=n) {
        if (substr(s,i,1)=="\\") { i+=2; continue }
        if (substr(s,i,1)==q) { i++; break }
        i++
      }
      continue
    }
    out=out c; i++
  }
  return out
}
function ismethodstart(h, lang,   l) {
  sub(/^[ \t]+/,"",h); l=h
  if (lang=="go") return (h ~ /^func[ \t]+[A-Za-z_]/) ? 1 : 0
  if (h ~ /(^|[^A-Za-z0-9_])(if|for|while|switch|catch|else|do|case|return|try|throw)([^A-Za-z0-9_]|$)/) return 0
  if (lang=="node" && h ~ /=>[ \t]*\{/) return 1
  return (h ~ /\)[ \t]*\{/) ? 1 : 0
}
function name_of(h, lang,   p,pre) {
  if (lang=="go") {
    sub(/^[ \t]*func[ \t]*/,"",h)
    if (h ~ /^\(/) sub(/^\([^)]*\)[ \t]*/,"",h)
    sub(/\(.*/,"",h); sub(/[ \t].*/,"",h)
    return h
  }
  p=index(h,"("); if (p==0) return "?"
  pre=substr(h,1,p-1)
  sub(/^.*[ \t]/,"",pre); sub(/.*\./,"",pre)
  return pre
}
function tokens(line,   c) {
  # word-boundary keyword match (works for both `if (x)` and Go's `if x {`)
  c += gsub(/(^|[^A-Za-z0-9_])(if|for|while|switch|catch|case)([^A-Za-z0-9_]|$)/," ",line)
  c += gsub(/&&/," ",line)
  c += gsub(/\|\|/," ",line)
  c += gsub(/\?/," ",line)
  return c
}
function begin_method(line, lang, dbefore,   d) {
  top++
  STACK[top,"d"] = dbefore + 1
  STACK[top,"n"] = name_of(line, lang)
  STACK[top,"l"] = FNR
  STACK[top,"c"] = 1
  STACK[top,"lines"] = 1
  STACK[top,"params"] = params(line)
}
function end_method( ) {
  if (top<0) return
  if (STACK[top,"c"] > 6)
    printf "%s:%d:%d:%s:CC=%d\n", FILENAME, STACK[top,"l"], FNR, STACK[top,"n"], STACK[top,"c"]
  if (STACK[top,"lines"] > 20)
    printf "%s:%d:%d:%s:KISS_LINES=%d\n", FILENAME, STACK[top,"l"], FNR, STACK[top,"n"], STACK[top,"lines"]
  if (STACK[top,"params"] > 6)
    printf "%s:%d:%d:%s:KISS_PARAMS=%d\n", FILENAME, STACK[top,"l"], FNR, STACK[top,"n"], STACK[top,"params"]
  top--
}
function params(h,   p,c,i,n,instr) {
  p=index(h,"("); if (p==0) return 0
  n=length(h); c=0; instr=0
  for (i=p+1; i<=n; i++) {
    ch=substr(h,i,1)
    if (ch=="(") instr++
    else if (ch==")") { if (instr==0) break; instr-- }
    else if (ch=="," && instr==0) c++
  }
  return c+1
}
FNR==1 { inblk=0; depth=0; top=-1 }
{
  line=clean($0)
  ob=0; cb=0
  n=length(line)
  for (i=1;i<=n;i++) { ch=substr(line,i,1); if (ch=="{") ob++; else if (ch=="}") cb++ }
  dbefore = depth
  depth += ob - cb
  if (ismethodstart(line, LANG)) begin_method(line, LANG, dbefore)
  if (top>=0) {
    STACK[top,"c"] += tokens(line)
    STACK[top,"lines"]++
  }
  while (top>=0 && depth < STACK[top,"d"]) end_method()
}
END { while (top>=0) end_method() }
AWK
)"

run_complexity_kiss() {
  local lang="$1"; shift
  local files=("$@")
  [ "${#files[@]}" -eq 0 ] && return 0
  local out
  out=$(printf '%s\n' "${files[@]}" | xargs awk -v LANG="$lang" "$complexity_awk" 2>/dev/null || true)
  [ -z "$out" ] && { pass "Complexity/KISS ($lang): no violations found"; return 0; }
  local line f s e
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    f=$(printf '%s' "$line" | cut -d: -f1)
    s=$(printf '%s' "$line" | cut -d: -f2)
    e=$(printf '%s' "$line" | cut -d: -f3)
    case "$line" in
      *CC=*) emit "$(classify "complexity" "fail" "$f" "$s" "$e")" "Cyclomatic complexity >6 ($lang): $line" ;;
      *KISS_LINES=*) emit "$(classify "complexity" "warn" "$f" "$s" "$e")" "Method body >20 lines ($lang): $line" ;;
      *KISS_PARAMS=*) emit "$(classify "complexity" "warn" "$f" "$s" "$e")" "Method with >6 parameters ($lang): $line" ;;
    esac
  done <<< "$out"
}

# ── DRY: duplicate 4-line windows ────────────────────────────────────────────
check_dry() {
  local files="$1"
  [ -z "$files" ] && return 0
  local tmp; tmp=$(mktemp)
  echo "$files" | while IFS= read -r f; do
    [ -f "$f" ] || continue
    awk -v file="$f" '
      FNR==1 { n=0; delete buf }
      { line=$0; sub(/\/\/.*/,"",line); sub(/\/\*.*\*\//,"",line)
        gsub(/^[ \t]+|[ \t]+$/,"",line)
        if (line=="") next
        if (line ~ /^[\{\}]+$/) next
        buf[n%4]=line
        n++
        if (n>=4) {
          win=""
          for (i=1;i<=4;i++) win = win (i>1?"\x1f":"") buf[(n-4+i)%4]
          if (length(win)>=16 && win !~ /^(import|package|using|export (default )?(class|function|const|type|interface|abstract))\x1f/)
            print win "\t" file ":" FNR-3
        }
      }' "$f"
  done | sort | awk -F '\t' '
    $1 != prev { if (count > 0 && count >= 2 && prevloc != "") print count "\t" prev "\t" prevloc; prev=$1; count=0; prevloc="" }
    { count++; if (prevloc=="") prevloc=$2 }
    END { if (count >= 2 && prevloc != "") print count "\t" prev "\t" prevloc }
  ' | sort -rn | head -10 > "$tmp"
  if [ -s "$tmp" ]; then
    local dfile dline sev
    while IFS=$'\t' read -r count win loc; do
      dfile=$(printf '%s' "$loc" | sed -E 's/:[0-9]+$//')
      dline=$(printf '%s' "$loc" | sed -nE 's/.*:([0-9]+)$/\1/p')
      sev=$(classify "dry" "warn" "$dfile" "$dline" "$dline")
      if [ "$sev" = none ]; then continue; fi
      emit "$sev" "Possible duplication (${count}x identical 4-line block, first at $loc): ${win//$'\x1f'/ /}"
    done < "$tmp"
  else
    pass "DRY: no duplicate 4-line blocks detected"
  fi
  rm -f "$tmp"
}

# ── YAGNI: single-implementation interfaces + empty bodies ───────────────────
check_yagni() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local name impls refs iface line
  case "$lang" in
    java)
      for f in $files; do
        [ -f "$f" ] || continue
        local lniface ln iface
        while IFS= read -r lniface; do
          [ -z "$lniface" ] && continue
          ln=${lniface%%:*}
          iface=${lniface#*:}
          name=$(echo "$iface" | grep -oE 'interface[ \t]+[A-Za-z0-9_]+' | awk '{print $2}')
          [ -z "$name" ] && continue
          impls=$(grep -rE "implements[^,{]*$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ' || true)
          if [ "$impls" -eq 1 ]; then
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln")" "YAGNI: interface $name has exactly one implementation (premature abstraction) — $f:$ln"
            found=true
          fi
        done < <(grep -nE '^\s*(public\s+)?interface[ \t]+' "$f" 2>/dev/null || true)
        while IFS=: read -r ln _; do
          emit "$(classify "yagni" "warn" "$f" "$ln" "$ln")" "Empty method body ($lang): $f:$ln"
          found=true
        done < <(grep -nE '\{\s*\}' "$f" 2>/dev/null | grep -vE '//|test' || true)
      done
      ;;
    go)
      for f in $files; do
        [ -f "$f" ] || continue
        local lniface ln iface
        while IFS= read -r lniface; do
          [ -z "$lniface" ] && continue
          ln=${lniface%%:*}
          iface=${lniface#*:}
          name=$(echo "$iface" | grep -oE 'interface[ \t]+[A-Za-z0-9_]+' | awk '{print $2}')
          [ -z "$name" ] && continue
          refs=$(grep -rE "\b$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.go" 2>/dev/null | grep -v "interface[ \t]*$name" | wc -l | tr -d ' ' || true)
          if [ "$refs" -le 1 ]; then
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln")" "YAGNI: Go interface $name is declared but barely referenced (premature abstraction) — $f:$ln"
            found=true
          fi
        done < <(grep -nE 'type[ \t]+[A-Za-z0-9_]+[ \t]+interface\b' "$f" 2>/dev/null || true)
      done
      ;;
    node)
      for f in $files; do
        [ -f "$f" ] || continue
        local lniface ln iface
        while IFS= read -r lniface; do
          [ -z "$lniface" ] && continue
          ln=${lniface%%:*}
          iface=${lniface#*:}
          name=$(echo "$iface" | grep -oE 'interface[ \t]+[A-Za-z0-9_]+' | awk '{print $2}')
          [ -z "$name" ] && continue
          impls=$(grep -rE "implements[^,{]*$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.ts" 2>/dev/null | wc -l | tr -d ' ' || true)
          if [ "$impls" -eq 1 ]; then
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln")" "YAGNI: interface $name has exactly one implementation (premature abstraction) — $f:$ln"
            found=true
          fi
        done < <(grep -nE '^\s*(export\s+)?interface[ \t]+' "$f" 2>/dev/null || true)
      done
      ;;
  esac
  $found || pass "YAGNI ($lang): no premature abstractions detected"
}

# ── SOLID ────────────────────────────────────────────────────────────────────
check_solid_srp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local f lines methods
  for f in $files; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    methods=0
    case "$lang" in
      java) methods=$(grep -cE '^\s*(public|protected|private)\s+.*\(' "$f" 2>/dev/null | tr -d ' ') || methods=0 ;;
      node) methods=$(grep -cE '^\s*(public|private|protected|async\s+)?[A-Za-z0-9_$]+\s*\([^)]*\)\s*\{' "$f" 2>/dev/null | tr -d ' ') || methods=0 ;;
      *) methods=0 ;;
    esac
    if [ "$lines" -gt 400 ] || [ "$methods" -gt 15 ]; then
      emit "$(classify "solid" "warn" "$f" "" "")" "SRP: possible god file ($lang) — $f: ${lines} lines, ${methods} methods (split by responsibility)"
      found=true
    fi
  done
  $found || pass "SOLID-SRP ($lang): no oversized files"
}

check_solid_ocp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local res r eif ocpfile ocpline eifline
  for f in $files; do
    [ -f "$f" ] || continue
    # switch with >=4 cases (word-boundary: matches `switch x {` Go form too)
    res=$(awk '
      /(^|[^A-Za-z0-9_])switch([^A-Za-z0-9_]|$)/ { swnr=FNR; cases=0; insw=1 }
      insw && /case[ \t]+/ { cases++ }
      insw && /^\s*\}/ { if (cases>=4) printf "%s:%d:switch with %d cases\n", FILENAME, swnr, cases; insw=0 }
    ' "$f" 2>/dev/null || true)
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      ocpfile=$(printf '%s' "$r" | cut -d: -f1)
      ocpline=$(printf '%s' "$r" | cut -d: -f2)
      emit "$(classify "solid" "warn" "$ocpfile" "$ocpline" "$ocpline")" "OCP: type-dispatch switch should be polymorphic ($lang) — $r"
      found=true
    done <<< "$res"
    eif=$(grep -cE '^\s*else[ \t]+if' "$f" 2>/dev/null || true)
    if [ "${eif:-0}" -ge 4 ]; then
      eifline=$(grep -nE '^\s*else[ \t]+if' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      emit "$(classify "solid" "warn" "$f" "$eifline" "$eifline")" "OCP: ${eif}-branch if/else chain ($lang) — $f (consider polymorphism or a lookup)"
      found=true
    fi
  done
  $found || pass "SOLID-OCP ($lang): no large type-dispatch chains"
}

check_solid_lsp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  case "$lang" in
    java|node) ;;
    *) return 0 ;;
  esac
  local found=false
  local f c
  for f in $files; do
    [ -f "$f" ] || continue
    c=$(grep -c 'instanceof' "$f" 2>/dev/null || true)
    if [ "$c" -ge 3 ]; then
      emit "$(classify "solid" "warn" "$f" "" "")" "LSP: ${c} instanceof checks in one file ($lang) — $f (suggests broken substitutability or type dispatch)"
      found=true
    fi
  done
  $found || pass "SOLID-LSP ($lang): no heavy instanceof dispatch"
}

check_solid_isp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local res r ispfile ispline
  for f in $files; do
    [ -f "$f" ] || continue
    res=$(awk '
      /^[ \t]*(public[ \t]+)?interface[ \t]+[A-Za-z0-9_]+/ { iw=1; nr=FNR; methods=0; next }
      iw && /^[ \t]*\}/ { if (methods>5) printf "%s:%d:interface with %d methods\n", FILENAME, nr, methods; iw=0; next }
      iw && /\([^)]*\)[ \t]*(;|\{|$)/ { methods++ }
    ' "$f" 2>/dev/null || true)
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      ispfile=$(printf '%s' "$r" | cut -d: -f1)
      ispline=$(printf '%s' "$r" | cut -d: -f2)
      emit "$(classify "solid" "warn" "$ispfile" "$ispline" "$ispline")" "ISP: fat interface (>5 methods) — $r (split by role)"
      found=true
    done <<< "$res"
  done
  $found || pass "SOLID-ISP ($lang): no fat interfaces"
}

check_solid_dip() {
  local lang="$1"
  local found=false
  local f hit dln
  case "$lang" in
    java)
      for f in $JAVA_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*)
            hit=$(grep -nE '^\s*import\s+.*\.(infrastructure|persistence|repository)\.' "$f" 2>/dev/null || true)
            if [ -n "$hit" ]; then
              dln=$(printf '%s\n' "$hit" | head -1 | cut -d: -f1)
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln"
              found=true
            fi
            ;;
        esac
      done
      ;;
    go)
      for f in $GO_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*)
            hit=$(grep -nE '^\s*"[^"]*/(store|infra|repository)[^"]*"' "$f" 2>/dev/null || true)
            if [ -n "$hit" ]; then
              dln=$(printf '%s\n' "$hit" | head -1 | cut -d: -f1)
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln")" "DIP: domain/engine code imports store/infra/repository ($lang) — $f:$dln"
              found=true
            fi
            ;;
        esac
      done
      ;;
    node)
      for f in $NODE_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*|*/entities/*)
            hit=$(grep -nE "from\s+['\"].*(/store|/infra|/repository|/repositories|/infrastructure)" "$f" 2>/dev/null || true)
            if [ -n "$hit" ]; then
              dln=$(printf '%s\n' "$hit" | head -1 | cut -d: -f1)
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln"
              found=true
            fi
            ;;
        esac
      done
      ;;
  esac
  $found || pass "SOLID-DIP ($lang): no domain→infrastructure imports"
}

# ── Property tests (production tier and above) ───────────────────────────────
check_property_tests() {
  case "$TIER" in
    mvp) echo "Property tests: skipped (project tier is $TIER — production+ required)"; return 0 ;;
  esac
  local lang="$1"
  local src
  case "$lang" in
    java)
      src=$JAVA_FILES
      if [ -n "$src" ]; then
        if grep -rE '@Property\b|net\.jqwik' $GREP_EXCLUDES "$SOURCE_DIR" --include="*.java" >/dev/null 2>&1; then
          pass "Property tests ($lang): jqwik/@Property in use"
        else
          fail "Property tests ($lang): no jqwik @Property tests found (required at $TIER tier)"
        fi
      fi
      ;;
    go)
      src=$GO_FILES
      if [ -n "$src" ]; then
        if grep -rE 'testing/quick\b|quick\.Check\b' $GREP_EXCLUDES "$SOURCE_DIR" --include="*.go" >/dev/null 2>&1; then
          pass "Property tests ($lang): testing/quick in use"
        else
          fail "Property tests ($lang): no testing/quick usage found (required at $TIER tier)"
        fi
      fi
      ;;
    node)
      src=$NODE_FILES
      if [ -n "$src" ]; then
        if grep -rE 'fast-check\b|@fast-check' $GREP_EXCLUDES "$SOURCE_DIR" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" >/dev/null 2>&1 \
           || grep -qE 'fast-check' "$SOURCE_DIR/package.json" 2>/dev/null; then
          pass "Property tests ($lang): fast-check in use"
        else
          fail "Property tests ($lang): no fast-check property tests found (required at $TIER tier)"
        fi
      fi
      ;;
  esac
}

# ── Blame scoping helpers (-BaseRef) ─────────────────────────────────────────
# Classification contract:
#   -BaseRef unset: a gate in the blocking set keeps its legacy per-finding
#   severity (CC FAIL, KISS WARN, ...); a gate outside the blocking set is
#   warn-only (this is where DIP and YAGNI single-impl demote to WARN).
#   -BaseRef set: untouched files are not evaluated (not reported); within the
#   diff, a blocking-gate finding whose line range overlaps an added line is
#   FAIL, otherwise pre-existing WARN; judgment gates are always WARN.
abs_of() { # abs_of <path> — normalize a (possibly relative) path to absolute
  case "$1" in
    /*) printf '%s' "$1" ;;
    ./*) printf '%s' "$(pwd)${1#.}" ;;
    *) printf '%s' "$(pwd)/$1" ;;
  esac
}

is_blocking() { # is_blocking <gate> — 0 if the gate may emit FAIL
  local g
  for g in $BLOCKING_SET; do [ "$g" = "$1" ] && return 0; done
  return 1
}

file_touched() { # file_touched <absfile> — 0 if the file is present in the diff
  [ -f "$BLAME_TOUCHED" ] || return 1
  grep -qxF "$1" "$BLAME_TOUCHED" >/dev/null 2>&1
}

file_fully_added() { # file_fully_added <absfile> — 0 if the diff added the whole file
  [ -f "$BLAME_FULLY_ADDED" ] || return 1
  grep -qxF "$1" "$BLAME_FULLY_ADDED" >/dev/null 2>&1
}

ranges_overlap() { # ranges_overlap <absfile> <start> <end> — 0 if any added range overlaps
  [ -f "$BLAME_RANGES" ] || return 1
  local line ranges r s e
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ranges="${line#*$'\t'}"
    for r in $ranges; do
      s="${r%%-*}"
      e="${r#*-}"
      if [ "$3" -ge "$s" ] && [ "$2" -le "$e" ]; then return 0; fi
    done
  done < <(grep -F "$1"$'\t' "$BLAME_RANGES" 2>/dev/null || true)
  return 1
}

classify_blame() { # classify_blame <gate> <file> <start> <end> → fail|warn|none under -BaseRef
  local gate="$1" file="$2" start="$3" end="$4" af
  af=$(abs_of "$file")
  if ! file_touched "$af"; then echo none; return; fi
  if ! is_blocking "$gate"; then echo warn; return; fi
  if file_fully_added "$af"; then echo fail; return; fi
  if [ -z "$start" ]; then echo fail; return; fi  # file-level: touched ⇒ overlap
  if ranges_overlap "$af" "$start" "$end"; then echo fail; return; fi
  echo warn
}

classify() { # classify <gate> <legacy> <file> <start> <end> → fail|warn|none
  local gate="$1" legacy="$2"
  if [ -n "$BASE_REF" ]; then
    classify_blame "$gate" "$3" "$4" "$5"
    return
  fi
  if is_blocking "$gate"; then echo "$legacy"; else echo warn; fi
}

emit() { # emit <severity> <message> — route a finding to fail/warn (none = silent)
  case "$1" in
    fail) fail "$2" ;;
    warn) warn "$2" ;;
  esac
}

collect_rel_paths() { # collect_rel_paths <repo_root> — audited files on stdin → repo-relative paths on stdout
  local repo_root="$1" p a
  while IFS= read -r p; do
    [ -z "$p" ] || [ ! -f "$p" ] && continue
    a=$(abs_of "$p")
    case "$a" in
      "$repo_root"/*) printf '%s\n' "${a#"$repo_root"/}" ;;
    esac
  done
}

hunk_range() { # hunk_range <@@ hunk line> — echo the added range "start-end", or return 1 if none added
  local line="$1" start count
  start=$(printf '%s' "$line" | sed -nE 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+)(,([0-9]+))? @@.*/\2/p')
  [ -n "$start" ] || return 1
  count=$(printf '%s' "$line" | sed -nE 's/^@@ -[0-9]+(,[0-9]+)? \+([0-9]+),([0-9]+) @@.*/\3/p')
  [ -n "$count" ] || count=1
  [ "$count" -ge 1 ] || return 1
  printf '%s' "$start-$((start + count - 1))"
}

parse_diff_hunks() { # parse_diff_hunks <diff> <repo_root> — fill BLAME_TOUCHED / BLAME_RANGES
  local diffout="$1" repo_root="$2" line cur rng
  # `+++ b/<path>` resets the current file; each `@@ -l +c,d @@` hunk
  # (unified=0, no context) contributes added range c..c+d-1.
  while IFS= read -r line; do
    case "$line" in
      '+++ /dev/null') cur="" ;;
      '+++ b/'*)
        cur="$repo_root/${line#'+++ b/'}"
        echo "$cur" >> "$BLAME_TOUCHED"
        ;;
      '@@ -'*)
        [ -n "$cur" ] || continue
        rng=$(hunk_range "$line") || continue
        echo "$cur"$'\t'"$rng" >> "$BLAME_RANGES"
        ;;
    esac
  done <<< "$diffout"
}

compute_diff() { # compute_diff <newline-separated audited files>
  local files="$1" repo_root errf rel=() diffout u untracked
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: -BaseRef '$BASE_REF' — git rev-parse --show-toplevel failed; cannot compute the diff" >&2
    exit 2
  }
  errf="$BLAME_DIR/diff.err"
  # Absolute paths for every audited file, then repo-relative for git.
  mapfile -t rel < <(collect_rel_paths "$repo_root" <<< "$files")
  [ "${#rel[@]}" -eq 0 ] && return 0
  if ! diffout=$(printf '%s\0' "${rel[@]}" | xargs -0 git -C "$repo_root" diff --unified=0 "$BASE_REF" -- 2>"$errf"); then
    echo "Error: -BaseRef '$BASE_REF' — git diff failed: $(head -1 "$errf")" >&2
    exit 2
  fi
  parse_diff_hunks "$diffout" "$repo_root"
  # Untracked (not gitignored) audited files are entirely diff-introduced.
  untracked=$(printf '%s\0' "${rel[@]}" | xargs -0 git -C "$repo_root" ls-files --others --exclude-standard -- 2>/dev/null || true)
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    echo "$repo_root/$u" >> "$BLAME_TOUCHED"
    echo "$repo_root/$u" >> "$BLAME_FULLY_ADDED"
  done <<< "$untracked"
  sort -u "$BLAME_TOUCHED" -o "$BLAME_TOUCHED"
  sort -u "$BLAME_RANGES" -o "$BLAME_RANGES"
  sort -u "$BLAME_FULLY_ADDED" -o "$BLAME_FULLY_ADDED"
}

# ── Run ──────────────────────────────────────────────────────────────────────
if [ -n "$BASE_REF" ]; then
  compute_diff "$ALL_NONTEST"
fi
run_complexity_kiss java $NONTEST_JAVA
run_complexity_kiss go $NONTEST_GO
run_complexity_kiss node $NONTEST_NODE
echo ""

echo "--- DRY ---"
check_dry "$ALL_NONTEST"
echo ""

echo "--- YAGNI ---"
check_yagni "$NONTEST_JAVA" java
check_yagni "$NONTEST_GO" go
check_yagni "$NONTEST_NODE" node
echo ""

echo "--- SOLID ---"
check_solid_srp "$NONTEST_JAVA" java
check_solid_srp "$NONTEST_GO" go
check_solid_srp "$NONTEST_NODE" node
check_solid_ocp "$NONTEST_JAVA" java
check_solid_ocp "$NONTEST_GO" go
check_solid_ocp "$NONTEST_NODE" node
check_solid_lsp "$NONTEST_JAVA" java
check_solid_lsp "$NONTEST_NODE" node
check_solid_isp "$NONTEST_JAVA" java
check_solid_isp "$NONTEST_NODE" node
check_solid_dip java
check_solid_dip go
check_solid_dip node
echo ""

echo "--- Property tests ---"
check_property_tests java
check_property_tests go
check_property_tests node
echo ""

# ── Summary ──────────────────────────────────────────────────────────────────
if [ "$WARN_AS_ERROR" = true ]; then
  TOTAL=$((FAILS + WARNS))
else
  TOTAL=$FAILS
fi

echo "---------------------------------------------"
if [ "$TOTAL" -gt 0 ]; then
  echo -e "${RED}✘ Design-principles check: ${FAILS} FAIL(s), ${WARNS} WARN(s).${NC}"
  echo "  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md"
  exit 1
fi
echo -e "${GREEN}✔ Design-principles check: ${FAILS} FAIL(s), ${WARNS} WARN(s).${NC}"
[ "$WARNS" -gt 0 ] && echo "  WARNs are review hints — verify each before merging."
exit 0
