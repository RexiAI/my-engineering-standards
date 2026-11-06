#!/usr/bin/env bash
# pr-review-gh.sh — the only executable the PR review agent may run.
#
# Spec 024/026 + ADR 0023: the reviewer is comment-only. Its permission block
# cannot express "gh pr view but not gh pr merge" reliably: opencode's bash
# permission matcher treats the allowlist differently across versions, and in
# headless CI any unmatched command falls through to `ask`, which is
# auto-rejected — so the reviewer posted nothing. This wrapper makes the
# boundary explicit and version-independent: one executable, four fixed
# read-only/comment subcommands, no free-form argument passthrough.
#
# Usage:
#   scripts/pr-review-gh.sh view <pr-number>
#   scripts/pr-review-gh.sh diff <pr-number>
#   scripts/pr-review-gh.sh checks <pr-number>
#   scripts/pr-review-gh.sh comment <pr-number>   # body on stdin
#
# Exit codes: 0 success, 2 usage error, otherwise the gh exit code.
set -euo pipefail

usage() {
  echo "usage: $0 {view|diff|checks|comment} <pr-number>" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage
subcommand="$1"
pr="$2"

case "$pr" in
  ''|*[!0-9]*) echo "$0: <pr-number> must be numeric" >&2; exit 2 ;;
esac

case "$subcommand" in
  view)
    exec gh pr view "$pr" --json title,body,files,headRefOid,baseRefName,author
    ;;
  diff)
    exec gh pr diff "$pr"
    ;;
  checks)
    exec gh pr checks "$pr"
    ;;
  comment)
    exec gh pr comment "$pr" --body-file -
    ;;
  *)
    usage
    ;;
esac
