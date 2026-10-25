#!/bin/bash
# gate-analysis-lib.sh — the per-gate analyzers behind the design-principles
# checker's DRY, YAGNI, SOLID (SRP/OCP/LSP/ISP/DIP), component-per-file and
# property-tests gates (specs 007, 011, 012).
#
# Sourced by scripts/check-code-principles.sh, which keeps what a dispatcher
# keeps: gate registration, flag parsing, the finding pipeline
# (fail/warn/classify/emit), blame scoping, JSON reporting, and per-gate
# dispatch. This lib holds only the analysis, so a change to a duplicate-block
# window, an SRP bound, or a language's dispatch pattern is a change to this
# file rather than to the dispatcher.
#
# Sourcing defines functions only — no shell flags, no assignments, no I/O — so
# the sourcing script's own `set -euo pipefail` governs. The functions read the
# dispatcher's globals, which is the contract:
#
#   SOURCE_DIR  GREP_EXCLUDES  TIER
#   JAVA_FILES  GO_FILES  NODE_FILES  PY_FILES  RS_FILES — tests included
#   PROP_TESTS_SKIP_SAID — the said-once latch
#
# and report findings through the dispatcher's pipeline: emit(), classify(),
# pass(), warn(), fail(). An analyzer that cannot run exits 2 — never a silent
# PASS (AC-007-03-07).

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
      sev=$(classify "dry" "warn" "$dfile" "$dline" "$dline" "$(lang_of_file "$dfile")")
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
          # Go declares the name BEFORE the keyword (`type X interface {`), unlike
          # Java's `interface X`. Match the Go form and tolerate a non-match:
          # bare `grep -o` returns 1 on no match, which aborts under pipefail.
          name=$(echo "$iface" | grep -oE 'type[ \t]+[A-Za-z0-9_]+[ \t]+interface' | awk '{print $2}' || true)
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
    python)
      # ABC/Protocol with exactly one concrete subclass = premature abstraction.
      # Approximate: subclassing detected textually, no import resolution.
      for f in $files; do
        [ -f "$f" ] || continue
        local lniface ln iface
        while IFS= read -r lniface; do
          [ -z "$lniface" ] && continue
          ln=${lniface%%:*}
          iface=${lniface#*:}
          name=$(echo "$iface" | grep -oE 'class[ \t]+[A-Za-z0-9_]+' | awk '{print $2}' || true)
          [ -z "$name" ] && continue
          impls=$(grep -rE "class[ \t]+[A-Za-z0-9_]+[ \t]*\([^)]*\b$name\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.py" 2>/dev/null | wc -l | tr -d ' ' || true)
          if [ "$impls" -eq 1 ]; then
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln" "$lang")" "YAGNI: Python ABC/Protocol $name has exactly one concrete subclass (premature abstraction) — $f:$ln" "$f" "$ln"
            found=true
          fi
        done < <(grep -nE '^[ \t]*class[ \t]+[A-Za-z0-9_]+[ \t]*\([^)]*(ABC|Protocol)[^)]*\)' "$f" 2>/dev/null || true)
        # Empty bodies: `pass` / `...` as the whole statement (approximate —
        # `pass` in an except branch is legitimate, hence WARN-level review hint).
        while IFS=: read -r ln _; do
          emit "$(classify "yagni" "warn" "$f" "$ln" "$ln" "$lang")" "Empty body (pass/...) ($lang): $f:$ln" "$f" "$ln"
          found=true
        done < <(grep -nE '^[ \t]*(pass|\.\.\.)[ \t]*(#.*)?$' "$f" 2>/dev/null | grep -vE 'test' || true)
      done
      ;;
    rust)
      # Trait with exactly one `impl ... Trait for` = premature abstraction.
      # Approximate: textual impl count, derive-macro and blanket impls counted
      # as written.
      for f in $files; do
        [ -f "$f" ] || continue
        local lniface ln iface
        while IFS= read -r lniface; do
          [ -z "$lniface" ] && continue
          ln=${lniface%%:*}
          iface=${lniface#*:}
          name=$(echo "$iface" | grep -oE 'trait[ \t]+[A-Za-z0-9_]+' | awk '{print $2}' || true)
          [ -z "$name" ] && continue
          impls=$(grep -rE "impl(<[^{;]*>)?[^{;]*\b$name\b[ \t]*for\b" $GREP_EXCLUDES "$SOURCE_DIR" --include="*.rs" 2>/dev/null | wc -l | tr -d ' ' || true)
          if [ "$impls" -eq 1 ]; then
            emit "$(classify "yagni" "fail" "$f" "$ln" "$ln" "$lang")" "YAGNI: Rust trait $name has exactly one implementation (premature abstraction) — $f:$ln" "$f" "$ln"
            found=true
          fi
        done < <(grep -nE '^[ \t]*(pub([ \t]*\([^)]*\))?[ \t]+)?trait[ \t]+[A-Za-z0-9_]+' "$f" 2>/dev/null || true)
        while IFS=: read -r ln _; do
          emit "$(classify "yagni" "warn" "$f" "$ln" "$ln" "$lang")" "Empty body or empty block ($lang): $f:$ln" "$f" "$ln"
          found=true
        done < <(grep -nE '\{\s*\}' "$f" 2>/dev/null | grep -vE '//|test' || true)
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
      python) methods=$(grep -cE '^[ \t]*(async[ \t]+)?def[ \t]+' "$f" 2>/dev/null | tr -d ' ') || methods=0 ;;
      rust) methods=$(grep -cE '^[ \t]*(pub([ \t]*\([^)]*\))?[ \t]+)?((async|unsafe|const)[ \t]+)*fn[ \t]+' "$f" 2>/dev/null | tr -d ' ') || methods=0 ;;
      *) methods=0 ;;
    esac
    # Tightened SRP for TSX/JSX: >300 lines OR >8 components (god-file via component count).
    # BookingWidget 14-in-1 was 390 lines / 14 components and passed the old 400/15 gate.
    if [ "$lang" = "node" ]; then
      case "$f" in
        *.tsx|*.jsx)
          comp_count=$( (grep -E '^\s*(export\s+)?(default\s+)?(function\s+[A-Z]|const\s+[A-Z][A-Za-z0-9_]*\s*[:=][^;]*=>|const\s+[A-Z][A-Za-z0-9_]*\s*=\s*React\.(memo|forwardRef)|class\s+[A-Z])' "$f" 2>/dev/null || true) | wc -l | tr -d ' ') || comp_count=0
          if [ "$lines" -gt 300 ] || [ "$comp_count" -gt 8 ] || [ "$lines" -gt 400 ] || [ "$methods" -gt 15 ]; then
            emit "$(classify "solid" "warn" "$f" "" "" "$lang")" "SRP: possible god file ($lang) — $f: ${lines} lines, ${methods} methods, ${comp_count} components (TSX threshold: 300 lines / 8 components; general: 400 lines / 15 methods) — split by responsibility" "$f"
            found=true
          fi
          continue
          ;;
      esac
    fi
    if [ "$lines" -gt 400 ] || [ "$methods" -gt 15 ]; then
      # ADR 0012: god-file is WARN by default because promoting it would turn
      # existing consumer code red overnight. Consumers that have cleaned up
      # opt into blocking enforcement with STRICT_GOD_FILE=1 (CI env or make).
      # classify() would force "solid" back to warn (gate not in the blocking
      # list), so the opt-in emits fail directly.
      if [ "${STRICT_GOD_FILE:-0}" = "1" ]; then
        emit "fail" "SRP: god file ($lang) — $f: ${lines} lines, ${methods} methods (split by responsibility — STRICT_GOD_FILE=1: blocking)" "$f"
      else
        emit "$(classify "solid" "warn" "$f" "" "" "$lang")" "SRP: possible god file ($lang) — $f: ${lines} lines, ${methods} methods (split by responsibility)" "$f"
      fi
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
    case "$lang" in
      python)
        # if/elif dispatch chain (approximate: statement-leading elif only)
        eif=$(grep -cE '^[ \t]*elif' "$f" 2>/dev/null || true)
        if [ "${eif:-0}" -ge 4 ]; then
          eifline=$(grep -nE '^[ \t]*elif' "$f" 2>/dev/null | head -1 | cut -d: -f1)
          emit "$(classify "solid" "warn" "$f" "$eifline" "$eifline" "$lang")" "OCP: ${eif}-branch if/elif chain ($lang) — $f (consider polymorphism or a dispatch dict)" "$f" "$eifline"
          found=true
        fi
        ;;
      rust)
        # match with >=4 `=>` arms (approximate: arm counting is heuristic and
        # nested matches attribute arms to the outer match)
        res=$(awk '
          /(^|[^A-Za-z0-9_])match([^A-Za-z0-9_]|$)/ { swnr=FNR; arms=0; insw=1 }
          insw { arms += gsub(/=>/," ") }
          insw && /^[ \t]*\}/ { if (arms>=4) printf "%s:%d:match with %d arms\n", FILENAME, swnr, arms; insw=0 }
        ' "$f" 2>/dev/null || true)
        while IFS= read -r r; do
          [ -n "$r" ] || continue
          ocpfile=$(printf '%s' "$r" | cut -d: -f1)
          ocpline=$(printf '%s' "$r" | cut -d: -f2)
          emit "$(classify "solid" "warn" "$ocpfile" "$ocpline" "$ocpline" "$lang")" "OCP: type-dispatch match should be polymorphic ($lang, approximate arm count) — $r" "$ocpfile" "$ocpline"
          found=true
        done <<< "$res"
        ;;
      *)
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
          emit "$(classify "solid" "warn" "$ocpfile" "$ocpline" "$ocpline" "$lang")" "OCP: type-dispatch switch should be polymorphic ($lang) — $r" "$ocpfile" "$ocpline"
          found=true
        done <<< "$res"
        eif=$(grep -cE '^\s*else[ \t]+if' "$f" 2>/dev/null || true)
        if [ "${eif:-0}" -ge 4 ]; then
          eifline=$(grep -nE '^\s*else[ \t]+if' "$f" 2>/dev/null | head -1 | cut -d: -f1)
          emit "$(classify "solid" "warn" "$f" "$eifline" "$eifline" "$lang")" "OCP: ${eif}-branch if/else chain ($lang) — $f (consider polymorphism or a lookup)" "$f" "$eifline"
          found=true
        fi
        ;;
    esac
  done
  $found || pass "SOLID-OCP ($lang): no large type-dispatch chains"
}

check_solid_lsp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local pat label
  case "$lang" in
    java|node) pat='instanceof'; label='instanceof' ;;
    python) pat='isinstance[ \t]*\('; label='isinstance' ;;
    *) return 0 ;;  # go/rust: no idiomatic runtime type-test dispatch to count
  esac
  local found=false
  local f c
  for f in $files; do
    [ -f "$f" ] || continue
    c=$(grep -cE "$pat" "$f" 2>/dev/null || true)
    if [ "$c" -ge 3 ]; then
      emit "$(classify "solid" "warn" "$f" "" "" "$lang")" "LSP: ${c} ${label} checks in one file ($lang) — $f (suggests broken substitutability or type dispatch)" "$f"
      found=true
    fi
  done
  $found || pass "SOLID-LSP ($lang): no heavy ${label} dispatch"
}

check_solid_isp() {
  local files="$1"; local lang="$2"
  [ -z "$files" ] && return 0
  local found=false
  local res r ispfile ispline prog label
  case "$lang" in
    python)
      # Protocol/ABC with >5 methods (approximate: ends at the next column-0
      # statement, so nested classes are mis-attributed)
      label="Protocol/ABC"
      prog='
        /^[ \t]*class[ \t]+[A-Za-z0-9_]+[ \t]*\(.*(ABC|Protocol)/ { iw=1; nr=FNR; methods=0; next }
        iw && /^[^ \t#]/ { if (methods>5) printf "%s:%d:Protocol/ABC with %d methods\n", FILENAME, nr, methods; iw=0; next }
        iw && /^[ \t]*(async[ \t]+)?def[ \t]/ { methods++ }
      '
      ;;
    rust)
      # trait with >5 required/provided fns (approximate: ends at the first
      # column-indented closing brace)
      label="trait"
      prog='
        /^[ \t]*(pub([ \t]*\([^)]*\))?[ \t]+)?trait[ \t]+[A-Za-z0-9_]+/ { iw=1; nr=FNR; methods=0; next }
        iw && /^[ \t]*\}/ { if (methods>5) printf "%s:%d:trait with %d methods\n", FILENAME, nr, methods; iw=0; next }
        iw && /(^|[^A-Za-z0-9_])fn[ \t]+[A-Za-z0-9_]/ { methods++ }
      '
      ;;
    *)
      label="interface"
      prog='
        /^[ \t]*(public[ \t]+)?interface[ \t]+[A-Za-z0-9_]+/ { iw=1; nr=FNR; methods=0; next }
        iw && /^[ \t]*\}/ { if (methods>5) printf "%s:%d:interface with %d methods\n", FILENAME, nr, methods; iw=0; next }
        iw && /\([^)]*\)[ \t]*(;|\{|$)/ { methods++ }
      '
      ;;
  esac
  for f in $files; do
    [ -f "$f" ] || continue
    res=$(awk "$prog" "$f" 2>/dev/null || true)
    while IFS= read -r r; do
      [ -n "$r" ] || continue
      ispfile=$(printf '%s' "$r" | cut -d: -f1)
      ispline=$(printf '%s' "$r" | cut -d: -f2)
      emit "$(classify "solid" "warn" "$ispfile" "$ispline" "$ispline" "$lang")" "ISP: fat ${label} (>5 methods) — $r (split by role)" "$ispfile" "$ispline"
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
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln" "$lang")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln" "$f" "$dln"
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
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln" "$lang")" "DIP: domain/engine code imports store/infra/repository ($lang) — $f:$dln" "$f" "$dln"
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
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln" "$lang")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln" "$f" "$dln"
              found=true
            fi
            ;;
        esac
      done
      ;;
    python)
      for f in $PY_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*)
            hit=$(grep -nE '^[ \t]*(from|import)[ \t]+[A-Za-z0-9_.]*(infrastructure|persistence|repository)' "$f" 2>/dev/null || true)
            if [ -n "$hit" ]; then
              dln=$(printf '%s\n' "$hit" | head -1 | cut -d: -f1)
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln" "$lang")" "DIP: domain/engine code imports infrastructure ($lang) — $f:$dln" "$f" "$dln"
              found=true
            fi
            ;;
        esac
      done
      ;;
    rust)
      for f in $RS_FILES; do
        case "$f" in
          */domain/*|*/engine/*|*/core/*)
            hit=$(grep -nE '^[ \t]*use[ \t]+[^;]*(infra|infrastructure|repository|store|persistence)' "$f" 2>/dev/null || true)
            if [ -n "$hit" ]; then
              dln=$(printf '%s\n' "$hit" | head -1 | cut -d: -f1)
              emit "$(classify "solid" "fail" "$f" "$dln" "$dln" "$lang")" "DIP: domain/engine code imports store/infra/repository ($lang) — $f:$dln" "$f" "$dln"
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
    mvp)
      # Once per run, not once per language — the skip reason is tier, not lang.
      if [ "$PROP_TESTS_SKIP_SAID" = false ]; then
        say "Property tests: skipped (project tier is $TIER — production+ required)"
        PROP_TESTS_SKIP_SAID=true
      fi
      return 0 ;;
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
    python)
      # ADR 0006 D6 warn phase: absence is a WARN (never fail) for one release.
      # Like the other languages, property-tests is a presence check and is
      # never blame-scoped. Framework: hypothesis (de-facto Python standard;
      # docs/TESTING.md does not yet name one for Python).
      src=$PY_FILES
      if [ -n "$src" ]; then
        if grep -rE '\bhypothesis\b|@given\(' $GREP_EXCLUDES "$SOURCE_DIR" --include="*.py" >/dev/null 2>&1 \
           || grep -qE 'hypothesis' "$SOURCE_DIR/pyproject.toml" 2>/dev/null \
           || grep -qE '^hypothesis' "$SOURCE_DIR"/requirements*.txt 2>/dev/null; then
          pass "Property tests ($lang): hypothesis in use"
        else
          warn "Property tests ($lang): no hypothesis property tests found (required at $TIER tier) — WARN only during the ADR 0006 D6 warn phase"
        fi
      fi
      ;;
    rust)
      # ADR 0006 D6 warn phase: absence is a WARN (never fail) for one release.
      # Framework: proptest (nominated by language-specific/rust/TESTING.md);
      # quickcheck also accepted.
      src=$RS_FILES
      if [ -n "$src" ]; then
        if grep -rE '\bproptest\b|\bquickcheck\b' $GREP_EXCLUDES "$SOURCE_DIR" --include="*.rs" >/dev/null 2>&1 \
           || grep -qE '^(proptest|quickcheck)' "$SOURCE_DIR/Cargo.toml" 2>/dev/null; then
          pass "Property tests ($lang): proptest/quickcheck in use"
        else
          warn "Property tests ($lang): no proptest/quickcheck property tests found (required at $TIER tier) — WARN only during the ADR 0006 D6 warn phase"
        fi
      fi
      ;;
  esac
}
