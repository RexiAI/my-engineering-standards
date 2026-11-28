#!/bin/bash
# pr-review-verdict.sh — Turn the PR review agent's marker comment into a
# required-check verdict, failing closed on anything it cannot read.
#
# Reads the JSON of `gh pr view <n> --json comments`, selects the LATEST
# comment whose body carries a line `Reviewed-SHA: <head-sha>` (exact SHA,
# comment order in the JSON), and requires exactly one case-sensitive
# `Review-Verdict: pass|findings` line in it.
#
# Result mapping:
#   pass       -> verdict=pass,       exit 0
#   findings   -> verdict=findings,   exit 1
#   no comment -> verdict=missing,    exit 1
#   zero/many/unknown verdict lines -> verdict=malformed, exit 1
#
# The script prints exactly one `verdict=<value>` line, never touches the
# network, and never treats an absent, empty, or malformed input as a pass.
#
# Usage:
#   scripts/pr-review-verdict.sh --head-sha <sha> --comments-file <path|->
#
# Exit codes: 0 pass, 1 non-pass, 2 usage or input error.
#
# Standards reference:
#   specs/045-pr-size-gate-and-auto-merge/20-acceptance/AC-045-05-*.md
#   agents/pr-review.md §Inputs and output contract (headless CI)
set -euo pipefail

HEAD_SHA=""
COMMENTS_FILE=""

die() { printf 'pr-review-verdict: %s\n' "$*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --head-sha) HEAD_SHA="${2:-}"; shift 2 ;;
    --comments-file) COMMENTS_FILE="${2:-}"; shift 2 ;;
    --help)
      printf 'usage: scripts/pr-review-verdict.sh --head-sha <sha> --comments-file <path|->\n'
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$HEAD_SHA" ] || die "--head-sha is required"
[ -n "$COMMENTS_FILE" ] || die "--comments-file is required"
if [ "$COMMENTS_FILE" = "-" ]; then
  COMMENTS_JSON="$(cat)"
else
  [ -r "$COMMENTS_FILE" ] || die "cannot read comments file: $COMMENTS_FILE"
  COMMENTS_JSON="$(cat "$COMMENTS_FILE")"
fi

# The comment bodies arrive JSON-escaped: one physical line per comment with
# literal \n inside the body. Split bodies onto their own lines so marker lines
# can be matched line-by-line, then let awk keep the latest marked comment.
printf '%s\n' "$COMMENTS_JSON" \
  | sed 's/\\n/\n/g' \
  | sed 's/"body":"/\n"body":"/g' \
  | awk -v sha="$HEAD_SHA" '
      function check(line) {
        # A body first line shares its physical line with the `"body":"`
        # key; a body last line shares its line with the JSON punctuation
        # that follows the closing quote. Remove both, then trim whitespace.
        sub(/^.*"body":"/, "", line)
        sub(/".*$/, "", line)
        sub(/[[:space:]]+$/, "", line)
        if (line == "Reviewed-SHA: " sha) { marked = 1; return }
        if (line ~ /^Review-Verdict: /) {
          count++
          val = line
          sub(/^Review-Verdict: /, "", val)
        }
      }
      function finish() {
        if (marked) { have_last = 1; last_count = count; last_val = val }
      }
      BEGIN { inbody = 0; marked = 0; count = 0; val = ""; have_last = 0; last_count = 0; last_val = "" }
      {
        if (index($0, "\"body\":\"")) {
          if (inbody) finish()
          inbody = 1; marked = 0; count = 0; val = ""
          check($0)
          next
        }
        if (inbody) check($0)
      }
      END {
        if (inbody) finish()
        if (!have_last) { print "verdict=missing"; exit 1 }
        if (last_count != 1) { print "verdict=malformed"; exit 1 }
        if (last_val == "pass") { print "verdict=pass"; exit 0 }
        if (last_val == "findings") { print "verdict=findings"; exit 1 }
        print "verdict=malformed"; exit 1
      }
    '
