#!/bin/bash
# check-pr-babysitter.sh — Verify the PR Babysitter loop deliverables are present
# and carry the required rules (spec 018).
#
# The PR Babysitter loop (spec 018) ships: a triage skill
# (skills/pr-review-triage/SKILL.md), its durable-state section in the root
# STATE.md, and a self-ci step. There is no application code and no test suite
# in the usual sense — this script is the spec's test carrier: every
# AC-018-NN-NN scenario ID from specs/018-pr-babysitter-loop/20-acceptance/ is
# cited below as a check, so scripts/check-scenario-traceability.sh traces this
# spec, and the greps double as the acceptance tests.
#
# Checks (one block per acceptance scenario):
#   AC-018-01-01  skill exists, frontmatter name, read/comment-only allowed-tools
#   AC-018-01-02  review norms (conventional-commit title, approval, threads, squash)
#   AC-018-01-03  required-check policy source of truth
#   AC-018-01-04  ready-to-merge definition
#   AC-018-01-05  check-state taxonomy (absent-unknown is never green)
#   AC-018-02-01  watcher enumerates open PRs once per run
#   AC-018-02-02  per-PR triage state recorded in STATE.md
#   AC-018-02-03  zero checks / policy unknown -> not ready
#   AC-018-02-04  any non-passing required check blocks readiness
#   AC-018-02-05  spec-pipeline draft PRs recorded, not fought
#   AC-018-03-01  separate minimal-fix sub-agent in an isolated worktree
#   AC-018-03-02  separate verifier confirms; implementer never self-approves
#   AC-018-03-03  loop proposes, never merges, no auto-merge
#   AC-018-03-04  CI gating is read-only input
#   AC-018-04-01  ready verdict -> label or human ping
#   AC-018-04-02  no label on any non-ready verdict
#   AC-018-04-03  ambiguous/high-risk escalates with context
#   AC-018-05-01  circuit breaker: max 3 fix attempts, then escalate + stop
#   AC-018-05-02  repeated failures escalate, never repeat a comment
#   AC-018-05-03  human gates for high-risk changes and >10 files
#   AC-018-05-04  idle >3 days -> single close/hand-off suggestion
#   AC-018-06-01  STATE.md keeps a ## PR Babysitter section
#   AC-018-06-02  merged/closed PRs pruned each run, prune logged
#   AC-018-06-03  every loop comment is signed
#   AC-018-06-04  each run appends a run-log entry, including no-op runs
#   AC-018-07-01  early exit on an empty watchlist
#   AC-018-07-02  cost table + budget from loop-budget.md
#   AC-018-08-01  this script exists, executable, exits 0/1
#   AC-018-08-02  every scenario ID cited, references resolve
#   AC-018-08-03  wired into self-ci, no new workflow file
#
# Usage:
#   scripts/check-pr-babysitter.sh [ROOT_DIR]
#   ROOT_DIR defaults to the current directory.
#
# Exit codes:
#   0 — every check passes
#   1 — one or more artifacts/rules missing; a FAIL line is printed per violation
#
# Standards reference:
#   docs/LOOP_ENGINEERING.md (spec 016)
#   docs/GIT_WORKFLOW.md §PR Requirements
#   templates/gate.yaml, templates/loop-budget.md, templates/loop-run-log.md (016)
#   specs/018-pr-babysitter-loop/20-acceptance/ (AC-018-01-01 … AC-018-08-03)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
ROOT_DIR="${1:-.}"

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

SKILL_FILE="$ROOT_DIR/skills/pr-review-triage/SKILL.md"
STATE_FILE="$ROOT_DIR/STATE.md"
SELF_CI_FILE="$ROOT_DIR/.github/workflows/self-ci.yml"

# require_file <ac-id> <file> <description>
require_file() {
  if [ -f "$2" ]; then
    pass "$1: $3"
  else
    fail "$1: $3 (missing $2)"
  fi
}

# require_grep <ac-id> <file> <fixed-pattern> <description>
require_grep() {
  if [ -f "$2" ] && grep -qF -- "$3" "$2"; then
    pass "$1: $4"
  else
    fail "$1: $4 (expected \"$3\" in $2)"
  fi
}

echo "Checking PR Babysitter loop deliverables in: $ROOT_DIR"
echo ""

# ── Task 1: pr-review-triage skill (AC-018-01) ───────────────────────────────
# AC-018-01-01 — The triage skill file exists with valid frontmatter
require_file "AC-018-01-01" "$SKILL_FILE" "skills/pr-review-triage/SKILL.md exists"
require_grep "AC-018-01-01" "$SKILL_FILE" "name: pr-review-triage" \
  "frontmatter declares name: pr-review-triage"
if [ -f "$SKILL_FILE" ]; then
  TOOLS_LINE=$(grep '^allowed-tools:' "$SKILL_FILE" | head -1 || true)
  if echo "$TOOLS_LINE" | grep -q 'Bash(gh pr ' \
     && ! echo "$TOOLS_LINE" | grep -qE 'merge|push'; then
    pass "AC-018-01-01: allowed-tools restrict the loop to read/comment-only operations"
  else
    fail "AC-018-01-01: allowed-tools missing or not read/comment-only (no merge, no push)"
  fi
fi

echo ""

# AC-018-01-02 — The skill defines the repo's review norms
require_grep "AC-018-01-02" "$SKILL_FILE" "conventional-commit" \
  "review norms: PR titles follow conventional-commit format"
require_grep "AC-018-01-02" "$SKILL_FILE" "self-approve" \
  "review norms: production+ requires one reviewer approval, mvp may self-approve"
require_grep "AC-018-01-02" "$SKILL_FILE" "unresolved discussion" \
  "review norms: no unresolved discussion threads"
require_grep "AC-018-01-02" "$SKILL_FILE" "squash-only" \
  "review norms: merge is squash-only"

echo ""

# AC-018-01-03 — The skill defines the required-check policy source of truth
require_grep "AC-018-01-03" "$SKILL_FILE" "required_status_checks.contexts" \
  "policy source: branch protection required_status_checks.contexts on the default branch"
require_grep "AC-018-01-03" "$SKILL_FILE" ".github/workflows/" \
  "policy source: .github/workflows/*.yml is the cross-check for what CI runs"
require_grep "AC-018-01-03" "$SKILL_FILE" "both reads succeed" \
  "policy is known only when both reads succeed, otherwise unknown"

echo ""

# AC-018-01-04 — The skill defines "ready to merge"
require_grep "AC-018-01-04" "$SKILL_FILE" "every required check is passing" \
  "ready to merge: required-check policy known and all required checks passing"
require_grep "AC-018-01-04" "$SKILL_FILE" "tier-required approval" \
  "ready to merge: at least the tier-required approval present"
require_grep "AC-018-01-04" "$SKILL_FILE" "no merge conflict" \
  "ready to merge: no merge conflict"
require_grep "AC-018-01-04" "$SKILL_FILE" "is not a draft" \
  "ready to merge: PR is not a draft"

echo ""

# AC-018-01-05 — The skill defines the check-state taxonomy
require_grep "AC-018-01-05" "$SKILL_FILE" "passing, failing, pending, or absent-unknown" \
  "check-state taxonomy: every check is passing/failing/pending/absent-unknown"
require_grep "AC-018-01-05" "$SKILL_FILE" "never treated as green" \
  "zero returned checks is absent-unknown and never treated as green"

echo ""

# ── Task 2: watcher and check-state triage (AC-018-02) ───────────────────────
# AC-018-02-01 — The loop discovers open PRs with the real mechanism
require_grep "AC-018-02-01" "$SKILL_FILE" "gh pr list --state open" \
  "watcher lists open PRs via gh pr list --state open"
require_grep "AC-018-02-01" "$SKILL_FILE" "github_list_pull_requests" \
  "watcher may list open PRs via MCP github_list_pull_requests"
require_grep "AC-018-02-01" "$SKILL_FILE" "exactly once per run" \
  "each open PR is recorded in the watchlist exactly once per run"

echo ""

# AC-018-02-02 — The loop records full triage state per PR
require_grep "AC-018-02-02" "$SKILL_FILE" "check status per check" \
  "STATE.md records check status per check"
require_grep "AC-018-02-02" "$SKILL_FILE" "required-check policy is known" \
  "STATE.md records whether the required-check policy is known"
require_grep "AC-018-02-02" "$SKILL_FILE" "approvals" \
  "STATE.md records review state (approvals)"
require_grep "AC-018-02-02" "$SKILL_FILE" "mergeability" \
  "STATE.md records mergeability"
require_grep "AC-018-02-02" "$SKILL_FILE" "ready-to-merge verdict" \
  "STATE.md records the ready-to-merge verdict"

echo ""

# AC-018-02-03 — Zero returned checks is absent/unknown, never green
require_grep "AC-018-02-03" "$SKILL_FILE" "is not ready to merge" \
  "absent-unknown / policy unknown PRs are not ready to merge"

echo ""

# AC-018-02-04 — Any non-passing required check blocks readiness
require_grep "AC-018-02-04" "$SKILL_FILE" "blocks readiness" \
  "any pending/failing/absent-unknown required check blocks readiness"

echo ""

# AC-018-02-05 — Spec-pipeline draft PRs are not fought
require_grep "AC-018-02-05" "$SKILL_FILE" "spec/NNN-slug" \
  "spec-pipeline draft PRs (spec/NNN-slug) are identified"
require_grep "AC-018-02-05" "$SKILL_FILE" "records state only" \
  "spec-pipeline drafts: records state only, no fixes/labels/comments on pipeline failures"
require_grep "AC-018-02-05" "$SKILL_FILE" "may ping the human" \
  "spec-pipeline drafts: may ping the human once green and undrafted"

echo ""

# ── Task 3: failing-check remediation (AC-018-03) ─────────────────────────────
# AC-018-03-01 — A failing check spawns a separate minimal-fix sub-agent
require_grep "AC-018-03-01" "$SKILL_FILE" "minimal-fix sub-agent" \
  "a failing check spawns a separate minimal-fix sub-agent"
require_grep "AC-018-03-01" "$SKILL_FILE" "isolated worktree" \
  "the fix is produced in an isolated worktree"
require_grep "AC-018-03-01" "$SKILL_FILE" "never editing the PR branch in place" \
  "the PR branch is never edited in place"

echo ""

# AC-018-03-02 — A separate verifier confirms the fix
require_grep "AC-018-03-02" "$SKILL_FILE" "separate verifier sub-agent" \
  "a separate verifier sub-agent independently confirms the fix"
require_grep "AC-018-03-02" "$SKILL_FILE" "no unrelated files" \
  "the verifier confirms no unrelated files were touched"
require_grep "AC-018-03-02" "$SKILL_FILE" "tests and lint still pass" \
  "the verifier confirms tests and lint still pass in the worktree"
require_grep "AC-018-03-02" "$SKILL_FILE" "never marks its own work done" \
  "the implementer never marks its own work done"

echo ""

# AC-018-03-03 — The loop proposes, never merges
require_grep "AC-018-03-03" "$SKILL_FILE" "never merges" \
  "the loop proposes the fix and never merges"
require_grep "AC-018-03-03" "$SKILL_FILE" "no auto-merge" \
  "no auto-merge path exists"

echo ""

# AC-018-03-04 — The babysitter never changes CI gating
require_grep "AC-018-03-04" "$SKILL_FILE" "read-only inputs" \
  ".github/workflows/*.yml, branch protection, and the required-check policy are read-only inputs"

echo ""

# ── Task 4: ready-to-merge action (AC-018-04) ─────────────────────────────────
# AC-018-04-01 — Ready verdict adds the label or pings the human
require_grep "AC-018-04-01" "$SKILL_FILE" "--add-label \"ready to merge\"" \
  "ready verdict adds the \"ready to merge\" label via gh pr edit --add-label"
require_grep "AC-018-04-01" "$SKILL_FILE" "label creation fails" \
  "if label creation fails the loop pings the human instead"

echo ""

# AC-018-04-02 — No label on any non-ready verdict
require_grep "AC-018-04-02" "$SKILL_FILE" "suppress the action" \
  "unknown policy / non-passing check / missing approval / unresolved threads / conflict / draft suppress the label"

echo ""

# AC-018-04-03 — Ambiguous or high-risk items escalate with context
require_grep "AC-018-04-03" "$SKILL_FILE" "escalates to the human" \
  "ambiguous or high-risk items escalate to the human"
require_grep "AC-018-04-03" "$SKILL_FILE" "PR link" \
  "escalation carries the PR link and what is uncertain"

echo ""

# ── Task 5: bounded remediation and human gates (AC-018-05) ───────────────────
# AC-018-05-01 — Circuit breaker caps fix attempts per PR
require_grep "AC-018-05-01" "$SKILL_FILE" "max 3 fix attempts" \
  "circuit breaker: max 3 fix attempts per PR"
require_grep "AC-018-05-01" "$SKILL_FILE" "same head SHA" \
  "no progress = no new commits or the same check failing at the same head SHA"
require_grep "AC-018-05-01" "$SKILL_FILE" "stops commenting" \
  "on exhaustion the loop escalates and stops commenting on that PR"

echo ""

# AC-018-05-02 — Repeated failures escalate instead of repeating comments
require_grep "AC-018-05-02" "$SKILL_FILE" "escalates instead of repeating" \
  "a repeated failure escalates instead of repeating the same comment"

echo ""

# AC-018-05-03 — Human gate for high-risk changes
require_grep "AC-018-05-03" "$SKILL_FILE" "more than 10 files" \
  "a PR touching more than 10 files is human-gated"
require_grep "AC-018-05-03" "$SKILL_FILE" "gate.yaml" \
  "the 016 gate.yaml path denylist is human-gated"
require_grep "AC-018-05-03" "$SKILL_FILE" "without a human decision" \
  "no fix proposal is made without a human decision"

echo ""

# AC-018-05-04 — Idle PRs get a single close/hand-off suggestion
require_grep "AC-018-05-04" "$SKILL_FILE" "more than 3 days" \
  "a PR idle more than 3 days gets a close/hand-off suggestion"
require_grep "AC-018-05-04" "$SKILL_FILE" "recorded in state" \
  "the suggestion is recorded in state"
require_grep "AC-018-05-04" "$SKILL_FILE" "is not re-pinged" \
  "the PR is not re-pinged on later runs"

echo ""

# ── Task 6: state, pruning, and identity (AC-018-06) ──────────────────────────
# AC-018-06-01 — STATE.md keeps a PR Babysitter section
require_grep "AC-018-06-01" "$STATE_FILE" "## PR Babysitter" \
  "STATE.md contains a ## PR Babysitter section"
require_grep "AC-018-06-01" "$STATE_FILE" "Human override" \
  "the section records human overrides that changed loop behavior"

echo ""

# AC-018-06-02 — Merged/closed PRs are pruned every run
require_grep "AC-018-06-02" "$SKILL_FILE" "recorded in the run-log" \
  "merged/closed PRs are pruned each run and the prune is recorded in the run-log"

echo ""

# AC-018-06-03 — Every loop comment is signed
require_grep "AC-018-06-03" "$SKILL_FILE" "Loop Engineering — PR Babysitter" \
  "every loop comment is signed 'Loop Engineering — PR Babysitter'"

echo ""

# AC-018-06-04 — Each run appends a run-log entry
require_grep "AC-018-06-04" "$SKILL_FILE" "\"pr-babysitter\"" \
  "run-log entries carry pattern \"pr-babysitter\""
require_grep "AC-018-06-04" "$SKILL_FILE" "tokens_estimate" \
  "run-log entries use the 016 format (tokens_estimate present)"
require_grep "AC-018-06-04" "$SKILL_FILE" "no-op runs" \
  "run-log entries are appended including no-op runs"

echo ""

# ── Task 7: cost guidance (AC-018-07) ─────────────────────────────────────────
# AC-018-07-01 — Empty watchlist exits early
require_grep "AC-018-07-01" "$SKILL_FILE" "exits immediately" \
  "an empty watchlist exits immediately after the no-op run-log entry"
require_grep "AC-018-07-01" "$SKILL_FILE" "no sub-agent spawns" \
  "an empty watchlist spawns no sub-agents and posts no comments"

echo ""

# AC-018-07-02 — Cost table and budget consumption are documented
require_grep "AC-018-07-02" "$SKILL_FILE" "3k tokens" \
  "cost table documents the no-op run cost"
require_grep "AC-018-07-02" "$SKILL_FILE" "80k tokens" \
  "cost table documents the triage run cost"
require_grep "AC-018-07-02" "$SKILL_FILE" "250k tokens" \
  "cost table documents the fix-attempt cost"
require_grep "AC-018-07-02" "$SKILL_FILE" "loop-budget.md" \
  "budget is spent from loop-budget.md (016)"
require_grep "AC-018-07-02" "$SKILL_FILE" "on-exceed" \
  "on-exceed and kill behavior are defined in loop-budget.md, not here"

echo ""

# ── Task 8: traceability shell gate (AC-018-08) ───────────────────────────────
# AC-018-08-01 — The check script exists and gates on completeness
if [ -x "$ROOT_DIR/scripts/check-pr-babysitter.sh" ]; then
  pass "AC-018-08-01: scripts/check-pr-babysitter.sh exists and is executable"
else
  fail "AC-018-08-01: scripts/check-pr-babysitter.sh is missing or not executable"
fi

echo ""

# AC-018-08-02 — Every scenario ID is cited by the script, references resolve
SCENARIO_IDS=(
  AC-018-01-01 AC-018-01-02 AC-018-01-03 AC-018-01-04 AC-018-01-05
  AC-018-02-01 AC-018-02-02 AC-018-02-03 AC-018-02-04 AC-018-02-05
  AC-018-03-01 AC-018-03-02 AC-018-03-03 AC-018-03-04
  AC-018-04-01 AC-018-04-02 AC-018-04-03
  AC-018-05-01 AC-018-05-02 AC-018-05-03 AC-018-05-04
  AC-018-06-01 AC-018-06-02 AC-018-06-03 AC-018-06-04
  AC-018-07-01 AC-018-07-02
  AC-018-08-01 AC-018-08-02 AC-018-08-03
)
MISSING_CITES=0
for id in "${SCENARIO_IDS[@]}"; do
  if ! grep -qF -- "$id" "$0"; then
    fail "AC-018-08-02: scenario $id is not cited by check-pr-babysitter.sh"
    MISSING_CITES=$((MISSING_CITES + 1))
  fi
done
if [ "$MISSING_CITES" -eq 0 ]; then
  pass "AC-018-08-02: every AC-018-NN-NN scenario ID is cited by this script"
fi

STALE_REFS=0
for ref in $(grep -oE 'AC-018-[0-9]{2}-[0-9]{2}' "$0" | sort -u); do
  case " ${SCENARIO_IDS[*]} " in
    *" $ref "*) ;;
    *)
      fail "AC-018-08-02: stale reference $ref in check-pr-babysitter.sh resolves to no scenario"
      STALE_REFS=$((STALE_REFS + 1))
      ;;
  esac
done
if [ "$STALE_REFS" -eq 0 ]; then
  pass "AC-018-08-02: every AC-018 reference inside the script resolves to a scenario ID"
fi

echo ""

# AC-018-08-03 — The script is wired into self-ci (no new workflow file)
require_grep "AC-018-08-03" "$SELF_CI_FILE" "check-pr-babysitter.sh" \
  ".github/workflows/self-ci.yml runs check-pr-babysitter.sh in the Validate job (no new workflow file)"

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ PR Babysitter check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/LOOP_ENGINEERING.md, docs/GIT_WORKFLOW.md §PR Requirements"
  exit 1
else
  echo -e "${GREEN}✔ PR Babysitter check: every check passed.${NC}"
fi
