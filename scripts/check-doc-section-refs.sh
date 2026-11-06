#!/bin/bash
# check-doc-section-refs.sh — Require section-scoped references to
# docs/CODING_CONVENTIONS.md (spec 041).
#
# The conventions doc is ~26 KB. A prompt that says "follow
# docs/CODING_CONVENTIONS.md" makes the agent read the whole file on every
# invocation, including sections it will never need (formatting, CI job
# orchestration). Pointing at the named sections instead costs a fraction of
# that per stage — and this gate makes the scoping structural rather than a
# habit: a bare whole-file reference fails the check, and an anchor that no
# longer names exactly one `## ` heading fails it too.
#
# Scope: agents/spec-*.md and commands/*.md. Every line carrying
# `docs/CODING_CONVENTIONS.md` must also carry at least one `§<Heading>`
# anchor; each anchored heading must match exactly one `^## <Heading>$` line in
# the doc. Level-3 headings are not unique (`### Java` appears twice), so
# anchors resolve against `^## ` only.
#
# Usage:
#   scripts/check-doc-section-refs.sh [ROOT]
#   scripts/check-doc-section-refs.sh --cost [ROOT]
#   scripts/check-doc-section-refs.sh -h|--help
#
# ROOT defaults to the repo root (parent of scripts/). It is a tree containing
# agents/, commands/, and docs/CODING_CONVENTIONS.md, so every negative case in
# scripts/tests/ac-041-doc-section-refs.bats runs against a scratch tree instead
# of rewriting the real agents.
#
# --cost is a measurement mode, not a threshold: for each in-scope file that
# carries at least one reference it prints
#   cost <path> sections=<n> bytes=<b> file_bytes=<t> ratio=<r>
# where <b> is the sum of the referenced sections' byte ranges (heading line
# through the line before the next `^## ` heading, or EOF), <t> is the doc's
# `wc -c`, and <r> is <b>/<t> to two decimals. A section referenced twice by
# one file counts once. It exits 0 on success, 2 on a tooling failure, and never
# 1 — it reports cost, it does not fail a budget.
#
# Exit codes:
#   0 — every reference is section-scoped and every section resolves uniquely;
#       one `[OK] <path>` line per file in scope
#   1 — at least one violation; each prints `path:line: reason: detail`
#       (reasons: bare-reference, section-missing, section-ambiguous)
#   2 — tooling failure: missing agents/ directory, missing conventions doc,
#       unknown option / usage error. Never a silent pass.
#
# Standards reference:
#   docs/CODING_CONVENTIONS.md §Design Principles
#   docs/spec-pipeline/coder.md
# shellcheck disable=SC2329  # handlers reached through "$handler" are invoked, not dead
set -euo pipefail

DOC_REL="docs/CODING_CONVENTIONS.md"
VIOLATIONS=0
MODE=check
POSITIONAL=()
ROOT=""
DOC=""

usage() {
  cat <<'EOF'
usage: scripts/check-doc-section-refs.sh [--cost] [ROOT]

Require every docs/CODING_CONVENTIONS.md reference in agents/spec-*.md and
commands/*.md to name the sections it needs (docs/CODING_CONVENTIONS.md
§<Heading>), and require each named section to resolve to exactly one
`## <Heading>` in the doc.

  --cost   print referenced-section bytes per file instead of checking
  ROOT     tree containing agents/, commands/, docs/ (default: repo root)

Exit: 0 clean, 1 violations, 2 tooling failure.
EOF
}

# repo_root — the tree holding scripts/, agents/, and docs/.
repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  dirname "$script_dir"
}

# tooling_fail <message> — a check that cannot read its inputs is never a pass.
tooling_fail() {
  echo "ERROR: $*" >&2
  exit 2
}

# usage_error — a usage problem is exit 2, with the usage block on stderr.
usage_error() {
  usage >&2
  exit 2
}

# apply_flag <arg> — resolve one option; unknown options are usage errors.
apply_flag() {
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --cost) MODE=cost; return 0 ;;
  esac
  echo "unknown option: $1" >&2
  usage_error
}

# parse_args <arg…> — fill MODE (check|cost) and ROOT; POSITIONAL keeps the
# non-option arguments.
parse_args() {
  local arg
  for arg in "$@"; do
    if [ "${arg#-}" != "$arg" ]; then apply_flag "$arg"; else POSITIONAL+=("$arg"); fi
  done
  [ "${#POSITIONAL[@]}" -le 1 ] || usage_error
  ROOT="${POSITIONAL[0]:-$(repo_root)}"
}

# require_inputs — the tree must carry agents/ and the conventions doc.
require_inputs() {
  ROOT="$(cd "$ROOT" 2>/dev/null && pwd)" || tooling_fail "ROOT not found"
  [ -d "$ROOT/agents" ] || tooling_fail "agents/ directory not found under $ROOT"
  DOC="$ROOT/$DOC_REL"
  [ -f "$DOC" ] || tooling_fail "conventions doc not found: $DOC"
}

# violation <path> <line> <reason> <detail> — one machine-greppable line.
violation() {
  printf '%s:%s: %s: %s\n' "$1" "$2" "$3" "$4"
  VIOLATIONS=$((VIOLATIONS + 1))
}

# trim_anchor <raw> — `§Name` with a trailing backtick/period/comma removed.
trim_anchor() {
  printf '%s\n' "$1" | sed -E 's/^§//; s/[[:space:]]+$//; s/[`.,;:)]+$//'
}

# heading_count <heading> — how many `## <heading>` lines the doc has. 0, 1, or
# more; grep exits 1 on no match, so the count is read with `|| true`.
heading_count() {
  grep -cxF "## $1" "$DOC" || true
}

# reference_lines <file> — the file's reference lines as `line:text`.
reference_lines() {
  grep -nE 'docs/CODING_CONVENTIONS\.md' "$1" || true
}

# anchors_of <text> — every `§…` anchor on one line. Anchors end at a comma or
# at the closing backtick of the code span that carries them; the last one is
# otherwise trimmed of trailing prose punctuation by trim_anchor.
anchors_of() {
  printf '%s\n' "$1" | grep -o '§[^,`]*' || true
}

# trim_anchors — stdin is `§…` anchors, one per line; stdout is the same
# anchors with trailing prose punctuation removed, empty ones dropped. The
# anchor grammar's trimming lives here once: check_anchors and resolved_of_line
# both read anchors through it.
trim_anchors() {
  local raw heading
  while IFS= read -r raw; do
    heading="$(trim_anchor "$raw")"
    [ -n "$heading" ] || continue
    printf '%s\n' "$heading"
  done
}

# reason_for <heading-count> — the violation reason a non-unique count carries.
# A lookup, not a branch chain: the reason names the resolution outcome.
reason_for() {
  case "$1" in
    0) printf 'section-missing' ;;
    *) printf 'section-ambiguous' ;;
  esac
}

# check_anchors <path> <line> <text> — one violation per anchor that does not
# resolve uniquely. An anchor-free line is a bare whole-file reference.
check_anchors() {
  local rel="$1" num="$2" text="$3" anchors heading count
  anchors="$(anchors_of "$text")"
  if [ -z "$anchors" ]; then
    violation "$rel" "$num" "bare-reference" \
      "$DOC_REL needs at least one §<Heading> anchor"
    return 0
  fi
  while IFS= read -r heading; do
    [ -n "$heading" ] || continue
    count="$(heading_count "$heading")"
    [ "$count" = "1" ] && continue
    violation "$rel" "$num" "$(reason_for "$count")" "§$heading"
  done <<< "$(trim_anchors <<< "$anchors")"
}

# each_reference <rel> <handler> — call <handler> <rel> <line> <text> for every
# reference line in one in-scope file.
each_reference() {
  local rel="$1" handler="$2" ref
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    "$handler" "$rel" "${ref%%:*}" "${ref#*:}"
  done <<< "$(reference_lines "$ROOT/$rel")"
}

# check_file <rel> — validate every reference line in one in-scope file.
check_file() {
  local rel="$1" before="$VIOLATIONS"
  each_reference "$rel" check_anchors
  if [ "$VIOLATIONS" -eq "$before" ]; then
    echo "[OK] $rel"
  fi
}

# in_scope_files — the files the check applies to, relative to ROOT.
in_scope_files() {
  local f
  shopt -s nullglob
  for f in "$ROOT"/agents/spec-*.md "$ROOT"/commands/*.md; do
    printf '%s\n' "${f#"$ROOT"/}"
  done
  shopt -u nullglob
}

# each_in_scope <handler> — call <handler> <rel> for every in-scope file.
each_in_scope() {
  local handler="$1" rel
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    "$handler" "$rel"
  done <<< "$(in_scope_files)"
}

# resolved_of_line <rel> <line> <text> — the headings on one reference line
# that resolve uniquely, one per line. Signature matches each_reference's
# handler contract.
resolved_of_line() {
  local heading
  while IFS= read -r heading; do
    [ -n "$heading" ] || continue
    [ "$(heading_count "$heading")" = "1" ] || continue
    printf '%s\n' "$heading"
  done <<< "$(anchors_of "$3" | trim_anchors)"
}

# resolved_headings <rel> — the headings one file references that resolve
# uniquely, one per line (duplicates kept; callers sort -u).
resolved_headings() {
  each_reference "$1" resolved_of_line
}

# section_bytes <heading> — the section's byte span: its `## ` line through the
# line before the next `## ` heading, or to EOF for the last section.
section_bytes() {
  local heading="$1" size
  size="$(wc -c < "$DOC" | tr -d ' ')"
  LC_ALL=C awk -v want="## $heading" -v size="$size" '
    /^## / {
      if (name == want) { print off - start; done = 1 }
      name = $0; start = off
    }
    { off += length($0) + 1 }
    END { if (!done && name == want) print size - start }
  ' "$DOC"
}

# cost_file <rel> — one `cost …` line when the file carries ≥1 resolvable
# reference, nothing otherwise.
cost_file() {
  local rel="$1" headings heading bytes=0 n=0 b size ratio
  headings="$(resolved_headings "$rel" | sort -u)"
  [ -n "$headings" ] || return 0
  while IFS= read -r heading; do
    [ -n "$heading" ] || continue
    b="$(section_bytes "$heading")"
    [ -n "$b" ] || continue
    bytes=$((bytes + b))
    n=$((n + 1))
  done <<< "$headings"
  [ "$n" -gt 0 ] || return 0
  size="$(wc -c < "$DOC" | tr -d ' ')"
  ratio="$(awk -v b="$bytes" -v t="$size" 'BEGIN { printf "%.2f", b / t }')"
  printf 'cost %s sections=%s bytes=%s file_bytes=%s ratio=%s\n' \
    "$rel" "$n" "$bytes" "$size" "$ratio"
}

main() {
  parse_args "$@"
  require_inputs
  if [ "$MODE" = cost ]; then
    each_in_scope cost_file
    exit 0
  fi
  each_in_scope check_file
  [ "$VIOLATIONS" -eq 0 ] || exit 1
  exit 0
}

main "$@"
