#!/bin/bash
# check-code-principles.sh — Static, language-agnostic audit of design principles:
# KISS, DRY, YAGNI, SOLID, cyclomatic complexity, and property-test coverage.
#
# Works on any code the standards allow: Java, Go, JavaScript/TypeScript (incl.
# React Native), and — per docs/adr/0006-python-rust-gate-coverage.md (D1) —
# Python and Rust. It reads source files directly and applies the same
# heuristics to every language, so it runs in a child repo without any
# project-specific linter configuration.
#
# ADR 0006 D6 rollout: Python and Rust coverage is WARN-ONLY for one release.
# Findings in .py/.rs files never change the exit status (see WARN_ONLY_LANGS
# below); Java/Go/JS-TS behavior is unchanged. The Python and Rust complexity
# heuristics are approximations — Python comprehensions/decorator stacks and
# Rust match arms/generic bounds/closures can inflate naive counts — so their
# findings say so explicitly. `component-per-file` is a JS/TS component-model
# concept and is NOT applied to Python or Rust (ADR 0006 D1).
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
#                  fast-check; Python hypothesis and Rust proptest/quickcheck
#                  during the ADR 0006 warn phase). See docs/TESTING.md
#                  §Property Testing.
#   Comments     — Clean Code Ch.4 redundant-comment elimination, not a comment
#                  ban. Five rules; two are blocking-class, three are advisory:
#                    blocking-class (WARN by default, FAIL under the strict
#                    switch below):
#                      · commented-out code — two or more consecutive
#                        code-shaped comment lines
#                      · comment restates the following line — the comment's
#                        token set is a subset of the next physical code line
#                    advisory (WARN in every mode, never FAIL):
#                      · TODO/FIXME without an issue reference
#                      · section-divider comment (`// ======`)
#                      · attribution comment (`@author`, `created by`)
#                  Allowlist — a comment line is skipped for every rule when it
#                  is on one of the first five lines of the file; contains
#                  `shellcheck`, `noqa`, `type: ignore`, `pragma`, `ponytail:`,
#                  `standards:allow-`, `SPDX-License-Identifier`, `Copyright`,
#                  `Licensed under`, `@license`, or a URL (`http://`,
#                  `https://`); licence and copyright markers are therefore
#                  permanently endorsed; sits in a `/** ... */` doc block
#                  immediately followed by a `public`/`protected`/`export`
#                  declaration; or sits in a `///` run or Go `//` run
#                  immediately followed by a public-API declaration (`pub`,
#                  `func <Upper>`, `type <Upper>`). Suppression is per line or
#                  per doc block, never per file.
#   Naming       — Clean Code Ch.2, five advisory heuristics (never FAIL): a
#                  single-character identifier other than i/j/k/_, a noise word
#                  (Manager/Processor/Helper/Util/Data/Info) in a type name, an
#                  encoded (Hungarian) identifier prefix, a boolean flag
#                  parameter whose name does not read as a predicate, and a
#                  function with more than three parameters. Java/Go/JS/TS/
#                  Python/Rust non-test code; not shell.
#   Null discipline — Clean Code Ch.7 "Don't Return Null" / "Don't Pass Null":
#                  `return null` and a `null` literal passed as a call argument
#                  are reported. Comparisons, local assignments and ternary
#                  branches are not. Always WARN. Java/JS/TS only — Python and
#                  Rust nullability semantics differ.
#
# Rollout (spec 032, ADR 0011): the `comments` gate is WARN by default and joins
# the blocking set only under STRICT_CLEAN_CODE=1 (only the literal value `1`
# counts) or an explicit `--blocking comments`. `naming` and `null-discipline`
# are advisory-only and never emit FAIL. Findings in .py/.rs files stay WARN
# even under STRICT_CLEAN_CODE=1 (ADR 0006 D6 warn phase).
#
# Comment scanning covers the eight source extensions above plus `*.sh`; block-
# comment syntax is only parsed for the C-family/Rust extensions, shell and
# Python comments run from `#` to end of line. Paths under docs/, specs/,
# agents/, templates/ and node_modules/ are excluded from comment scanning
# (prose and agent prompts are not code).
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
#                                           [--require-language <lang>]
#
# --require-language <lang> (ADR 0006 D5): opt-in strictness for child repos
# that know what they are. Exits 1 when zero files of <lang> are found under
# SOURCE_DIR, exits 0 (normal run) when at least one is present. Valid names:
# java, go, node (aliases: js, ts, javascript, typescript), python (py),
# rust (rs). Without this flag a zero-file scan still exits 0 — a hard failure
# would break docs-only repos and uncovered languages (ADR 0006 Alternative A).
#
# SOURCE_DIR defaults to the current directory. --tier overrides auto-detection
# from the project's AGENTS_*.md "Conformance tier:" declaration (see
# docs/CONFORMANCE_TIERS.md). --warn-as-error promotes every WARN to a failure.
# --gates restricts the run to a comma-separated subset of the nine gate
# categories (complexity, dry, yagni, solid, component-per-file, property-tests,
# comments, naming, null-discipline) — the Verifier's
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
#   solid (SRP/OCP/LSP/ISP/DIP as one unit), component-per-file, property-tests,
#   comments, naming, null-discipline.
#   Default blocking set: complexity,property-tests,component-per-file — the
#   objective gates in this repo's terms (component-per-file is mvp-tier, cheap
#   heuristic — BookingWidget 14-in-1 must not pass). A gate outside the
#   blocking set is warn-only and never emits FAIL, with or without -BaseRef
#   (DIP and YAGNI single-implementation findings therefore report as WARN).
#   `comments` is warn-only by default and joins the blocking set either through
#   an explicit --blocking/PRINCIPLES_BLOCKING_GATES entry or through
#   STRICT_CLEAN_CODE=1 (spec 032, ADR 0011); only its two blocking-class rules
#   are affected — the three advisory comment rules stay WARN in every mode.
#   `naming` and `null-discipline` are advisory-only: they never emit FAIL, no
#   matter what names the blocking set.
#   Override with --blocking <comma-list> or the
#   PRINCIPLES_BLOCKING_GATES environment variable (flag wins over env
#   over default); an unknown gate name or an empty value exits 2.
#   Language scoping (ADR 0006 D6): python and rust are in WARN_ONLY_LANGS —
#   their findings are demoted to WARN before the blocking set is consulted,
#   so no --blocking value can make a .py/.rs finding fail during the warn
#   phase. Promote by removing the language from WARN_ONLY_LANGS (phase 2).
#
# Exit codes:
#   0 — no FAILs (WARNs may exist), or no source files to check
#   1 — at least one FAIL (or a WARN with --warn-as-error), or
#       --require-language <lang> named a language with zero files found
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
# Per-gate analyzers (DRY / YAGNI / SOLID / component-per-file / property-tests):
# the analysis lives in scripts/gate-analysis-lib.sh, so this script keeps
# registration, classification and dispatch.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-analysis-lib.sh"
# spec 032 clean-code gates (comments / naming / null-discipline). The analyzers,
# their awk programs, the comment discovery set and the STRICT_CLEAN_CODE
# promotion rule live there, so this script keeps registration, classification
# and dispatch — see scripts/gate-clean-code-lib.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gate-clean-code-lib.sh"

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
# Property-tests skip reason is said once per run, not once per language: the
# reason is the tier, not the language.
PROP_TESTS_SKIP_SAID=false

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
REQUIRE_LANG=""
REQUIRE_LANG_SET=false

# ── ADR 0006 D6 warn phase ────────────────────────────────────────────────────
# Languages listed here are warn-only for one release: classify()/
# classify_blame() demote every finding in their files to WARN before the
# blocking set is consulted, so new-language coverage cannot change the exit
# status. PATH TO PROMOTION (phase 2): remove the language from this list —
# nothing else gates on it — and update the header docs above.
WARN_ONLY_LANGS="python rust"
is_warn_only_lang() { # is_warn_only_lang <lang> — 0 while <lang> is in the D6 warn phase
  local l
  [ -n "${1:-}" ] || return 1
  for l in $WARN_ONLY_LANGS; do [ "$l" = "$1" ] && return 0; done
  return 1
}
lang_of_file() { # lang_of_file <path> — analyzer language for a file extension ("" = legacy language)
  case "$1" in
    *.py) echo python ;;
    *.rs) echo rust ;;
    *) echo "" ;;
  esac
}

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
      require-language) REQUIRE_LANG="${2:-}"; REQUIRE_LANG_SET=true; shift $(( $# > 1 ? 2 : 1 )) ;;
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

# ── --require-language validation (ADR 0006 D5) ──────────────────────────────
if [ "$REQUIRE_LANG_SET" = true ]; then
  if [ -z "$REQUIRE_LANG" ]; then
    echo "Error: --require-language requires a language name (java, go, node, python, rust)" >&2
    exit 2
  fi
  case "$REQUIRE_LANG" in
    java|go|node|python|rust) ;;
    js|ts|javascript|typescript) REQUIRE_LANG=node ;;
    py) REQUIRE_LANG=python ;;
    rs) REQUIRE_LANG=rust ;;
    *) echo "Error: unknown --require-language value: '$REQUIRE_LANG' (valid: java, go, node, python, rust)" >&2; exit 2 ;;
  esac
fi

# ── Blocking set (which gates may emit FAIL) ─────────────────────────────────
# Gate names: complexity, dry, yagni, solid, component-per-file, property-tests,
# comments, naming, null-discipline. Default:
# complexity,property-tests,component-per-file (the objective gates). --blocking wins over the
# PRINCIPLES_BLOCKING_GATES env var, which wins over the default.
blocking_raw() { # blocking_raw — resolve --blocking / env var / default into a raw comma list
  if [ "$BLOCKING_ARG_SET" = true ]; then
    [ -n "$BLOCKING_ARG" ] || { echo "Error: --blocking requires a comma-separated list of gates (complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline)" >&2; exit 2; }
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
    complexity|dry|yagni|solid|component-per-file|property-tests|comments|naming|null-discipline) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_blocking_set() {
  local raw g
  raw=$(blocking_raw | tr -d '[:space:]')
  BLOCKING_SET=""
  for g in $(printf '%s' "$raw" | tr ',' '\n' | sed '/^$/d'); do
    if ! valid_gate "$g"; then
      echo "Error: unknown gate name in blocking set: '$g' (valid gates: complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline)" >&2
      exit 2
    fi
    BLOCKING_SET="${BLOCKING_SET}${BLOCKING_SET:+ }$g"
  done
  [ -n "$BLOCKING_SET" ] || { echo "Error: blocking set is empty — must name at least one of: complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline" >&2; exit 2; }
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
    echo "ERROR: --gates requires a comma-separated list of gate names (complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline)" >&2
    exit 2
  fi
  IFS=',' read -r -a gate_list <<< "$GATES"
  for g in "${gate_list[@]}"; do
    case "$g" in
      complexity|dry|yagni|solid|component-per-file|property-tests|comments|naming|null-discipline) SELECTED_GATES+=("$g") ;;
      *) echo "ERROR: unknown gate '$g' (valid: complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline)" >&2; exit 2 ;;
    esac
  done
else
  SELECTED_GATES=(complexity dry yagni solid component-per-file property-tests comments naming null-discipline)
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
FIND_PRUNE='( -name node_modules -o -name target -o -name vendor -o -name .git -o -name dist -o -name build )'

JAVA_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.java' -print 2>/dev/null || true)
GO_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.go' -print 2>/dev/null || true)
NODE_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \) -print 2>/dev/null || true)
PY_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.py' -print 2>/dev/null || true)
RS_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.rs' -print 2>/dev/null || true)

# Comment scanning (spec 032, Task 03) has its own discovery set: the eight
# extensions above plus *.sh, and a path-segment exclusion for prose/prompt
# trees (docs/, specs/, agents/, templates/, node_modules/). This set is used
# ONLY by the three new gates — every existing gate keeps the file sets above
# byte-for-byte, so a .sh file never reaches the complexity analyzer.
SH_FILES=$(find "$SOURCE_DIR" $FIND_PRUNE -prune -o -name '*.sh' -print 2>/dev/null || true)

# The comment gate's own file set: the six discovery lists above, minus the
# prose/prompt trees (docs/, specs/, agents/, templates/, node_modules/). The
# exclusion lives in the lib beside the gate that needs it.
COMMENT_FILES=$(cc_comment_files "$SOURCE_DIR" $JAVA_FILES $GO_FILES $NODE_FILES $PY_FILES $RS_FILES $SH_FILES)

# --require-language (ADR 0006 D5): the caller declared the language this repo
# is written in — zero files of it is a failure (exit 1), not a silent pass.
if [ "$REQUIRE_LANG_SET" = true ]; then
  REQ_FOUND=""
  case "$REQUIRE_LANG" in
    java) REQ_FOUND="$JAVA_FILES" ;;
    go) REQ_FOUND="$GO_FILES" ;;
    node) REQ_FOUND="$NODE_FILES" ;;
    python) REQ_FOUND="$PY_FILES" ;;
    rust) REQ_FOUND="$RS_FILES" ;;
  esac
  if [ -z "$REQ_FOUND" ]; then
    echo "ERROR: --require-language $REQUIRE_LANG: no matching source files found under $SOURCE_DIR — expected at least one" >&2
    exit 1
  fi
  say "--require-language $REQUIRE_LANG: matching source files found under $SOURCE_DIR"
fi

# ADR 0006 D5: enumerate exactly which extensions were scanned so a repo in an
# uncovered language visibly reports that nothing matched, instead of implying
# it was checked. Still exit 0 by default (Alternative A — hard-failing zero
# files — breaks docs-only repos and uncovered languages). Spec 032 adds `sh`
# to the enumeration: a shell-only tree is scanned by the `comments` gate, so it
# must not report "nothing was analysed".
[ -z "$JAVA_FILES" ] && [ -z "$GO_FILES" ] && [ -z "$NODE_FILES" ] && [ -z "$PY_FILES" ] && [ -z "$RS_FILES" ] && [ -z "$SH_FILES" ] && {
  finish_clean "No source files found under $SOURCE_DIR — scanned for extensions: java, go, ts, tsx, js, jsx, py, rs, sh; none matched, so nothing was analysed. If this repo uses another language it is NOT covered by this gate; pass --require-language <lang> to fail instead of silently passing."
}

say "Checking design principles in: $SOURCE_DIR (tier: $TIER)"
say ""

# Non-test source files (principles apply to production code).
NONTEST_JAVA=$(echo "$JAVA_FILES" | grep -vE '/test/|/tests/|src/test/' || true)
NONTEST_GO=$(echo "$GO_FILES" | grep -vE '_test\.go$' || true)
NONTEST_NODE=$(echo "$NODE_FILES" | grep -vE '\.(test|spec)\.(ts|tsx|js|jsx)$|/test/|/tests/|__tests__/' || true)
# Python: pytest/unittest conventions (test_*.py, *_test.py, tests/ dirs, conftest).
NONTEST_PY=$(echo "$PY_FILES" | grep -vE '/tests?/|(^|/)test_[^/]*\.py$|_test\.py$|(^|/)conftest\.py$' || true)
# Rust: the tests/ integration dir. #[cfg(test)] modules inside src/ cannot be
# filtered by filename — same approximation the other languages already make.
NONTEST_RS=$(echo "$RS_FILES" | grep -vE '/tests?/|(^|/)tests?\.rs$' || true)

ALL_NONTEST="$NONTEST_JAVA $NONTEST_GO $NONTEST_NODE $NONTEST_PY $NONTEST_RS"
ALL_NONTEST=$(echo "$ALL_NONTEST" | tr ' ' '\n' | sed '/^$/d' | sort -u)

# ── Analyzers ────────────────────────────────────────────────────────────────
# DRY / YAGNI / SOLID / component-per-file / property-tests: the analyzers and
# their awk programs live in scripts/gate-analysis-lib.sh. The three clean-code
# gates (comments / naming / null-discipline) live in
# scripts/gate-clean-code-lib.sh, together with the comment discovery set. The
# complexity/KISS analyzer stays here — it shares the LOC splitting and
# reporting helpers with the run block. Only the dispatch of any of them stays
# below.

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
  if (lang=="rust") {
    # Rust: `fn name(...) [-> T] {` with the opening brace at end of line.
    # Approximate: `match x {` and closures are not method starts; a `{` on a
    # later line (long where-clauses) is missed — undercount, never a false
    # positive.
    return (h ~ /(^|[ \t])fn[ \t]+[A-Za-z0-9_]/ && h ~ /\{[ \t]*$/) ? 1 : 0
  }
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
  if (lang=="rust") {
    sub(/^[ \t]*(pub([ \t]*\([^)]*\))?[ \t]+)?((async|unsafe|const|extern)[ \t]+)*fn[ \t]+/,"",h)
    sub(/[<(].*/,"",h); sub(/[ \t].*/,"",h)
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
  if (LANG=="rust") {
    # Rust has no ternary `?` (postfix `?` is the try operator — not a branch),
    # but `match`/`loop` and each `=>` arm are decision points. Approximate:
    # `||` is also the zero-arg closure form, which overcounts here.
    c += gsub(/(^|[^A-Za-z0-9_])(match|loop)([^A-Za-z0-9_]|$)/," ",line)
    c += gsub(/=>/," ",line)
  } else {
    c += gsub(/\?/," ",line)
  }
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

# ── Python complexity + KISS analyzer (awk, indent-based) ────────────────────
# Python has no braces, so the analyzer above cannot serve it: function bodies
# are tracked by indentation instead of brace depth. Heuristic and approximate
# (ADR 0006): comprehension `for`/`if` clauses count as decision points (they
# are branches, but a dense comprehension inflates the count); decorator stacks
# and multi-line signatures are handled only approximately; blank/comment lines
# do not count toward body length. Findings for python are emitted as warnings
# that say they are approximate (D6 warn phase).
complexity_awk_py="$(cat <<'AWK'
function cleanpy(s,   i,n,c,out,q) {
  out=""; i=1; n=length(s)
  while (i<=n) {
    c=substr(s,i,1)
    if (c=="#") break
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
function pyname(h,   t) {
  t=h
  sub(/^[ \t]*(async[ \t]+)?def[ \t]+/,"",t)
  sub(/\(.*/,"",t); sub(/[ \t:].*/,"",t)
  return t
}
function pyparams(h,   p,c,i,n,instr,ch) {
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
function pytokens(line,   c) {
  # Decision keywords. `and`/`or` short-circuit like &&/||; the inline ternary
  # `a if b else c` and comprehension `for`/`if` clauses are counted wherever
  # they appear — deliberate overcount, flagged as approximate in the message.
  c += gsub(/(^|[^A-Za-z0-9_])(if|elif|for|while|except|and|or)([^A-Za-z0-9_]|$)/," ",line)
  return c
}
function begin_py(line, indent) {
  top++
  STACK[top,"i"] = indent
  STACK[top,"n"] = pyname(line)
  STACK[top,"l"] = FNR
  STACK[top,"c"] = 1
  STACK[top,"lines"] = 1
  STACK[top,"params"] = pyparams(line)
}
function end_py( ) {
  if (top<0) return
  if (STACK[top,"c"] > 6)
    printf "%s:%d:%d:%s:CC=%d\n", FILENAME, STACK[top,"l"], FNR, STACK[top,"n"], STACK[top,"c"]
  if (STACK[top,"lines"] > 20)
    printf "%s:%d:%d:%s:KISS_LINES=%d\n", FILENAME, STACK[top,"l"], FNR, STACK[top,"n"], STACK[top,"lines"]
  if (STACK[top,"params"] > 6)
    printf "%s:%d:%d:%s:KISS_PARAMS=%d\n", FILENAME, STACK[top,"l"], FNR, STACK[top,"n"], STACK[top,"params"]
  top--
}
FNR==1 { top=-1 }
{
  if ($0 ~ /^[ \t]*$/) next
  line=cleanpy($0)
  if (line ~ /^[ \t]*$/) next
  indent=match(line,/[^ \t]/)-1
  while (top>=0 && indent <= STACK[top,"i"]) end_py()
  if (line ~ /^[ \t]*(async[ \t]+)?def[ \t]+[A-Za-z0-9_]/) begin_py(line, indent)
  if (top>=0) {
    STACK[top,"c"] += pytokens(line)
    STACK[top,"lines"]++
  }
}
END { while (top>=0) end_py() }
AWK
)"

# report_complexity_finding <lang> <approx-note> <analyzer-line> — route one
# `file:start:end:name:RULE=n` record through classify(), so -BaseRef blame
# scoping applies. `CC=` is a defect (legacy FAIL); body length and parameter
# count are review hints (legacy WARN).
report_complexity_finding() {
  local lang="$1" approx="$2" line="$3" f s e
  [ -z "$line" ] && return 0
  f=$(printf '%s' "$line" | cut -d: -f1)
  s=$(printf '%s' "$line" | cut -d: -f2)
  e=$(printf '%s' "$line" | cut -d: -f3)
  case "$line" in
    *CC=*) emit "$(classify "complexity" "fail" "$f" "$s" "$e" "$lang")" "Cyclomatic complexity >6 ($lang): $line$approx" "$f" "$s" ;;
    *KISS_LINES=*) emit "$(classify "complexity" "warn" "$f" "$s" "$e" "$lang")" "Method body >20 lines ($lang): $line$approx" "$f" "$s" ;;
    *KISS_PARAMS=*) emit "$(classify "complexity" "warn" "$f" "$s" "$e" "$lang")" "Method with >6 parameters ($lang): $line$approx" "$f" "$s" ;;
  esac
}

# complexity_analyzer <lang> — set CC_PROG to the analyzer program for <lang>
# and CC_APPROX to the note its findings carry. Python needs the indent-based
# program (no braces); Rust reuses the brace-based one and says why its count is
# approximate.
complexity_analyzer() {
  CC_PROG="$complexity_awk"
  CC_APPROX=""
  case "$1" in
    python)
      CC_PROG="$complexity_awk_py"
      CC_APPROX=" [approximate heuristic — comprehension/decorator forms can inflate the count; ADR 0006 warn phase]" ;;
    rust)
      CC_APPROX=" [approximate heuristic — match arms/generic bounds/closures can inflate the count; ADR 0006 warn phase]" ;;
  esac
}

run_complexity_kiss() {
  local lang="$1"
  shift
  local files=("$@")
  [ "${#files[@]}" -eq 0 ] && return 0
  complexity_analyzer "$lang"
  local out rc=0 line
  # No `|| true` swallow: an awk/xargs failure means the check could not run —
  # that is a tooling failure (exit 2), never a silent PASS (AC-007-03-07).
  out=$(printf '%s\n' "${files[@]}" | xargs awk -v LANG="$lang" "$CC_PROG" 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ERROR: complexity/KISS analyzer failed to run (awk/xargs) — cannot complete the check" >&2
    exit 2
  fi
  [ -z "$out" ] && { pass "Complexity/KISS ($lang): no violations found"; return 0; }
  while IFS= read -r line; do
    report_complexity_finding "$lang" "$CC_APPROX" "$line"
  done <<< "$out"
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
  # ADR 0011 rollout: STRICT_CLEAN_CODE=1 is the opt-in that adds `comments`
  # to the blocking set, so -BaseRef blame semantics still apply (pre-existing
  # debt stays WARN; a diff-overlapping line FAILs). The env-value rule (only
  # the literal `1` promotes) lives in gate-clean-code-lib.sh. `naming` and
  # `null-discipline` are never promoted.
  if [ "$1" = "comments" ] && cc_comments_forced_blocking; then return 0; fi
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

# range_contains <start> <end> <range> — 0 when <range> ("s-e") overlaps
# [start, end]. Split out of ranges_overlap so the scan and the comparison each
# read as one thing.
range_contains() {
  local s="${3%%-*}" e="${3#*-}"
  [ "$2" -ge "$s" ] && [ "$1" -le "$e" ]
}

# ranges_hit <start> <end> <ranges> — 0 when any space-separated "s-e" in
# <ranges> overlaps [start, end].
ranges_hit() {
  local r
  for r in $3; do
    range_contains "$1" "$2" "$r" && return 0
  done
  return 1
}

ranges_overlap() { # ranges_overlap <absfile> <start> <end> — 0 if any added range overlaps
  [ -f "$BLAME_RANGES" ] || return 1
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    ranges_hit "$2" "$3" "${line#*$'\t'}" && return 0
  done < <(grep -F "$1"$'\t' "$BLAME_RANGES" 2>/dev/null || true)
  return 1
}

# blame_overlaps_diff <absfile> <start> <end> — 0 when the finding is
# diff-introduced: its lines overlap an added line, or (for a file-level finding
# with no line anchor) the file was touched at all.
blame_overlaps_diff() {
  file_fully_added "$1" && return 0
  [ -n "$2" ] || return 0
  ranges_overlap "$1" "$2" "$3"
}

classify_blame() { # classify_blame <gate> <file> <start> <end> [lang] → fail|warn|none under -BaseRef
  local gate="$1" file="$2" start="$3" end="$4" lang="${5:-}" af
  af=$(abs_of "$file")
  if ! file_touched "$af"; then echo none; return; fi
  if is_warn_only_lang "$lang"; then echo warn; return; fi  # ADR 0006 D6 warn phase
  if ! is_blocking "$gate"; then echo warn; return; fi
  if blame_overlaps_diff "$af" "$start" "$end"; then echo fail; return; fi
  echo warn
}

classify() { # classify <gate> <legacy> <file> <start> <end> [lang] → fail|warn|none
  local gate="$1" legacy="$2" lang="${6:-}"
  if [ -n "$BASE_REF" ]; then
    classify_blame "$gate" "$3" "$4" "$5" "$lang"
    return
  fi
  if is_warn_only_lang "$lang"; then echo warn; return; fi  # ADR 0006 D6 warn phase
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

# mark_untracked_added <repo_root> <repo-relative path>... — an untracked (and
# not gitignored) audited file is entirely diff-introduced: it counts as both
# touched and fully added.
mark_untracked_added() {
  local repo_root="$1"
  shift
  local untracked u
  untracked=$(printf '%s\0' "$@" | xargs -0 git -C "$repo_root" ls-files --others --exclude-standard -- 2>/dev/null || true)
  while IFS= read -r u; do
    [ -z "$u" ] && continue
    echo "$repo_root/$u" >> "$BLAME_TOUCHED"
    echo "$repo_root/$u" >> "$BLAME_FULLY_ADDED"
  done <<< "$untracked"
}

compute_diff() { # compute_diff <newline-separated audited files>
  local files="$1" repo_root errf rel=() diffout
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
  mark_untracked_added "$repo_root" "${rel[@]}"
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
  run_complexity_kiss python $NONTEST_PY
  run_complexity_kiss rust $NONTEST_RS
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
  check_yagni "$NONTEST_PY" python
  check_yagni "$NONTEST_RS" rust
  say ""
fi

if contains_gate solid; then
  say "--- SOLID ---"
  check_solid_srp "$NONTEST_JAVA" java
  check_solid_srp "$NONTEST_GO" go
  check_solid_srp "$NONTEST_NODE" node
  check_solid_srp "$NONTEST_PY" python
  check_solid_srp "$NONTEST_RS" rust
  check_solid_ocp "$NONTEST_JAVA" java
  check_solid_ocp "$NONTEST_GO" go
  check_solid_ocp "$NONTEST_NODE" node
  check_solid_ocp "$NONTEST_PY" python
  check_solid_ocp "$NONTEST_RS" rust
  check_solid_lsp "$NONTEST_JAVA" java
  check_solid_lsp "$NONTEST_NODE" node
  check_solid_lsp "$NONTEST_PY" python
  check_solid_isp "$NONTEST_JAVA" java
  check_solid_isp "$NONTEST_NODE" node
  check_solid_isp "$NONTEST_PY" python
  check_solid_isp "$NONTEST_RS" rust
  check_solid_dip java
  check_solid_dip go
  check_solid_dip node
  check_solid_dip python
  check_solid_dip rust
  say ""
fi

# component-per-file is JS/TS-scoped by design (ADR 0006 D1) — never run for
# Python or Rust.
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
  check_property_tests python
  check_property_tests rust
  say ""
fi

# The three spec-032 gates (analyzers in scripts/gate-clean-code-lib.sh).
# `comments` scans its own discovery set (eight extensions + *.sh, prose/prompt
# trees excluded); `naming` reuses the eight existing non-test sets (never
# shell); `null-discipline` is Java/JS/TS only.
if contains_gate comments; then
  say "--- Comments ---"
  run_comments_gate $COMMENT_FILES
  say ""
fi

if contains_gate naming; then
  say "--- Naming ---"
  run_naming_gate $ALL_NONTEST
  say ""
fi

if contains_gate null-discipline; then
  say "--- Null discipline ---"
  run_null_discipline_gate $NONTEST_JAVA $NONTEST_NODE
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
[ "${#SELECTED_GATES[@]}" -lt 9 ] && GATE_SUMMARY="(gates: $(IFS=,; echo "${SELECTED_GATES[*]}"))"

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
