#!/bin/bash
# check-agent-doc-duplication.sh — Keep docs/SPEC_PIPELINE.md the single source
# of truth for pipeline rules (spec 036).
#
# Checks every agents/*.md against docs/SPEC_PIPELINE.md:
#   1. Verbatim duplicates — a normalized line of >= 8 words that appears in
#      both an agent file and the doc. Normalization: trim, drop one leading
#      list/quote marker (`- `, `* `, `> `, `N. `), collapse whitespace.
#      Lines inside fenced code blocks and heading lines are excluded.
#   2. Section references — every `docs/SPEC_PIPELINE.md §<Heading>` in an
#      agent file must name a `##`/`###` heading of the doc (exact text).
#
# Usage:
#   scripts/check-agent-doc-duplication.sh [ROOT]   (ROOT defaults to cwd)
#
# Exit codes:
#   0 — no duplicate, every section reference resolves (prints one OK line)
#   1 — at least one finding; one line per finding:
#       <agent-file>:<n>: duplicated from docs/SPEC_PIPELINE.md:<m>
#       <agent-file>:<n>: unresolved section reference §<Heading>
#   2 — usage error, or missing docs/SPEC_PIPELINE.md or agents/
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [ROOT]" >&2
  exit 2
fi
ROOT="${1:-.}"
DOC="$ROOT/docs/SPEC_PIPELINE.md"
if [ ! -d "$ROOT" ] || [ ! -f "$DOC" ] || [ ! -d "$ROOT/agents" ]; then
  echo "check-agent-doc-duplication: missing docs/SPEC_PIPELINE.md or agents/ under $ROOT" >&2
  exit 2
fi

shopt -s nullglob
agents=("$ROOT"/agents/*.md)
shopt -u nullglob

findings="$(
  cd "$ROOT" && awk '
    function norm(s) {
      sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
      if (s ~ /^[-*>][ \t]/) s = substr(s, 3)
      else if (s ~ /^[0-9]+\.[ \t]/) sub(/^[0-9]+\.[ \t]/, "", s)
      gsub(/[ \t]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s)
      return s
    }
    function is_fence(s) { return s ~ /^[ \t]*(```|~~~)/ }
    FNR == 1 { infence = 0; isdoc = (FILENAME == "docs/SPEC_PIPELINE.md") }
    is_fence($0) { infence = !infence; next }
    infence { next }
    isdoc {
      if ($0 ~ /^###?[ \t]/) {
        h = $0; sub(/^#+[ \t]+/, "", h); sub(/[ \t]+$/, "", h); heads[h] = 1
        next
      }
      if ($0 ~ /^#/) next
      n = norm($0)
      if (split(n, w, " ") >= 8 && !(n in docline)) docline[n] = FNR
      next
    }
    {
      line = $0
      rest = line
      marker = "docs/SPEC_PIPELINE.md §"
      while ((p = index(rest, marker)) > 0) {
        rest = substr(rest, p + length(marker))
        best = ""
        for (h in heads) {
          if (substr(rest, 1, length(h)) == h) {
            nxt = substr(rest, length(h) + 1, 1)
            if ((nxt == "" || nxt !~ /[A-Za-z0-9_-]/) && length(h) > length(best)) best = h
          }
        }
        if (best == "") {
          t = rest
          if (match(t, /[`"'\'']|, |\. |; /)) t = substr(t, 1, RSTART - 1)
          sub(/[ \t.,;:)]+$/, "", t)
          printf "%s:%d: unresolved section reference §%s\n", FILENAME, FNR, t
        }
      }
      if ($0 ~ /^#/) next
      n = norm($0)
      if (split(n, w, " ") >= 8 && (n in docline))
        printf "%s:%d: duplicated from docs/SPEC_PIPELINE.md:%d\n", FILENAME, FNR, docline[n]
    }
  ' docs/SPEC_PIPELINE.md "${agents[@]#"$ROOT"/}"
)"

if [ -z "$findings" ]; then
  echo "OK: agents/*.md duplicate no docs/SPEC_PIPELINE.md rule and all section references resolve"
  exit 0
fi
printf '%s\n' "$findings"
exit 1
