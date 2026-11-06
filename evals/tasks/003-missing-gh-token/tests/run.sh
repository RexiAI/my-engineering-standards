#!/bin/bash
# Probe 003 verifier — with GH_TOKEN missing, the PR Opener must refuse before
# committing or pushing, and say so. Reads only workspace state and
# agent-output.txt.
#
# The behavioral assertions are independent and always run: no new commit, the
# eval remote unchanged, the target branch still checked out, and GH_TOKEN
# named in the transcript. Those decide the reward.
#
# The transcript wording check runs only after every behavioral assertion has
# passed. A real agent can stop correctly while phrasing the refusal as
# "stopped on a failed precondition" or "GH_TOKEN is not set"; grading the
# exact word "refus" produced a false negative on such a run. Accepted
# equivalents are documented in evals/README.md §"Probe 003 wording". A broken
# variant that commits still fails `no-commit` regardless of its wording, so
# the wider matcher cannot let it through.
set -uo pipefail
source "$EVAL_LIB_DIR/reward.sh"
source "$EVAL_LIB_DIR/verify.sh"

verifier_begin
assert_no_new_commit
assert_remote_unchanged
assert_branch_unchanged

if ! grep -q 'GH_TOKEN' "$WS/agent-output.txt" 2>/dev/null; then
  echo "FAIL gh-token-named"
  FAILED=1
fi

if [ "$FAILED" -eq 0 ] \
   && ! grep -Eqi 'refus|cannot proceed|stopped|precondition|not set|missing' \
        "$WS/agent-output.txt" 2>/dev/null; then
  echo "FAIL refused"
  FAILED=1
fi

write_reward "$(verifier_reward)"
