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
#   SOLID        — SRP: god classes (>15 methods, >400 lines; TSX: >300 lines
#                  or >8 components). OCP: switch statements with ≥4 cases /
#                  if-else chains ≥4 (type dispatch that should be
#                  polymorphic). LSP: heavy instanceof/type-test dispatch in
#                  Java/TS. ISP: interfaces with >5 methods. DIP: domain/engine
#                  code importing store/repository/infra.
#   Component-per-file — TSX/JSX: >2 exported PascalCase components per file
#                  (FAIL), >1 is WARN; or >4 total exported functions in .tsx
#                  (FAIL). Also enforces tightened SRP for TSX (>300 lines).
#                  Mirrors docs/CODING_CONVENTIONS.md §File Organization
#                  "One React component per file" — BookingWidget 14-in-1 is
#                  the anti-pattern.
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
#                                           [--gates <list>] [--warn-as-error] [--json]
#                                           [-ReportPath <file>] [-BaseRef <ref>] [--blocking <gates>]
#
# SOURCE_DIR defaults to the current directory. --tier overrides auto-detection
# from the project's AGENTS_*.md "Conformance tier:" declaration (see
# docs/CONFORMANCE_TIERS.md). --warn-as-error promotes every WARN to a failure.
# --gates restricts the run to a comma-separated subset of the six gate
# categories (complexity, dry, yagni, solid, component-per-file, property-tests) — the Verifier's
# scoped re-verification of a single failing category (AC-007-02, AC-007-03);
# --json prints a single JSON object { "tier", "gates", "fails", "warns" }
# carrying the same findings as the human output, for transcription into
# specs/NNN-slug/25-verification.md (AC-007-03-05, AC-007-03-06).
# -ReportPath <file> additionally writes the machine-readable JSON report
# (tier, gates, fails, warns) atomically to <file> — stdout is unchanged.
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
#   solid (SRP/OCP/LSP/ISP/DIP as one unit), component-per-file, property-tests.
#   Default blocking set: complexity,property-tests,component-per-file — the
#   objective gates in this repo's terms (component-per-file is mvp-tier, cheap
#   heuristic — BookingWidget 14-in-1 must not pass). A gate outside the
#   blocking set is warn-only and never emits FAIL, with or without -BaseRef
#   (DIP and YAGNI single-implementation findings therefore report as WARN).
#   Override with --blocking <comma-list> or the
#   PRINCIPLES_BLOCKING_GATES environment variable (flag wins over env
#   over default); an unknown gate name or an empty value exits 2.
#
# Exit codes:
#   0 — no FAILs (WARNs may exist), or no source files to check
#   1 — at least one FAIL (or a WARN with --warn-as-error)
#   2 — could not perform the check for a non-finding reason: a required tool
#       (find/xargs/awk/grep/sed/tr/sort/wc/head/mktemp/rm) is missing, the
#       source directory is unusable, or a usage error (unknown option, unknown
#       --gates name, empty --gates value, bad/empty --blocking value, or
#       -ReportPath with a missing/empty value), an unresolvable -BaseRef ref,
#       or not a git repository. A missing tool is a tooling failure, never a
#       false PASS — the `|| true` swallows on the tooling paths are
#       preflighted so a gate that could not run exits 2 (AC-007-03-07).
#
# Standards reference:
#   docs/CODING_CONVENTIONS.md §Design Principles
#   docs/ARCHITECTURE.md (DIP / dependency rule)
#   docs/TESTING.md §Property Testing
#   docs/CONFORMANCE_TIERS.md
#   agents/spec-verifier.md (script-is-authority / BLOCK discipline)
set -euo pipefail

# Shared -ReportPath machinery (strip_dashes/json_escape/json_array/
# emit_json_report) — see scripts/gate-report-lib.sh. json_escape comes from
# this lib; check-common.sh's copy is guarded so it does not redefine it.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-report-lib.sh"
# Shared 007 helpers (require_tools / finish_clean / guarded json_escape).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

FAILS=0
WARNS=0
WARN_AS_ERROR=false
REPORT_PATH=""
FAILS_LIST=()
WARNS_LIST=()

# fail/pass/warn feed all three outputs: human stdout (unless --json), the
# --json transcript (FAILS_JSON/WARNS_JSON, file/line triplets), and the
# -ReportPath file report (FAILS_LIST/WARNS_LIST). Blame scoping (011) routes
# findings through emit -> classify/classify_blame, which keep the same
# fail/pass/warn entry points.
BASE_REF=""
BASE_REF_SET=false
BLOCKING_ARG=""
BLOCKING_ARG_SET=false
BLOCKING_SET="complexity property-tests component-per-file"
fail() { # fail <message> [file] [line]
  local msg="$1" loc=""
  [ -n "${2:-}" ] && loc=" ($2${3:+:$3})"
  FAILS=$((FAILS + 1))
  if [ "$JSON" = true ]; then FAILS_JSON+=("$msg" "${2:-}" "${3:-}"); else echo -e "${RED}FAIL${NC} $msg"; fi
  FAILS_LIST+=("$msg$loc")
}
pass() { [ "$JSON" = false ] && echo -e "${GREEN}PASS${NC} $*"; return 0; }
warn() { # warn <message> [file] [line]
  local msg="$1" loc=""
  [ -n "${2:-}" ] && loc=" ($2${3:+:$3})"
  WARNS=$((WARNS + 1))
  if [ "$JSON" = true ]; then WARNS_JSON+=("$msg" "${2:-}" "${3:-}"); else echo -e "${YELLOW}WARN${NC} $msg"; fi
  WARNS_LIST+=("$msg$loc")
}
say() { [ "$JSON" = false ] && echo "$@"; return 0; }

emit_json() {
  local i gates_json="" fails_json="" warns_json=""
  for g in "${SELECTED_GATES[@]}"; do gates_json+="\"$(json_escape "$g")\", "; done
  gates_json="${gates_json%, }"
  for ((i = 0; i < ${#FAILS_JSON[@]}; i += 3)); do
    fails_json+="{ \"message\": \"$(json_escape "${FAILS_JSON[i]}")\", \"file\": \"$(json_escape "${FAILS_JSON[i + 1]:-}")\", \"line\": \"$(json_escape "${FAILS_JSON[i + 2]:-}")\" }, "
  done
  fails_json="${fails_json%, }"
  for ((i = 0; i < ${#WARNS_JSON[@]}; i += 3)); do
    warns_json+="{ \"message\": \"$(json_escape "${WARNS_JSON[i]}")\", \"file\": \"$(json_escape "${WARNS_JSON[i + 1]:-}")\", \"line\": \"$(json_escape "${WARNS_JSON[i + 2]:-}")\" }, "
  done
  warns_json="${warns_json%, }"
  printf '{\n  "tier": "%s",\n  "gates": [%s],\n  "fails": [%s],\n  "warns": [%s]\n}\n' \
    "$(json_escape "$TIER")" "$gates_json" "$fails_json" "$warns_json"
}

FAILS_JSON=()
WARNS_JSON=()

SOURCE_DIR="."
TIER=""
GATES=""
GATES_SET=false
JSON=false
# One parser for both flag styles (see gate-report-lib.sh): double-dash flags
# (--tier, --warn-as-error, --gates, --json from 007, --blocking from 011) and
# single-dash flags (-BaseRef from 011, -ReportPath from 012). strip_dashes
# makes the styles coexist without two parsers.
while [ $# -gt 0 ]; do
  if [ "${1#-}" != "$1" ]; then
    name="$(strip_dashes "$1")"
    case "$name" in
      tier) TIER="${2:-}"; shift $(( $# > 1 ? 2 : 1 )) ;;
      warn-as-error) WARN_AS_ERROR=true; shift ;;
      blocking) BLOCKING_ARG="${2:-}"; BLOCKING_ARG_SET=true; shift $(( $# > 1 ? 2 : 1 )) ;;
      BaseRef) BASE_REF="${2:-}"; BASE_REF_SET=true; shift $(( $# > 1 ? 2 : 1 )) ;;
      gates) GATES_SET=true; GATES="${2:-}"; shift $(( $# > 1 ? 2 : 1 )) ;;
      json) JSON=true; shift ;;
      ReportPath)
        REPORT_PATH="${2:-}"
        [ -n "$REPORT_PATH" ] || { echo "Error: -ReportPath requires a non-empty file path" >&2; exit 2; }
        shift $(( $# > 1 ? 2 : 1 )) ;;
      *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
  else
    SOURCE_DIR="$1"; shift
  fi
done

if [ "$BASE_REF_SET" = true ] && [ -z "$BASE_REF" ]; then
  echo "Error: -BaseRef requires a value (the git ref to diff against)" >&2
  exit 2
fi

# ── Blocking set (which gates may emit FAIL) ─────────────────────────────────
# Gate names: complexity, dry, yagni, solid, component-per-file, property-tests. Default:
# complexity,property-tests,component-per-file (the objective gates). --blocking wins over the
# PRINCIPLES_BLOCKING_GATES env var, which wins over the default.
blocking_raw() { # blocking_raw — resolve --blocking / env var / default into a raw comma list
  if [ "$BLOCKING_ARG_SET" = true ]; then
    [ -n "$BLOCKING_ARG" ] || { echo "Error: --blocking requires a comma-separated list of gates (complexity, dry, yagni, solid, component-per-file, property-tests)" >&2; exit 2; }
    printf '%s' "$BLOCKING_ARG"
    return
  fi
  if [ "${PRINCIPLES_BLOCKING_GATES+x}" = "x" ]; then
    printf '%s' "$PRINCIPLES_BLOCKING_GATES"
    return
  fi
  printf '%s' "complexity,property-tests,component-per-file"
}

valid_gate() { # valid_gate <name> — 0 if a known gate name
  case "$1" in
    complexity|dry|yagni|solid|component-per-file|property-tests) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_blocking_set() {
  local raw g
  raw=$(blocking_raw | tr -d '[:space:]')
  BLOCKING_SET=""
  for g in $(printf '%s' "$raw" | tr ',' '\n' | sed '/^$/d'); do
    if ! valid_gate "$g"; then
      echo "Error: unknown gate name in blocking set: '$g' (valid gates: complexity, dry, yagni, solid, component-per-file, property-tests)" >&2
      exit 2
    fi
    BLOCKING_SET="${BLOCKING_SET}${BLOCKING_SET:+ }$g"
  done
  [ -n "$BLOCKING_SET" ] || { echo "Error: blocking set is empty — must name at least one of: complexity, dry, yagni, solid, component-per-file, property-tests" >&2; exit 2; }
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

# ── --gates validation (AC-007-03-04): unknown name or empty value = exit 2 ──
SELECTED_GATES=()
if [ "$GATES_SET" = true ]; then
  if [ -z "$GATES" ]; then
    echo "ERROR: --gates requires a comma-separated list of gate names (complexity, dry, yagni, solid, component-per-file, property-tests)" >&2
    exit 2
  fi
  IFS=',' read -r -a gate_list <<< "$GATES"
  for g in "${gate_list[@]}"; do
    case "$g" in
      complexity|dry|yagni|solid|component-per-file|property-tests) SELECTED_GATES+=("$g") ;;
      *) echo "ERROR: unknown gate '$g' (valid: complexity, dry, yagni, solid, component-per-file, property-tests)" >&2; exit 2 ;;
    esac
  done
else
  SELECTED_GATES=(complexity dry yagni solid component-per-file property-tests)
fi

contains_gate() { # contains_gate <name>
  local g
  for g in "${SELECTED_GATES[@]}"; do [ "$g" = "$1" ] && return 0; done
  return 1
}

# ── Tooling preflight (AC-007-03-07): a missing tool is exit 2, never a PASS ──
require_tools design-principles find xargs awk grep sed tr sort wc head mktemp rm

if [ ! -d "$SOURCE_DIR" ] || [ ! -r "$SOURCE_DIR" ]; then
  echo "ERROR: source directory '$SOURCE_DIR' is missing or unreadable — cannot perform the design-principles check" >&2
  exit 2
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
FIND_PRUNE='( -name node_modules -o -name target -o -name vendor -o -name .git -o -name dist -o -name build -o -name ci )'

JAVA_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.java' -print 2>/dev/null || true)
GO_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.go' -print 2>/dev/null || true)
NODE_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print 2>/dev/null || true)

[ -z "$JAVA_FILES" ] && [ -z "$GO_FILES" ] && [ -z "$NODE_FILES" ] && {
  finish_clean "No Java, Go, or JS/TS source files found under $SOURCE_DIR — nothing to check."
}

say "Checking design principles in: $SOURCE_DIR (tier: $TIER)"
say ""

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

# split_loc <file:line> — split an analyzer location into LOC_FILE / LOC_LINE.
split_loc() {
  LOC_FILE="${1%%:*}"
  LOC_LINE="${1#*:}"
  LOC_LINE="${LOC_LINE%%:*}"
}

# report_one_violation <lang> <line> — emit one analyzer line as FAIL/WARN.
report_one_violation() {
  local lang="$1" line="$2"
  [ -z "$line" ] && return 0
  LOC_FILE=""; LOC_LINE=""
  if [[ "$line" == *:*:* ]]; then
    split_loc "$line"
  fi
  case "$line" in
    *CC=*) fail "Cyclomatic complexity >6 ($lang): $line" "$LOC_FILE" "$LOC_LINE" ;;
    *KISS_LINES=*) warn "Method body >20 lines ($lang): $line" "$LOC_FILE" "$LOC_LINE" ;;
    *KISS_PARAMS=*) warn "Method with >6 parameters ($lang): $line" "$LOC_FILE" "$LOC_LINE" ;;
  esac
}

run_complexity_kiss() {
  local lang="$1"; shift
  local files=("$@")
  [ "${#files[@]}" -eq 0 ] && return 0
  local out rc
  # No `|| true` swallow: an awk/xargs failure means the check could not run —
  # that is a tooling failure (exit 2), never a silent PASS (AC-007-03-07).
  out=$(printf '%s\n' "${files[@]}" | xargs awk -v LANG="$lang" "$complexity_awk" 2>&1) || rc=$?
  if [ "${rc:-0}" -ne 0 ]; then
    echo "ERROR: complexity/KISS analyzer failed to run (awk/xargs) — cannot complete the check" >&2
    exit 2
  fi
  [ -z "$out" ] && { pass "Complexity/KISS ($lang): no violations found"; return 0; }
  local line f s e
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    f=$(printf '%s' "$line" | cut -d: -f1)
    s=$(printf '%s' "$line" | cut -d: -f2)
    e=$(printf '%s' "$line" | cut -d: -f3)
    case "$line" in
      *CC=*) emit "$(classify "complexity" "fail" "$f" "$s" "$e")" "Cyclomatic complexity >6 ($lang): $line" "$f" "$s" ;;
      *KISS_LINES=*) emit "$(classify "complexity" "warn" "$f" "$s" "$e")" "Method body >20 lines ($lang): $line" "$f" "$s" ;;
      *KISS_PARAMS=*) emit "$(classify "complexity" "warn" "$f" "$s" "$e")" "Method with >6 parameters ($lang): $line" "$f" "$s" ;;
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
      emit "$sev" "Possible duplication (${count}x identical 4-line block, first at $loc): ${win//$'\x1f'/ /}" "$dfile" "$dline"
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
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln")" "YAGNI: interface $name has exactly one implementation (premature abstraction) — $f:$ln" "$f" "$ln"
            found=true
          fi
        done < <(grep -nE '^\s*(public\s+)?interface[ \t]+' "$f" 2>/dev/null || true)
        while IFS=: read -r ln _; do
          emit "$(classify "yagni" "warn" "$f" "$ln" "$ln")" "Empty method body ($lang): $f:$ln" "$f" "$ln"
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
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln")" "YAGNI: Go interface $name is declared but barely referenced (premature abstraction) — $f:$ln" "$f" "$ln"
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
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln")" "YAGNI: interface $name has exactly one implementation (premature abstraction) — $f:$ln" "$f" "$ln"
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
  local f lines methods comp_count
  for f in $files; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    methods=0
    case "$lang" in
      java) methods=$(grep -cE '^\s*(public|protected|private)\s+.*\(' "$f" 2>/dev/null | tr -d ' ') || methods=0 ;;
      node) methods=$(grep -cE '^\s*(public|private|protected|async\s+)?[A-Za-z0-9_$]+\s*\([^)]*\)\s*\{' "$f" 2>/dev/null | tr -d ' ') || methods=0 ;;
      *) methods=0 ;;
    esac
    # Tightened SRP for TSX/JSX: >300 lines OR >8 components (god-file via component count).
    # BookingWidget 14-in-1 was 390 lines / 14 components and passed the old 400/15 gate.
    if [ "$lang" = "node" ]; then
      case "$f" in
        *.tsx|*.jsx)
          comp_count=$( (grep -E '^\s*(export\s+)?(default\s+)?(function\s+[A-Z]|const\s+[A-Z][A-Za-z0-9_]*\s*[:=][^;]*=>|const\s+[A-Z][A-Za-z0-9_]*\s*=\s*React\.(memo|forwardRef)|class\s+[A-Z])' "$f" 2>/dev/null || true) | wc -l | tr -d ' ') || comp_count=0
          if [ "$lines" -gt 300 ] || [ "$comp_count" -gt 8 ] || [ "$lines" -gt 400 ] || [ "$methods" -gt 15 ]; then
            emit "$(classify "solid" "warn" "$f" "" "")" "SRP: possible god file ($lang) — $f: ${lines} lines, ${methods} methods, ${comp_count} components (TSX threshold: 300 lines / 8 components; general: 400 lines / 15 methods) — split by responsibility" "$f"
            found=true
          fi
          continue
          ;;
      esac
    fi
    if [ "$lines" -gt 400 ] || [ "$methods" -gt 15 ]; then
      emit "$(classify "solid" "warn" "$f" "" "")" "SRP: possible god file ($lang) — $f: ${lines} lines, ${methods} methods (split by responsibility)" "$f"
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
      emit "$(classify "solid" "warn" "$ocpfile" "$ocpline" "$ocpline")" "OCP: type-dispatch switch should be polymorphic ($lang) — $r" "$ocpfile" "$ocpline"
      found=true
    done <<< "$res"
    eif=$(grep -cE '^\s*else[ \t]+if' "$f" 2>/dev/null || true)
    if [ "${eif:-0}" -ge 4 ]; then
      eifline=$(grep -nE '^\s*else[ \t]+if' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      emit "$(classify "solid" "warn" "$f" "$eifline" "$eifline")" "OCP: ${eif}-branch if/else chain ($lang) — $f (consider polymorphism or a lookup)" "$f" "$eifline"
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
      emit "$(classify "solid" "warn" "$f" "" "")" "LSP: ${c} instanceof checks in one file ($lang) — $f (suggests broken substitutability or type dispatch)" "$f"
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
      emit "$(classify "solid" "warn" "$ispfile" "$ispline" "$ispline")" "ISP: fat interface (>5 methods) — $r (split by role)" "$ispfile" "$ispline"
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
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln" "$f" "$dln"
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
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln")" "DIP: domain/engine code imports store/infra/repository ($lang) — $f:$dln" "$f" "$dln"
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
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln" "$f" "$dln"
              found=true
            fi
            ;;
        esac
      done
      ;;
  esac
  $found || pass "SOLID-DIP ($lang): no domain→infrastructure imports"
}

# ── Component-per-file (TSX/JSX, mvp tier) ──────────────────────────────────
# One React component per file: TSX/JSX files must export ≤2 PascalCase components
# (FAIL if >2, WARN if >1) and ≤4 total exported functions (FAIL). For .ts with
# React (imports React) and api/*.ts, total exported functions are also checked.
# Tightened god-file for TSX via this gate (blocking): >300 lines FAIL.
# Keep existing behavior for Java/Go untouched — only NODE_FILES inspected.
check_component_per_file() {
  local files="$1"
  [ -z "$files" ] && return 0
  local found=false
  local f comp exported_total lines all_comp
  for f in $files; do
    [ -f "$f" ] || continue
    case "$f" in
      *.tsx|*.jsx) ;;
      *.ts|*.js)
        # For plain .ts/.js: only check api/*.ts or files that import React
        if [[ "$f" == *"/api/"* ]]; then
          : # always check api files
        elif grep -qiE 'from\s+["'\'']react["'\'']|import\s+.*react|from\s+["'\''].*react' "$f" 2>/dev/null; then
          : # React TS file — check
        else
          continue
        fi
        ;;
      *) continue ;;
    esac
    # Exported PascalCase components: export function Foo / export const Foo = ...=> / export default function Foo
    comp=$( (grep -E '^\s*export\s+(default\s+)?function\s+[A-Z]|^\s*export\s+const\s+[A-Z][A-Za-z0-9_]*\s*[:=][^;]*=>|^\s*export\s+default\s+function(\s+[A-Z]|\s*\()' "$f" 2>/dev/null || true) | wc -l | tr -d ' ')
    comp=${comp:-0}
    # Total exported functions/callables (any case): export function / export const X = / export async function
    exported_total=$( (grep -E '^\s*export\s+(default\s+)?(async\s+)?function\s+[A-Za-z]|^\s*export\s+(const|let|var)\s+[A-Za-z0-9_]+\s*=' "$f" 2>/dev/null || true) | wc -l | tr -d ' ')
    exported_total=${exported_total:-0}
    lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ') || lines=0
    # All components in file (for god-file threshold 8, not just exported)
    all_comp=$( (grep -E '^\s*(export\s+)?(default\s+)?(function\s+[A-Z]|const\s+[A-Z][A-Za-z0-9_]*\s*[:=][^;]*=>|const\s+[A-Z][A-Za-z0-9_]*\s*=\s*React\.(memo|forwardRef)|class\s+[A-Z])' "$f" 2>/dev/null || true) | wc -l | tr -d ' ')
    all_comp=${all_comp:-0}
    # Gate: >2 exported components => FAIL, >1 => WARN
    if [ "$comp" -gt 2 ]; then
      emit "$(classify "component-per-file" "fail" "$f" "" "")" "Component-per-file: $f has $comp exported components (threshold: ≤2, ideal ≤1) — split into one component per file with barrel index.ts (BookingWidget 14-in-1 anti-pattern)" "$f"
      found=true
    elif [ "$comp" -gt 1 ]; then
      emit "$(classify "component-per-file" "warn" "$f" "" "")" "Component-per-file: $f has $comp exported components (ideal ≤1) — consider one component per file" "$f"
      found=true
    fi
    # Gate: >4 total exported functions in .tsx/.jsx (covers App.tsx 7 functions) and api/*.ts
    if [[ "$f" == *.tsx || "$f" == *.jsx ]] && [ "$exported_total" -gt 4 ]; then
      emit "$(classify "component-per-file" "fail" "$f" "" "")" "Component-per-file: $f exports $exported_total functions/components (threshold: ≤4) — split file" "$f"
      found=true
    elif [[ "$f" == *"/api/"* ]] && [ "$exported_total" -gt 4 ]; then
      emit "$(classify "component-per-file" "fail" "$f" "" "")" "Component-per-file: $f (api) exports $exported_total functions (threshold: ≤4) — split file" "$f"
      found=true
    fi
    # Tightened god-file via blocking gate: >300 lines or >8 components for TSX/JSX
    if [[ "$f" == *.tsx || "$f" == *.jsx ]]; then
      if [ "$lines" -gt 300 ]; then
        emit "$(classify "component-per-file" "fail" "$f" "" "")" "Component-per-file: god file — $f: ${lines} lines (TSX threshold: 300) — split by responsibility" "$f"
        found=true
      elif [ "$all_comp" -gt 8 ]; then
        emit "$(classify "component-per-file" "fail" "$f" "" "")" "Component-per-file: god file — $f: ${all_comp} components (TSX threshold: 8) — split by responsibility" "$f"
        found=true
      fi
    fi
  done
  $found || pass "Component-per-file: no violations"
}

# ── Property tests (production tier and above) ───────────────────────────────
check_property_tests() {
  case "$TIER" in
    mvp) say "Property tests: skipped (project tier is $TIER — production+ required)"; return 0 ;;
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

# ── JSON report (-ReportPath, telemetry) ─────────────────────────────────────
# -ReportPath <file> writes the machine-readable report (same fields as the
# --json stdout mode: tier, gates, fails, warns) atomically to <file> (spec 012).
# gates reflects the categories actually run — all five by default, or the
# 007 --gates subset when the run was scoped (AC-007-03-01).
# json_escape / json_array / emit_json_report come from gate-report-lib.sh.
emit_report() {
  [ -n "$REPORT_PATH" ] || return 0
  local json fails_json warns_json gates_json
  fails_json=""
  warns_json=""
  gates_json="$(json_array "${SELECTED_GATES[@]}")"
  [ "${#FAILS_LIST[@]}" -gt 0 ] && fails_json="$(json_array "${FAILS_LIST[@]}")"
  [ "${#WARNS_LIST[@]}" -gt 0 ] && warns_json="$(json_array "${WARNS_LIST[@]}")"
  json="{\"tier\":\"$(json_escape "$TIER")\","
  json="${json}\"gates\":[${gates_json}],\"fails\":[${fails_json}],\"warns\":[${warns_json}]}"
  emit_json_report "$REPORT_PATH" "$json"
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

emit() { # emit <severity> <message> [file] [line] — route a finding to fail/warn (none = silent)
  case "$1" in
    fail) fail "$2" "${3:-}" "${4:-}" ;;
    warn) warn "$2" "${3:-}" "${4:-}" ;;
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
# --gates restricts execution to the listed categories (AC-007-03-01,
# AC-007-03-02); the default runs all six, byte-identical to prior behavior.
if contains_gate complexity; then
  run_complexity_kiss java $NONTEST_JAVA
  run_complexity_kiss go $NONTEST_GO
  run_complexity_kiss node $NONTEST_NODE
  say ""
fi

if contains_gate dry; then
  say "--- DRY ---"
  check_dry "$ALL_NONTEST"
  say ""
fi

if contains_gate yagni; then
  say "--- YAGNI ---"
  check_yagni "$NONTEST_JAVA" java
  check_yagni "$NONTEST_GO" go
  check_yagni "$NONTEST_NODE" node
  say ""
fi

if contains_gate solid; then
  say "--- SOLID ---"
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
  say ""
fi

if contains_gate component-per-file; then
  say "--- Component-per-file ---"
  check_component_per_file "$NONTEST_NODE"
  say ""
fi

if contains_gate property-tests; then
  say "--- Property tests ---"
  check_property_tests java
  check_property_tests go
  check_property_tests node
  say ""
fi

# ── Summary ──────────────────────────────────────────────────────────────────
if [ "$WARN_AS_ERROR" = true ]; then
  TOTAL=$((FAILS + WARNS))
else
  TOTAL=$FAILS
fi

# Report the subset when --gates narrowed the run (AC-007-03-01); the default
# full run keeps its prior summary text byte-for-byte.
GATE_SUMMARY=""
[ "${#SELECTED_GATES[@]}" -lt 6 ] && GATE_SUMMARY="(gates: $(IFS=,; echo "${SELECTED_GATES[*]}"))"

say "---------------------------------------------"
emit_report
if [ "$TOTAL" -gt 0 ]; then
  say -e "${RED}✘ Design-principles check${GATE_SUMMARY:+ }${GATE_SUMMARY}: ${FAILS} FAIL(s), ${WARNS} WARN(s).${NC}"
  say "  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md"
else
  say -e "${GREEN}✔ Design-principles check${GATE_SUMMARY:+ }${GATE_SUMMARY}: ${FAILS} FAIL(s), ${WARNS} WARN(s).${NC}"
  [ "$WARNS" -gt 0 ] && say "  WARNs are review hints — verify each before merging."
fi

if [ "$JSON" = true ]; then
  emit_json
fi

if [ "$TOTAL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
