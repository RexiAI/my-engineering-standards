#!/bin/bash
# gate-clean-code-lib.sh — the spec 032 clean-code gates: `comments`, `naming`,
# and `null-discipline`.
#
# Sourced by scripts/check-code-principles.sh, which keeps what a dispatcher
# keeps: gate registration, flag parsing, the finding pipeline (fail/warn/
# classify/emit), blame scoping, and per-gate dispatch. This lib holds the trio's
# analysis — the three awk programs, the comment discovery set, the one
# classify()+emit() composition they share, and the STRICT_CLEAN_CODE promotion
# rule. Same reason-to-change test as gate-report-lib.sh and check-common.sh: a
# change to a comment rule, a naming heuristic or the allowlist is a change to
# this file, never to the dispatcher.
#
# Sourcing defines functions only — no shell flags, no assignments, no I/O — so
# the sourcing script's own `set -euo pipefail` governs. The functions call back
# into the dispatcher, which is the contract:
#
#   emit         <severity> <message> [file] [line]     route one finding
#   classify     <gate> <legacy> <file> <start> <end> [lang]  fail|warn|none
#   lang_of_file <path>                                 analyzer language ("" = legacy)
#   pass         <message>                              a gate-clean line
#
# and an analyzer that cannot run exits 2 — never a silent PASS (AC-007-03-07).

# ── Shared plumbing ──────────────────────────────────────────────────────────

# cc_analyze <label> <awk-program> <file>... — run <awk-program> over <file>...
# and set CC_FINDINGS to its output. An awk/xargs failure means the check could
# not run: exit 2, never a silent PASS.
cc_analyze() {
  local label="$1" prog="$2"
  shift 2
  local rc=0
  CC_FINDINGS=""
  [ "$#" -eq 0 ] && return 0
  CC_FINDINGS=$(printf '%s\n' "$@" | xargs awk "$prog" 2>&1) || rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ERROR: ${label} analyzer failed to run (awk/xargs) — cannot complete the check" >&2
    exit 2
  fi
}

# cc_emit <gate> <legacy-severity> <file> <start> <end> <message> — the single
# place the clean-code gates compose classify() + lang_of_file() + emit(), so
# the language lookup and the -BaseRef scoping are written once instead of once
# per rule. classify() answering `none` emits nothing.
cc_emit() {
  local gate="$1" legacy="$2" file="$3" start="$4" end="$5" msg="$6"
  emit "$(classify "$gate" "$legacy" "$file" "$start" "$end" "$(lang_of_file "$file")")" \
    "$msg" "$file" "$start"
}

# cc_comments_forced_blocking — 0 when the environment promotes the `comments`
# gate into the blocking set (ADR 0011 rollout). Only the literal value `1`
# promotes; `0`, `true` and the empty string all leave it warn-only.
cc_comments_forced_blocking() {
  [ "${STRICT_CLEAN_CODE:-}" = "1" ]
}

# ── Comment discovery ────────────────────────────────────────────────────────
# The `comments` gate scans its own file set: the eight source extensions plus
# `*.sh`, minus the prose/prompt trees. Every other gate keeps its own set
# byte-for-byte, so a shell file can never reach an analyzer that cannot parse
# it.

# cc_rel_path <source_dir> <path> — <path> as the scanner prints it, relative to
# the scanned root, so the segment exclusion matches `src/a.sh` whether the
# caller passed `.` or an absolute directory.
cc_rel_path() {
  case "$2" in
    "$1"/*) printf '%s' "${2#"$1"/}" ;;
    ./*) printf '%s' "${2#./}" ;;
    *) printf '%s' "$2" ;;
  esac
}

# cc_comment_files <source_dir> <candidate>... — the audited paths, one per
# line. A candidate under docs/, specs/, agents/, templates/ or node_modules/ is
# prose or agent prompt, not code, and is skipped.
cc_comment_files() {
  local src="$1"
  shift
  local p rel
  for p in "$@"; do
    [ -n "$p" ] || continue
    rel=$(cc_rel_path "$src" "$p")
    case "/$rel/" in
      */docs/*|*/specs/*|*/agents/*|*/templates/*|*/node_modules/*) continue ;;
    esac
    printf '%s\n' "$p"
  done
}

# ── Comments (Clean Code Ch.4: redundant-comment elimination) ────────────────
# Not a comment ban: the eight endorsed kinds survive via the allowlist. Five
# rules, two blocking-class (commented-out code, restating comment) and three
# advisory (TODO/FIXME without a reference, section divider, attribution).
# The code-shape predicate is a conservative shape test, never a prose-word
# blacklist: a comment is code-shaped when its content ends in `;`/`{`/`}` or
# `)`, is an assignment (`name = expr` / `name := expr`, but not `==`, `!=`,
# `=>`), or opens a control statement (`if`/`for`/`while`/`switch`/`catch`).

# cc_comments_prog — the comment analyzer. Each record is TAB-separated
# `file line rule end`: `rule` names the finding, `end` closes a multi-line run
# (equal to `line` for a single-line finding).
cc_comments_prog() {
  cat <<'AWK'
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function codeshape(s,   t) {
  t = trim(s)
  if (t == "") return 0
  if (t ~ /[;{}]$/) return 1
  if (t ~ /^[A-Za-z_$][A-Za-z0-9_.$]*[ \t]*:?=[ \t]*[^=>]/) return 1
  if (t ~ /(^|[^A-Za-z0-9_])(if|for|while|switch|catch)[ \t]*\(/) return 1
  if (t ~ /\)$/) return 1
  return 0
}

# Allowlist: endorsed comment kinds never count as redundancy (Task 07).
function allowlisted(s) {
  return (s ~ /shellcheck/ || s ~ /noqa/ || s ~ /type: ignore/ ||
          s ~ /pragma/ || s ~ /ponytail:/ || s ~ /standards:allow-/ ||
          s ~ /SPDX-License-Identifier/ || s ~ /Copyright/ ||
          s ~ /Licensed under/ || s ~ /@license/ ||
          s ~ /http:\/\// || s ~ /https:\/\//)
}

function isdivider(s,   i, c) {
  if (length(s) < 3) return 0
  c = substr(s, 1, 1)
  if (index("=-*#~─_", c) == 0) return 0
  for (i = 2; i <= length(s); i++) { if (substr(s, i, 1) != c) return 0 }
  return 1
}

function ntok(s, SET, LIST,   i, n, cur, c, cnt, k) {
  # Fill SET (token -> 1) for the subset test and LIST (1..cnt) for the comment
  # side. Both are cleared first: stale keys would make the subset test lie.
  for (k in SET) delete SET[k]
  for (k in LIST) delete LIST[k]
  s = tolower(s); cnt = 0; cur = ""; n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (c ~ /[a-z0-9]/) { cur = cur c }
    else if (cur != "") { cnt++; LIST[cnt] = cur; SET[cur] = 1; cur = "" }
  }
  if (cur != "") { cnt++; LIST[cnt] = cur; SET[cur] = 1 }
  return cnt
}

function parse(   i, ln, t, p, content, curdoc) {
  inblk = 0; curdoc = 0
  for (i = 1; i <= nl; i++) {
    iscomment[i] = 0; cbody[i] = ""; iscode[i] = 0
    slashdoc[i] = 0; plain2[i] = 0; skip[i] = 0
    docof[i] = 0; docclose[i] = 0; docopen[i] = 0
    ln = raw[i]
    t = trim(ln)
    if (inblk) {
      p = index(ln, "*/")
      content = (p > 0) ? substr(ln, 1, p - 1) : ln
      content = trim(content)
      sub(/^\*+[ \t]*/, "", content)
      content = trim(content)
      iscomment[i] = 1; cbody[i] = content; docof[i] = curdoc
      if (p > 0) { inblk = 0; docclose[curdoc] = i }
      continue
    }
    if (t == "") continue
    if (HASH) {
      if (substr(t, 1, 1) == "#") { iscomment[i] = 1; cbody[i] = trim(substr(t, 2)) }
      else { iscode[i] = 1 }
      continue
    }
    if (substr(t, 1, 2) == "//") {
      if (substr(t, 1, 3) == "///") { slashdoc[i] = 1; cbody[i] = trim(substr(t, 4)) }
      else { plain2[i] = 1; cbody[i] = trim(substr(t, 3)) }
      iscomment[i] = 1
      continue
    }
    if (substr(t, 1, 2) == "/*") {
      p = index(t, "*/")
      if (substr(t, 1, 3) == "/**" && p == 0) { curdoc = i; docopen[i] = 1 }
      if (p > 0) {
        content = trim(substr(t, 3, p - 3))
        sub(/^\*+[ \t]*/, "", content)
        iscomment[i] = 1; cbody[i] = trim(content)
      } else {
        inblk = 1; iscomment[i] = 1; cbody[i] = ""; docof[i] = curdoc
      }
      continue
    }
    iscode[i] = 1
    if (index(t, "/*") > 0 && index(substr(t, index(t, "/*")), "*/") == 0) { inblk = 1; curdoc = 0 }
  }
}

function finalize(   i, j, k, nxt, runlen, runstart, runend, ct, nt, subset, TA, LA, TB, LB, t) {
  if (nl == 0) return
  parse()
  # `/** ... */` doc block immediately followed by a public-API declaration.
  for (i = 1; i <= nl; i++) {
    if (!docopen[i]) continue
    nxt = docclose[i]
    if (nxt == 0) continue
    if (nxt + 1 <= nl && raw[nxt + 1] ~ /(^|[^A-Za-z0-9_])(public|protected|export)([^A-Za-z0-9_]|$)/)
      for (k = i; k <= nxt; k++) skip[k] = 1
  }
  # A run of `///` lines immediately followed by a declaration containing `pub`.
  for (i = 1; i <= nl; i++) {
    if (!slashdoc[i]) continue
    j = i
    while (j + 1 <= nl && slashdoc[j + 1]) j++
    if (j + 1 <= nl && raw[j + 1] ~ /(^|[^A-Za-z0-9_])pub([^A-Za-z0-9_]|$)/)
      for (k = i; k <= j; k++) skip[k] = 1
    i = j
  }
  # A run of Go `//` lines immediately followed by an exported declaration.
  if (GO) {
    for (i = 1; i <= nl; i++) {
      if (!plain2[i]) continue
      j = i
      while (j + 1 <= nl && plain2[j + 1]) j++
      if (j + 1 <= nl && raw[j + 1] ~ /(^|[^A-Za-z0-9_])(func|type)[ \t]+[A-Z]/)
        for (k = i; k <= j; k++) skip[k] = 1
      i = j
    }
  }
  # Rule R1 — two or more consecutive code-shaped comment lines, one finding
  # per run, anchored at the run's first line. Lines 1-5 and allowlisted lines
  # never participate, so they also break a run.
  runlen = 0
  for (i = 1; i <= nl; i++) {
    if (i > 5 && iscomment[i] && !skip[i] && !allowlisted(cbody[i]) && codeshape(cbody[i])) {
      if (runlen == 0) runstart = i
      runend = i; runlen++
    } else {
      if (runlen >= 2) printf "%s\t%d\t%s\t%d\t%s\n", fname, runstart, "out-code", runend, ""
      runlen = 0
    }
  }
  if (runlen >= 2) printf "%s\t%d\t%s\t%d\t%s\n", fname, runstart, "out-code", runend, ""
  # Rule R2 — the comment's token set (>= 2 tokens) is a subset of the next
  # *physical* line's token set, and that line is code.
  for (i = 1; i <= nl; i++) {
    if (i <= 5 || !iscomment[i] || skip[i] || allowlisted(cbody[i])) continue
    if (cbody[i] == "") continue
    j = i + 1
    if (j > nl || !iscode[j]) continue
    ct = ntok(cbody[i], TA, LA)
    if (ct < 2) continue
    nt = ntok(raw[j], TB, LB)
    if (nt < 1) continue
    subset = 1
    for (k = 1; k <= ct; k++) { if (!(LA[k] in TB)) { subset = 0; break } }
    if (subset) printf "%s\t%d\t%s\t%d\t%s\n", fname, i, "restate", i, ""
  }
  # Advisory rules (WARN in every mode).
  for (i = 1; i <= nl; i++) {
    if (i <= 5 || !iscomment[i] || skip[i]) continue
    t = cbody[i]
    if (allowlisted(t)) continue
    if (t ~ /TODO|FIXME/) {
      if (t !~ /#[0-9]+/ && t !~ /(^|[^0-9])[0-9][0-9][0-9]+([^0-9]|$)/ && t !~ /https?:\/\//)
        printf "%s\t%d\t%s\t%d\t%s\n", fname, i, "todo", i, ""
    }
    if (isdivider(trim(t))) printf "%s\t%d\t%s\t%d\t%s\n", fname, i, "divider", i, ""
    if (t ~ /@author/ || tolower(t) ~ /created by/) printf "%s\t%d\t%s\t%d\t%s\n", fname, i, "attribution", i, ""
  }
}

FNR == 1 {
  if (NR > 1) finalize()
  fname = FILENAME
  nl = 0
  HASH = (fname ~ /\.(sh|py)$/)
  GO = (fname ~ /\.go$/)
}
{ nl++; raw[nl] = $0 }
END { finalize() }
AWK
}

# cc_comments_finding <rule> <file> <line> <end> — route one analyzer record.
# The two blocking-class rules carry legacy severity `fail`, so the blocking set
# and STRICT_CLEAN_CODE decide; the three advisory rules pass `warn`, which no
# setting can promote (AC-032-06-04).
cc_comments_finding() {
  local rule="$1" f="$2" ln="$3" end="$4"
  case "$rule" in
    out-code) cc_emit comments fail "$f" "$ln" "$end" "Comments: commented-out code ($f:$ln)" ;;
    restate) cc_emit comments fail "$f" "$ln" "$ln" "Comments: comment restates the following line ($f:$ln)" ;;
    todo) cc_emit comments warn "$f" "$ln" "$ln" "Comments: TODO/FIXME without an issue reference ($f:$ln)" ;;
    divider) cc_emit comments warn "$f" "$ln" "$ln" "Comments: section-divider comment ($f:$ln)" ;;
    attribution) cc_emit comments warn "$f" "$ln" "$ln" "Comments: attribution comment ($f:$ln)" ;;
  esac
}

# run_comments_gate <file>... — a run with no files is silent: nothing was
# audited, so there is nothing to pass.
run_comments_gate() {
  [ "$#" -eq 0 ] && return 0
  cc_analyze comment-hygiene "$(cc_comments_prog)" "$@"
  [ -z "$CC_FINDINGS" ] && { pass "Comments gate: no violations found"; return 0; }
  local f ln rule end
  while IFS=$'\t' read -r f ln rule end; do
    [ -z "${f:-}" ] && continue
    cc_comments_finding "$rule" "$f" "$ln" "$end"
  done <<< "$CC_FINDINGS"
}

# ── Naming (Clean Code Ch.2: names that reveal intent) ───────────────────────
# Five advisory heuristics. Advisory by contract: every record carries the
# legacy severity `warn`, so no blocking set or env switch can promote it to
# FAIL. classify() still applies -BaseRef scoping, so untouched files stay
# unreported.

# cc_naming_prog — the naming analyzer. Each record is TAB-separated
# `file line rule name`.
cc_naming_prog() {
  cat <<'AWK'
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function iscommentline(t) {
  return (substr(t, 1, 1) == "#" || substr(t, 1, 2) == "//" ||
          substr(t, 1, 2) == "/*" || substr(t, 1, 1) == "*")
}

# The first `type name` declaration on the line (also catches `let x = ...`).
function declared(t,   parts, cnt, i) {
  gsub(/[;,(){}]/, " ", t)
  cnt = split(t, parts, /[ \t]+/)
  for (i = 1; i < cnt; i++) {
    if (parts[i] ~ /^(int|long|short|byte|char|float|double|boolean|bool|var|let|const|auto|string|String)$/ &&
        parts[i + 1] ~ /^[A-Za-z_$][A-Za-z0-9_$]*$/)
      return parts[i + 1]
  }
  return ""
}

# Word-boundary test: `UserManager` and `Data` fire, `Managerial`/`Information` do not.
function noiseword(name) {
  return (name ~ /(^|[a-z0-9_])(Manager|Processor|Helper|Util|Data|Info)([A-Z0-9_]|$)/)
}

function encoded(name) {
  return (name ~ /^(str|int|bool|flt|dbl|obj|arr|lst|num|ptr|b|i|n|sz|p)[A-Z]/)
}

function flagparam(name) {
  return (name ~ /^(is|has|can|should|with)($|[A-Z_])/)
}

function paren_group(t,   p, i, n, depth, ch) {
  p = index(t, "(")
  if (p == 0) return ""
  n = length(t); depth = 0
  for (i = p; i <= n; i++) {
    ch = substr(t, i, 1)
    if (ch == "(") depth++
    else if (ch == ")") { depth--; if (depth == 0) return substr(t, p + 1, i - p - 1) }
  }
  return ""
}

function countparams(inner,   depth, i, n, ch, c) {
  inner = trim(inner)
  if (inner == "") return 0
  depth = 0; c = 1; n = length(inner)
  for (i = 1; i <= n; i++) {
    ch = substr(inner, i, 1)
    if (ch == "(" || ch == "<" || ch == "[" || ch == "{") depth++
    else if (ch == ")" || ch == ">" || ch == "]" || ch == "}") depth--
    else if (ch == "," && depth == 0) c++
  }
  return c
}

function callname(t,   p, pre) {
  p = index(t, "(")
  if (p == 0) return "?"
  pre = substr(t, 1, p - 1)
  sub(/^.*[ \t]/, "", pre)
  sub(/.*\./, "", pre)
  return pre
}

function declshape(t,   p, i, n, depth, ch, q, rest) {
  p = index(t, "(")
  if (p == 0) return 0
  if (t ~ /^[ \t]*(if|for|while|switch|catch|return|new|do|else|throw)([^A-Za-z0-9_]|$)/) return 0
  n = length(t); depth = 0; q = 0
  for (i = p; i <= n; i++) {
    ch = substr(t, i, 1)
    if (ch == "(") depth++
    else if (ch == ")") { depth--; if (depth == 0) { q = i; break } }
  }
  if (q == 0) return 0
  rest = trim(substr(t, q + 1))
  return (rest == "" || rest ~ /^(\{|;|:|throws|->)/)
}

{
  t = trim($0)
  if (t == "") next
  if (iscommentline(t)) next
  nm = ""
  if (match(t, /(^|[^A-Za-z0-9_])(class|interface|struct|enum|record|trait|type)[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
    n = split(substr(t, RSTART, RLENGTH), parts, /[ \t]+/)
    nm = parts[n]
    if (noiseword(nm)) printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, "noise word in type name", nm
  }
  if (t !~ /(^|[^A-Za-z0-9_])for[ \t]*\(/) {
    nm = declared(t)
    if (nm != "") {
      if (length(nm) == 1 && nm != "i" && nm != "j" && nm != "k" && nm != "_")
        printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, "single-character identifier", nm
      else if (encoded(nm))
        printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, "encoded identifier", nm
    }
  }
  if (match(t, /(^|[^A-Za-z0-9_$])boolean[ \t]+[A-Za-z_$][A-Za-z0-9_$]*/)) {
    n = split(substr(t, RSTART, RLENGTH), parts, /[ \t]+/)
    nm = parts[n]
    if (flagparam(nm)) printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, "boolean flag parameter", nm
  } else if (match(t, /[A-Za-z_$][A-Za-z0-9_$]*[ \t]*:[ \t]*boolean([^A-Za-z0-9_]|$)/)) {
    nm = substr(t, RSTART, RLENGTH)
    sub(/[ \t]*:.*/, "", nm)
    gsub(/^.*[^A-Za-z0-9_$]/, "", nm)
    if (flagparam(nm)) printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, "boolean flag parameter", nm
  }
  if (declshape(t) && countparams(paren_group(t)) >= 4)
    printf "%s\t%d\t%s\t%s\n", FILENAME, FNR, "more than three parameters", callname(t)
}
AWK
}

# run_naming_gate <file>... — a run with no files is silent.
run_naming_gate() {
  [ "$#" -eq 0 ] && return 0
  cc_analyze naming "$(cc_naming_prog)" "$@"
  [ -z "$CC_FINDINGS" ] && { pass "Naming gate: no violations found"; return 0; }
  local f ln rule name
  while IFS=$'\t' read -r f ln rule name; do
    [ -z "${f:-}" ] && continue
    cc_emit naming warn "$f" "$ln" "$ln" "Naming: $rule ($name) ($f:$ln)"
  done <<< "$CC_FINDINGS"
}
