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
#
# SOURCE_DIR defaults to the current directory. --tier overrides auto-detection
# from the project's AGENTS_*.md "Conformance tier:" declaration (see
# docs/CONFORMANCE_TIERS.md). --warn-as-error promotes every WARN to a failure.
#
# Exit codes:
#   0 — no FAILs (WARNs may exist)
#   1 — at least one FAIL (or a WARN with --warn-as-error)
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

fail() { echo -e "${RED}FAIL${NC} $*"; FAILS=$((FAILS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }
warn() { echo -e "${YELLOW}WARN${NC} $*"; WARNS=$((WARNS + 1)); }

SOURCE_DIR="."
TIER=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tier) TIER="${2:-}"; shift 2 ;;
    --warn-as-error) WARN_AS_ERROR=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 2 ;;
    *) SOURCE_DIR="$1"; shift ;;
  esac
done

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
    printf "%s:%d:%s:CC=%d\n", FILENAME, STACK[top,"l"], STACK[top,"n"], STACK[top,"c"]
  if (STACK[top,"lines"] > 20)
    printf "%s:%d:%s:KISS_LINES=%d\n", FILENAME, STACK[top,"l"], STACK[top,"n"], STACK[top,"lines"]
  if (STACK[top,"params"] > 6)
    printf "%s:%d:%s:KISS_PARAMS=%d\n", FILENAME, STACK[top,"l"], STACK[top,"n"], STACK[top,"params"]
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
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      *CC=*) fail "Cyclomatic complexity >6 ($lang): $line" ;;
      *KISS_LINES=*) warn "Method body >20 lines ($lang): $line" ;;
      *KISS_PARAMS=*) warn "Method with >6 parameters ($lang): $line" ;;
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
    while IFS=$'\t' read -r count win loc; do
      warn "Possible duplication (${count}x identical 4-line block, first at $loc): ${win//$'\x1f'/ /}"
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
        while IFS= read -r iface; do
          [ -z "$iface" ] && continue
          name=$(echo "$iface" | grep -oE 'interface[ \t]+[A-Za-z0-9_]+' | awk '{print $2}')
          [ -z "$name" ] && continue
          impls=$(grep -rE "implements[^,{]*$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ' || true)
          if [ "$impls" -eq 1 ]; then
            fail "YAGNI: interface $name has exactly one implementation (premature abstraction) — $f"
            found=true
          fi
        done < <(grep -E '^\s*(public\s+)?interface[ \t]+' "$f" 2>/dev/null || true)
        while IFS=: read -r ln _; do
          warn "Empty method body ($lang): $f:$ln"
          found=true
        done < <(grep -nE '\{\s*\}' "$f" 2>/dev/null | grep -vE '//|test' || true)
      done
      ;;
    go)
      for f in $files; do
        [ -f "$f" ] || continue
        while IFS= read -r iface; do
          [ -z "$iface" ] && continue
          name=$(echo "$iface" | grep -oE 'interface[ \t]+[A-Za-z0-9_]+' | awk '{print $2}')
          [ -z "$name" ] && continue
          refs=$(grep -rE "\b$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.go" 2>/dev/null | grep -v "interface[ \t]*$name" | wc -l | tr -d ' ' || true)
          if [ "$refs" -le 1 ]; then
            fail "YAGNI: Go interface $name is declared but barely referenced (premature abstraction) — $f"
            found=true
          fi
        done < <(grep -E 'type[ \t]+[A-Za-z0-9_]+[ \t]+interface\b' "$f" 2>/dev/null || true)
      done
      ;;
    node)
      for f in $files; do
        [ -f "$f" ] || continue
        while IFS= read -r iface; do
          [ -z "$iface" ] && continue
          name=$(echo "$iface" | grep -oE 'interface[ \t]+[A-Za-z0-9_]+' | awk '{print $2}')
          [ -z "$name" ] && continue
          impls=$(grep -rE "implements[^,{]*$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.ts" 2>/dev/null | wc -l | tr -d ' ' || true)
          if [ "$impls" -eq 1 ]; then
            fail "YAGNI: interface $name has exactly one implementation (premature abstraction) — $f"
            found=true
          fi
        done < <(grep -E '^\s*(export\s+)?interface[ \t]+' "$f" 2>/dev/null || true)
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
      warn "SRP: possible god file ($lang) — $f: ${lines} lines, ${methods} methods (split by responsibility)"
      found=true
    fi
  done
  $found || pass "SOLID-SRP ($lang): no oversized files"
}

check_solid_ocp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local res r eif
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
      warn "OCP: type-dispatch switch should be polymorphic ($lang) — $r"
      found=true
    done <<< "$res"
    eif=$(grep -cE '^\s*else[ \t]+if' "$f" 2>/dev/null || true)
    if [ "${eif:-0}" -ge 4 ]; then
      warn "OCP: ${eif}-branch if/else chain ($lang) — $f (consider polymorphism or a lookup)"
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
  for f in $files; do
    [ -f "$f" ] || continue
    c=$(grep -c 'instanceof' "$f" 2>/dev/null || true)
    if [ "$c" -ge 3 ]; then
      warn "LSP: ${c} instanceof checks in one file ($lang) — $f (suggests broken substitutability or type dispatch)"
      found=true
    fi
  done
  $found || pass "SOLID-LSP ($lang): no heavy instanceof dispatch"
}

check_solid_isp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local res r
  for f in $files; do
    [ -f "$f" ] || continue
    res=$(awk '
      /^[ \t]*(public[ \t]+)?interface[ \t]+[A-Za-z0-9_]+/ { iw=1; nr=FNR; methods=0; next }
      iw && /^[ \t]*\}/ { if (methods>5) printf "%s:%d:interface with %d methods\n", FILENAME, nr, methods; iw=0; next }
      iw && /\([^)]*\)[ \t]*(;|\{|$)/ { methods++ }
    ' "$f" 2>/dev/null || true)
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      warn "ISP: fat interface (>5 methods) — $r (split by role)"
      found=true
    done <<< "$res"
  done
  $found || pass "SOLID-ISP ($lang): no fat interfaces"
}

check_solid_dip() {
  local lang="$1"
  local found=false
  case "$lang" in
    java)
      for f in $JAVA_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*)
            hit=$(grep -E '^\s*import\s+.*\.(infrastructure|persistence|repository)\.' "$f" 2>/dev/null || true)
            [ -n "$hit" ] && { fail "DIP: domain/engine code imports infrastructure ($lang) — $f"; found=true; }
            ;;
        esac
      done
      ;;
    go)
      for f in $GO_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*)
            hit=$(grep -E '^\s*"[^"]*/(store|infra|repository)[^"]*"' "$f" 2>/dev/null || true)
            [ -n "$hit" ] && { fail "DIP: domain/engine code imports store/infra/repository ($lang) — $f"; found=true; }
            ;;
        esac
      done
      ;;
    node)
      for f in $NODE_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*|*/entities/*)
            hit=$(grep -E "from\s+['\"].*(/store|/infra|/repository|/repositories|/infrastructure)" "$f" 2>/dev/null || true)
            [ -n "$hit" ] && { fail "DIP: domain/engine code imports infrastructure ($lang) — $f"; found=true; }
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

# ── Run ──────────────────────────────────────────────────────────────────────
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
