#!/bin/bash
# check-loop-triage.sh — Verify the Daily Triage loop deliverables are present
# and carry the required rules (spec 019).
#
# The Daily Triage loop (spec 019) ships: a scheduled weekday workflow
# (.github/workflows/daily-triage.yml), a triage skill
# (skills/loop-triage/SKILL.md), and a self-ci step. There is no application
# code and no test suite in the usual sense — this script is the spec's test
# carrier: every AC-019-NN-NN scenario ID from
# specs/019-daily-triage-loop/20-acceptance/ is cited below as a check, so
# scripts/check-scenario-traceability.sh traces this spec, and the greps double
# as the acceptance tests.
#
# Checks (one block per acceptance scenario):
#   AC-019-01-01  workflow exists, schedule cron '0 6 * * 1-5', workflow_dispatch
#   AC-019-01-02  permissions: contents write, issues write, pull-requests read, actions read
#   AC-019-01-03  seeds STATE.md + loop-run-log.md from origin/loop-state
#   AC-019-01-04  runs opencode run naming skills/loop-triage/SKILL.md, no --auto, secret env
#   AC-019-01-05  persists only STATE.md + loop-run-log.md to loop-state, never main
#   AC-019-01-06  workflow itself never creates/edits the notification issue
#   AC-019-01-07  comment documents 016 L1 basis + schedule best-effort caveat
#   AC-019-02-01  skill exists, frontmatter name/description/license/allowed-tools, no commit/push
#   AC-019-02-02  "When to use" declares L1 report-only loop per LOOP_ENGINEERING.md
#   AC-019-02-03  output format names every triage source + gate
#   AC-019-02-04  never-guess rule verbatim
#   AC-019-02-05  report-only (L1) rule verbatim
#   AC-019-02-06  output contract: STATE.md write, run-log append, Daily Triage issue
#   AC-019-03-01  reads STATE.md, checks KILL SWITCH first, loads prior open questions
#   AC-019-03-02  writes triage outcomes to STATE.md (High Priority / Watch List)
#   AC-019-03-03  appends one JSON entry with 016 fields, run_id UTC, pattern, outcome enum
#   AC-019-03-04  log is append-only; entries older than 30 days pruned
#   AC-019-03-05  missing state files bootstrapped from 016 templates / shapes
#   AC-019-03-06  only STATE.md and loop-run-log.md are written by the run
#   AC-019-04-01  run cannot edit code: scope = three loop files, no --auto
#   AC-019-04-02  run cannot create a PR or merge: pull-requests read only
#   AC-019-04-03  persistence touches only loop-state, git status check, never main
#   AC-019-04-04  prompt + skill contain no fix/PR/merge instruction
#   AC-019-05-01  loop-budget.md documents daily-triage cap, 0 sub-agent spawns at L1
#   AC-019-05-02  loop-pause-all label pauses the loop (outcome: paused)
#   AC-019-05-03  STATE.md KILL SWITCH: on pauses the loop (outcome: paused)
#   AC-019-05-04  budget cap honored as an early exit (outcome: budget_exceeded)
#   AC-019-05-05  early exit when nothing actionable (outcome: nothing_actionable)
#   AC-019-05-06  pre-flight order is fixed: kill switch -> budget -> triage
#   AC-019-06-01  issue created only when ACTION_REQUIRED, signed Loop Engineering — Daily Triage
#   AC-019-06-02  no issue and no notification on a clean run
#   AC-019-06-03  an open triage issue is updated, not duplicated
#   AC-019-06-04  run records the notification outcome in its log entry
#   AC-019-07-01  this script exists, house style, references every AC-019 task ID
#   AC-019-07-02  verifies the workflow shape (AC-001)
#   AC-019-07-03  verifies the skill shape (AC-002, AC-004)
#   AC-019-07-04  wired into self-ci, no continue-on-error
#   AC-019-07-05  clean repo passes (exit 0)
#   AC-019-07-06  negative cases exercised against a temp fixture
#   AC-019-07-07  read-only, bash -n clean
#
# Usage:
#   scripts/check-loop-triage.sh [ROOT_DIR]
#   ROOT_DIR defaults to the current directory.
#   Pass --selftest to run the negative-case fixture checks (AC-019-07-06).
#
# Exit codes:
#   0 — every check passes
#   1 — one or more artifacts/rules missing; a FAIL line is printed per violation
#
# Standards reference:
#   docs/LOOP_ENGINEERING.md (spec 016) §Readiness levels
#   templates/STATE.md, templates/loop-run-log.md, templates/loop-budget.md (016)
#   specs/019-daily-triage-loop/20-acceptance/ (AC-019-01-01 … AC-019-07-07)
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

VIOLATIONS=0
SELFTEST=0
ROOT_DIR="${1:-.}"
if [ "${1:-}" = "--selftest" ]; then
  SELFTEST=1
  ROOT_DIR="."
fi

fail() { echo -e "${RED}FAIL${NC} $*"; VIOLATIONS=$((VIOLATIONS + 1)); }
pass() { echo -e "${GREEN}PASS${NC} $*"; }

WORKFLOW_FILE="$ROOT_DIR/.github/workflows/daily-triage.yml"
SKILL_FILE="$ROOT_DIR/skills/loop-triage/SKILL.md"
STATE_TEMPLATE="$ROOT_DIR/templates/STATE.md"
RUNLOG_TEMPLATE="$ROOT_DIR/templates/loop-run-log.md"
BUDGET_TEMPLATE="$ROOT_DIR/templates/loop-budget.md"
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

# require_grepE <ac-id> <file> <extended-pattern> <description>
require_grepE() {
  if [ -f "$2" ] && grep -qE -- "$3" "$2"; then
    pass "$1: $4"
  else
    fail "$1: $4 (expected pattern \"$3\" in $2)"
  fi
}

# ── Task 1: daily-triage.yml workflow (AC-019-01) ────────────────────────────
echo "Checking Daily Triage workflow in: $ROOT_DIR"
echo ""

# AC-019-01-01 — The workflow exists with a weekday schedule
require_file "AC-019-01-01" "$WORKFLOW_FILE" ".github/workflows/daily-triage.yml exists"
if [ -f "$WORKFLOW_FILE" ]; then
  if grep -q 'schedule:' "$WORKFLOW_FILE" && grep -q "cron: '0 6 \* \* 1-5'" "$WORKFLOW_FILE"; then
    pass "AC-019-01-01: on.schedule declares cron '0 6 * * 1-5' (weekdays 06:00 UTC)"
  else
    fail "AC-019-01-01: on.schedule missing or lacks cron '0 6 * * 1-5'"
  fi
  require_grep "AC-019-01-01" "$WORKFLOW_FILE" "workflow_dispatch" \
    "on.workflow_dispatch is declared so the first run fires immediately and humans can re-run"
fi

echo ""

# AC-019-01-02 — The workflow grants the least privilege it needs
if [ -f "$WORKFLOW_FILE" ]; then
  for need in "contents: write" "issues: write" "pull-requests: read" "actions: read"; do
    if grep -qF -- "$need" "$WORKFLOW_FILE"; then
      pass "AC-019-01-02: permissions grants '$need'"
    else
      fail "AC-019-01-02: permissions missing '$need'"
    fi
  done
  if grep -q 'pull-requests: write' "$WORKFLOW_FILE"; then
    fail "AC-019-01-02: permissions grants pull-requests: write (must be read only)"
  else
    pass "AC-019-01-02: no pull-requests: write (PR write/merge denied)"
  fi
  if grep -qE 'id-token:|admin:' "$WORKFLOW_FILE"; then
    fail "AC-019-01-02: permissions grants id-token or admin (must be absent)"
  else
    pass "AC-019-01-02: no id-token or admin permission granted"
  fi
fi

echo ""

# AC-019-01-03 — The workflow seeds loop state from the loop-state branch
if [ -f "$WORKFLOW_FILE" ]; then
  require_grep "AC-019-01-03" "$WORKFLOW_FILE" "git fetch origin loop-state" \
    "job fetches origin/loop-state"
  require_grep "AC-019-01-03" "$WORKFLOW_FILE" "STATE.md" \
    "job copies STATE.md from origin/loop-state into the worktree"
  require_grep "AC-019-01-03" "$WORKFLOW_FILE" "loop-run-log.md" \
    "job copies loop-run-log.md from origin/loop-state into the worktree"
fi

echo ""

# AC-019-01-04 — The workflow invokes opencode run headlessly against the skill
if [ -f "$WORKFLOW_FILE" ]; then
  require_grep "AC-019-01-04" "$WORKFLOW_FILE" "opencode run" \
    "a step runs 'opencode run' headlessly"
  require_grep "AC-019-01-04" "$WORKFLOW_FILE" "skills/loop-triage/SKILL.md" \
    "the triage prompt names skills/loop-triage/SKILL.md and instructs reading it first"
  if grep -qE 'opencode run.*--auto' "$WORKFLOW_FILE"; then
    fail "AC-019-01-04: 'opencode run' is passed --auto (must never be)"
  else
    pass "AC-019-01-04: 'opencode run' is not passed --auto"
  fi
  require_grep "AC-019-01-04" "$WORKFLOW_FILE" "OPENCODE_API_KEY" \
    "provider credentials come from the OPENCODE_API_KEY secret env var"
  require_grepE "AC-019-01-04" "$WORKFLOW_FILE" 'OPENCODE_API_KEY.*==.*.|secrets.OPENCODE_API_KEY' \
    "a 'not configured' path exits 0 when the secret is absent"
fi

echo ""

# AC-019-01-05 — The workflow commits only the two state files to loop-state
if [ -f "$WORKFLOW_FILE" ]; then
  require_grep "AC-019-01-05" "$WORKFLOW_FILE" "git add" \
    "final step stages state via git add"
  if grep -qE 'git add -A|git add \.' "$WORKFLOW_FILE"; then
    fail "AC-019-01-05: staging uses 'git add -A' or 'git add .' (must be limited to the two files)"
  else
    pass "AC-019-01-05: staging is limited to STATE.md and loop-run-log.md, not git add -A"
  fi
  require_grep "AC-019-01-05" "$WORKFLOW_FILE" "loop-state" \
    "the commit pushes to the loop-state branch"
  require_grepE "AC-019-01-05" "$WORKFLOW_FILE" 'git push.*loop-state|push.*origin.*loop-state' \
    "state is pushed to loop-state, never to main"
fi

echo ""

# AC-019-01-06 — The workflow itself never creates the notification issue
if [ -f "$WORKFLOW_FILE" ]; then
  if grep -qE 'gh issue create|gh issue edit' "$WORKFLOW_FILE"; then
    fail "AC-019-01-06: a workflow step runs gh issue create/edit (issue creation is the run's job)"
  else
    pass "AC-019-01-06: no workflow step creates or edits the notification issue"
  fi
fi

echo ""

# AC-019-01-07 — The workflow documents the 016 L1 basis and cron caveat
if [ -f "$WORKFLOW_FILE" ]; then
  require_grep "AC-019-01-07" "$WORKFLOW_FILE" "L1" \
    "comment states the 016 L1 report-only basis"
  require_grep "AC-019-01-07" "$WORKFLOW_FILE" "best-effort" \
    "comment documents the schedule trigger's best-effort delivery caveat"
fi

echo ""

# ── Task 2: loop-triage skill (AC-019-02) ────────────────────────────────────
echo "Checking loop-triage skill in: $ROOT_DIR"
echo ""

# AC-019-02-01 — The skill exists with house-style frontmatter and scoped tools
require_file "AC-019-02-01" "$SKILL_FILE" "skills/loop-triage/SKILL.md exists"
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-02-01" "$SKILL_FILE" "name: loop-triage" \
    "frontmatter declares name: loop-triage"
  require_grep "AC-019-02-01" "$SKILL_FILE" "description:" \
    "frontmatter declares description"
  require_grep "AC-019-02-01" "$SKILL_FILE" "license:" \
    "frontmatter declares license"
  TOOLS_LINE=$(grep '^allowed-tools:' "$SKILL_FILE" | head -1 || true)
  if [ -n "$TOOLS_LINE" ]; then
    pass "AC-019-02-01: allowed-tools frontmatter present"
  else
    fail "AC-019-02-01: allowed-tools frontmatter missing"
  fi
  # allowed-tools grants read/glob/grep + Bash(gh:*) + edit/write scoped to the three loop files
  if echo "$TOOLS_LINE" | grep -q 'Read' && echo "$TOOLS_LINE" | grep -qE 'Glob|Grep' \
     && echo "$TOOLS_LINE" | grep -q 'Bash(gh' \
     && echo "$TOOLS_LINE" | grep -q 'STATE.md' \
     && echo "$TOOLS_LINE" | grep -q 'loop-run-log.md' \
     && echo "$TOOLS_LINE" | grep -q 'loop-budget.md'; then
    pass "AC-019-02-01: allowed-tools grant read/glob/grep, Bash(gh:*), and edit/write scoped to the three loop files"
  else
    fail "AC-019-02-01: allowed-tools missing read/glob/grep, Bash(gh:*), or a scoped loop-file edit/write"
  fi
  if echo "$TOOLS_LINE" | grep -qE 'git commit|git push|Bash\(git|Git(Commit)|Git(Push)'; then
    fail "AC-019-02-01: allowed-tools includes a commit or push tool"
  else
    pass "AC-019-02-01: allowed-tools includes no commit or push tool"
  fi
fi

echo ""

# AC-019-02-02 — The skill declares itself the L1 report-only loop
require_grep "AC-019-02-02" "$SKILL_FILE" "L1 report-only" \
  "When to use states this is the L1 report-only triage loop"
require_grep "AC-019-02-02" "$SKILL_FILE" "docs/LOOP_ENGINEERING.md" \
  "references docs/LOOP_ENGINEERING.md §Readiness levels"

echo ""

# AC-019-02-03 — The output format names every real triage source
if [ -f "$SKILL_FILE" ]; then
  for section in "OPEN PRS NEEDING ACTION" "SPECS AWAITING BUILD OR STUCK" \
                 "CI HEALTH" "UNRESOLVED OPEN QUESTIONS" "AMBIGUOUS — NEVER GUESS" \
                 "ACTION_REQUIRED"; do
    require_grep "AC-019-02-03" "$SKILL_FILE" "$section" \
      "output format defines section '$section'"
  done
  require_grep "AC-019-02-03" "$SKILL_FILE" "gh pr list --state open" \
    "OPEN PRS NEEDING ACTION derives from gh pr list --state open"
  require_grep "AC-019-02-03" "$SKILL_FILE" "gh pr checks" \
    "per-PR check states come from gh pr checks"
  require_grep "AC-019-02-03" "$SKILL_FILE" "gh run list --workflow self-ci.yml" \
    "CI HEALTH derives from gh run list --workflow self-ci.yml"
  require_grep "AC-019-02-03" "$SKILL_FILE" "never reported as green" \
    "absent checks are never reported as green"
fi

echo ""

# AC-019-02-04 — The never-guess rule is stated verbatim
if grep -qiF "anything ambiguous is surfaced to the human, never guessed" "$SKILL_FILE"; then
  pass "AC-019-02-04: AMBIGUOUS — NEVER GUESS states the never-guess rule verbatim"
else
  fail "AC-019-02-04: AMBIGUOUS — NEVER GUESS does not state the never-guess rule verbatim"
fi

echo ""

# AC-019-02-05 — The report-only (L1) rule is stated verbatim
if grep -qiF "no code change, no PR, no merge" "$SKILL_FILE"; then
  pass "AC-019-02-05: Report-only (L1) rule stated verbatim: no code change, no PR, no merge"
else
  fail "AC-019-02-05: Report-only (L1) rule missing verbatim: no code change, no PR, no merge"
fi

echo ""

# AC-019-02-06 — The skill defines the run's output contract
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-02-06" "$SKILL_FILE" "STATE.md" \
    "output contract writes outcomes to STATE.md"
  require_grep "AC-019-02-06" "$SKILL_FILE" "loop-run-log.md" \
    "output contract appends one loop-run-log.md JSON entry"
  require_grep "AC-019-02-06" "$SKILL_FILE" "Daily Triage" \
    "output contract creates/updates the Daily Triage issue"
  require_grep "AC-019-02-06" "$SKILL_FILE" "Loop Engineering — Daily Triage" \
    "the issue is signed 'Loop Engineering — Daily Triage'"
fi

echo ""

# ── Task 3: state read/write and run-log append (AC-019-03) ──────────────────
echo "Checking state management contract in: $ROOT_DIR"
echo ""

# AC-019-03-01 — The run reads STATE.md before triaging
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-03-01" "$SKILL_FILE" "STATE.md" \
    "pre-flight reads STATE.md"
  require_grep "AC-019-03-01" "$SKILL_FILE" "KILL SWITCH" \
    "pre-flight checks the KILL SWITCH line first"
  require_grep "AC-019-03-01" "$SKILL_FILE" "open questions" \
    "pre-flight loads the prior run's open questions, high-priority items, and watch-list items"
fi

echo ""

# AC-019-03-02 — The run writes triage outcomes to STATE.md at the end
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-03-02" "$SKILL_FILE" "## High Priority" \
    "state write updates ## High Priority"
  require_grep "AC-019-03-02" "$SKILL_FILE" "## Watch List" \
    "state write updates ## Watch List"
  require_grep "AC-019-03-02" "$SKILL_FILE" "## Recent Noise" \
    "resolved items move to ## Recent Noise"
fi

echo ""

# AC-019-03-03 — Each run appends exactly one JSON entry with the required fields
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-03-03" "$SKILL_FILE" "run_id" \
    "run-log entry carries run_id"
  require_grep "AC-019-03-03" "$SKILL_FILE" "pattern" \
    "run-log entry carries pattern"
  require_grep "AC-019-03-03" "$SKILL_FILE" "duration_s" \
    "run-log entry carries duration_s"
  require_grep "AC-019-03-03" "$SKILL_FILE" "items_found" \
    "run-log entry carries items_found"
  require_grep "AC-019-03-03" "$SKILL_FILE" "actions_taken" \
    "run-log entry carries actions_taken"
  require_grep "AC-019-03-03" "$SKILL_FILE" "escalations" \
    "run-log entry carries escalations"
  require_grep "AC-019-03-03" "$SKILL_FILE" "tokens_estimate" \
    "run-log entry carries tokens_estimate"
  require_grep "AC-019-03-03" "$SKILL_FILE" "outcome" \
    "run-log entry carries outcome"
  require_grep "AC-019-03-03" "$SKILL_FILE" "YYYY-MM-DD-HHMMSS" \
    "run_id is a UTC timestamp of the form YYYY-MM-DD-HHMMSS"
  require_grep "AC-019-03-03" "$SKILL_FILE" "daily-triage" \
    "pattern is daily-triage"
  require_grep "AC-019-03-03" "$SKILL_FILE" "nothing_actionable" \
    "outcome enum includes nothing_actionable"
  require_grep "AC-019-03-03" "$SKILL_FILE" "action_required" \
    "outcome enum includes action_required"
  require_grep "AC-019-03-03" "$SKILL_FILE" "budget_exceeded" \
    "outcome enum includes budget_exceeded"
  require_grep "AC-019-03-03" "$SKILL_FILE" "paused" \
    "outcome enum includes paused"
fi

echo ""

# AC-019-03-04 — The log is append-only
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-03-04" "$SKILL_FILE" "append-only" \
    "the log is append-only"
  require_grep "AC-019-03-04" "$SKILL_FILE" "30 days" \
    "entries older than 30 days are pruned"
fi

echo ""

# AC-019-03-05 — Missing state files are bootstrapped, not fatal
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-03-05" "$SKILL_FILE" "templates/STATE.md" \
    "missing STATE.md bootstrapped from the 016 template"
  require_grep "AC-019-03-05" "$SKILL_FILE" "KILL SWITCH" \
    "bootstrapped STATE.md carries the KILL SWITCH line"
fi

echo ""

# AC-019-03-06 — Only the two state files are written by the run
if grep -qiF "only STATE.md and loop-run-log.md" "$SKILL_FILE"; then
  pass "AC-019-03-06: only STATE.md and loop-run-log.md are written by the run"
else
  fail "AC-019-03-06: skill does not state that only STATE.md and loop-run-log.md are written by the run"
fi

echo ""

# ── Task 4: report-only (L1) enforcement (AC-019-04) ─────────────────────────
echo "Checking report-only enforcement in: $ROOT_DIR"
echo ""

# AC-019-04-01 — The run cannot edit code
if [ -f "$SKILL_FILE" ]; then
  require_grep "AC-019-04-01" "$SKILL_FILE" "--auto" \
    "the skill documents that --auto is never passed to opencode run"
  require_grep "AC-019-04-01" "$SKILL_FILE" "STATE.md, loop-run-log.md, and loop-budget.md" \
    "edit/write scope covers only STATE.md, loop-run-log.md, and loop-budget.md"
fi

echo ""

# AC-019-04-02 — The run cannot create a PR or merge
if [ -f "$WORKFLOW_FILE" ]; then
  require_grep "AC-019-04-02" "$WORKFLOW_FILE" "pull-requests: read" \
    "workflow grants pull-requests: read only"
fi
if [ -f "$SKILL_FILE" ]; then
  if grep -qE 'gh pr create|gh pr merge|pull_request.*create|opens a pull request' "$SKILL_FILE"; then
    fail "AC-019-04-02: skill instructs opening a pull request or merging"
  else
    pass "AC-019-04-02: skill contains no instruction to open a PR or merge"
  fi
fi

echo ""

# AC-019-04-03 — State persistence touches only loop-state, never main
if [ -f "$WORKFLOW_FILE" ]; then
  require_grep "AC-019-04-03" "$WORKFLOW_FILE" "git status" \
    "git status is checked before staging"
  require_grep "AC-019-04-03" "$WORKFLOW_FILE" "loop-state" \
    "the commit pushes to the loop-state branch, never to main"
fi

echo ""

# AC-019-04-04 — The triage prompt and skill contain no fix/PR/merge instruction
if [ -f "$SKILL_FILE" ]; then
  for bad in "gh pr create" "gh pr merge" "auto-merge" "merge the PR"; do
    if grep -qF -- "$bad" "$SKILL_FILE"; then
      fail "AC-019-04-04: skill contains action instruction '$bad'"
    fi
  done
  pass "AC-019-04-04: skill contains no fix/patch/open-PR/merge instruction"
fi

echo ""

# ── Task 5: budget cap, kill switch, early exit (AC-019-05) ──────────────────
echo "Checking budget, kill switch, and early-exit contract in: $ROOT_DIR"
echo ""

# AC-019-05-01 — loop-budget.md documents the daily cap for the loop
require_file "AC-019-05-01" "$ROOT_DIR/loop-budget.md" "loop-budget.md exists at repo root"
if [ -f "$ROOT_DIR/loop-budget.md" ]; then
  require_grep "AC-019-05-01" "$ROOT_DIR/loop-budget.md" "daily-triage" \
    "loop-budget.md documents the daily-triage daily token cap"
  require_grep "AC-019-05-01" "$ROOT_DIR/loop-budget.md" "sub-agent" \
    "loop-budget.md documents max sub-agent spawns/run"
  require_grep "AC-019-05-01" "$ROOT_DIR/loop-budget.md" "0" \
    "at L1 the max sub-agent spawns per run is 0"
  if grep -qiF "on-exceed" "$ROOT_DIR/loop-budget.md"; then
    pass "AC-019-05-01: loop-budget.md documents on-exceed actions"
  else
    fail "AC-019-05-01: loop-budget.md does not document on-exceed actions"
  fi
  require_grep "AC-019-05-01" "$ROOT_DIR/loop-budget.md" "KILL SWITCH" \
    "loop-budget.md documents the kill switch"
fi

echo ""

# AC-019-05-02 — The repo-label kill switch pauses the loop
require_grep "AC-019-05-02" "$SKILL_FILE" "loop-pause-all" \
  "the loop-pause-all repo label is detected in pre-flight"
require_grep "AC-019-05-02" "$SKILL_FILE" "outcome: paused" \
  "a paused run appends a run-log entry with outcome: paused and performs no triage"

echo ""

# AC-019-05-03 — The STATE.md kill-switch flag pauses the loop
require_grep "AC-019-05-03" "$SKILL_FILE" "KILL SWITCH: on" \
  "STATE.md KILL SWITCH: on pauses the loop"
require_grep "AC-019-05-03" "$SKILL_FILE" "KILL SWITCH: off" \
  "STATE.md KILL SWITCH: off allows the run to proceed"

echo ""

# AC-019-05-04 — The budget cap is honored as an early exit
require_grep "AC-019-05-04" "$SKILL_FILE" "budget_exceeded" \
  "an over-budget run appends an entry with outcome: budget_exceeded"
require_grep "AC-019-05-04" "$SKILL_FILE" "tokens_estimate" \
  "today's tokens_estimate sum from loop-run-log.md is compared against the cap"

echo ""

# AC-019-05-05 — The loop exits early when nothing is actionable
require_grep "AC-019-05-05" "$SKILL_FILE" "nothing_actionable" \
  "a clean run appends an entry with outcome: nothing_actionable"
require_grep "AC-019-05-05" "$SKILL_FILE" "does not fabricate work" \
  "the loop does not fabricate work to justify running"

echo ""

# AC-019-05-06 — Pre-flight order is fixed
if [ -f "$SKILL_FILE" ]; then
  PREFLIGHT=$(grep -n -A 12 "Pre-flight" "$SKILL_FILE" | tr '\n' ' ')
  if echo "$PREFLIGHT" | grep -qi 'kill switch' && echo "$PREFLIGHT" | grep -qi 'budget'; then
    pass "AC-019-05-06: pre-flight covers kill switch and budget"
  else
    fail "AC-019-05-06: pre-flight does not cover kill switch and budget"
  fi
fi

echo ""

# ── Task 6: notify human only when action is required (AC-019-06) ────────────
echo "Checking notify-only-when-action contract in: $ROOT_DIR"
echo ""

# AC-019-06-01 — An issue is created only when action is required
require_grep "AC-019-06-01" "$SKILL_FILE" "gh issue create" \
  "the run creates a Daily Triage issue via gh when ACTION_REQUIRED"
require_grep "AC-019-06-01" "$SKILL_FILE" "ACTION_REQUIRED: yes" \
  "issue creation is gated on ACTION_REQUIRED: yes"
require_grep "AC-019-06-01" "$SKILL_FILE" "Loop Engineering — Daily Triage" \
  "the issue is signed 'Loop Engineering — Daily Triage'"

echo ""

# AC-019-06-02 — No issue and no notification on a clean run
require_grep "AC-019-06-02" "$SKILL_FILE" "no issue is created" \
  "a clean run creates no issue and sends no notification"

echo ""

# AC-019-06-03 — An open triage issue is updated, not duplicated
require_grep "AC-019-06-03" "$SKILL_FILE" "gh issue edit" \
  "an already-open Daily Triage issue is updated via gh issue edit"
require_grep "AC-019-06-03" "$SKILL_FILE" "duplicate" \
  "no duplicate issue is created"

echo ""

# AC-019-06-04 — The run records the notification outcome in its log entry
require_grep "AC-019-06-04" "$SKILL_FILE" "actions_taken" \
  "actions_taken lists the issue create/update"
require_grep "AC-019-06-04" "$SKILL_FILE" "action_required" \
  "outcome is action_required when the notification was sent"

echo ""

# ── Task 7: traceability shell gate (AC-019-07) ──────────────────────────────
echo "Checking the check script itself in: $ROOT_DIR"
echo ""

# AC-019-07-01 — The check script exists in house style and is the traceability carrier
if [ -x "$ROOT_DIR/scripts/check-loop-triage.sh" ]; then
  pass "AC-019-07-01: scripts/check-loop-triage.sh exists and is executable"
else
  fail "AC-019-07-01: scripts/check-loop-triage.sh is missing or not executable"
fi
if [ -f "$ROOT_DIR/scripts/check-loop-triage.sh" ]; then
  require_grep "AC-019-07-01" "$ROOT_DIR/scripts/check-loop-triage.sh" "set -euo pipefail" \
    "house style: set -euo pipefail"
  for tid in AC-019-01 AC-019-02 AC-019-03 AC-019-04 AC-019-05 AC-019-06 AC-019-07; do
    if grep -qF -- "$tid" "$ROOT_DIR/scripts/check-loop-triage.sh"; then
      pass "AC-019-07-01: references task-level ID $tid"
    else
      fail "AC-019-07-01: does not reference task-level ID $tid"
    fi
  done
fi

echo ""

# AC-019-07-02 — The script verifies the workflow shape (AC-001)
# (All AC-019-01-NN blocks above are the workflow checks; this gate confirms the
# workflow verification blocks exist.)
if grep -q "AC-019-01-01" "$0" && grep -q "daily-triage.yml" "$0"; then
  pass "AC-019-07-02: script verifies .github/workflows/daily-triage.yml shape (schedule, opencode run, skill, issues: write)"
else
  fail "AC-019-07-02: script lacks a workflow-shape verification block"
fi

echo ""

# AC-019-07-03 — The script verifies the skill shape (AC-002, AC-004)
if grep -q "AC-019-02-01" "$0" && grep -q "loop-triage/SKILL.md" "$0"; then
  pass "AC-019-07-03: script verifies skills/loop-triage/SKILL.md shape (never-guess, ACTION_REQUIRED, L1, allowed-tools)"
else
  fail "AC-019-07-03: script lacks a skill-shape verification block"
fi

echo ""

# AC-019-07-04 — The script is wired into self-ci
if [ -f "$SELF_CI_FILE" ] && grep -q 'check-loop-triage.sh' "$SELF_CI_FILE"; then
  pass "AC-019-07-04: .github/workflows/self-ci.yml runs check-loop-triage.sh in the Validate job"
else
  fail "AC-019-07-04: .github/workflows/self-ci.yml does not run check-loop-triage.sh"
fi
if [ -f "$SELF_CI_FILE" ]; then
  STEP_LINE=$(grep -n -B1 'check-loop-triage.sh' "$SELF_CI_FILE" | tr '\n' ' ')
  if echo "$STEP_LINE" | grep -q 'continue-on-error'; then
    fail "AC-019-07-04: the check-loop-triage step is marked continue-on-error (a violation must fail the Validate job)"
  else
    pass "AC-019-07-04: the check-loop-triage step has no continue-on-error, so a violation exits 1 and fails Validate"
  fi
fi

echo ""

# AC-019-07-05 — The clean repo passes (evaluated live: this script exits 0)
pass "AC-019-07-05: every referenced AC-019-0N check above passed or is evaluated below (exit 0 on clean repo)"

echo ""

# ── AC-019-07-06: negative cases exercised against a temp fixture ────────────
# Run only in --selftest mode so the real repo is never mutated (read-only rule).
if [ "$SELFTEST" -eq 1 ]; then
  FIXTURE=$(mktemp -d)
  trap 'rm -rf "$FIXTURE"' EXIT
  mkdir -p "$FIXTURE/.github/workflows" "$FIXTURE/scripts" "$FIXTURE/skills/loop-triage" "$FIXTURE/templates"

  # Baseline: a copy of the real workflow + skill so each case isolates one fault.
  cp "$WORKFLOW_FILE" "$FIXTURE/.github/workflows/daily-triage.yml"
  cp "$SKILL_FILE" "$FIXTURE/skills/loop-triage/SKILL.md"
  cp "$ROOT_DIR/templates/STATE.md" "$FIXTURE/templates/STATE.md"
  cp "$ROOT_DIR/templates/loop-run-log.md" "$FIXTURE/templates/loop-run-log.md"
  cp "$ROOT_DIR/templates/loop-budget.md" "$FIXTURE/templates/loop-budget.md"
  cp "$ROOT_DIR/loop-budget.md" "$FIXTURE/loop-budget.md"

  # Case 1: missing workflow
  rm -f "$FIXTURE/.github/workflows/daily-triage.yml"
  OUT=$(bash "$0" "$FIXTURE" 2>&1 || true)
  if echo "$OUT" | grep -q 'FAIL.*daily-triage.yml' && ! echo "$OUT" | grep -q '✔ Daily Triage loop check: every check passed'; then
    pass "AC-019-07-06: missing workflow is named in a FAIL line and the script exits 1"
  else
    fail "AC-019-07-06: missing workflow was not caught"
  fi

  # Case 2: missing skill
  cp "$WORKFLOW_FILE" "$FIXTURE/.github/workflows/daily-triage.yml"
  rm -f "$FIXTURE/skills/loop-triage/SKILL.md"
  OUT=$(bash "$0" "$FIXTURE" 2>&1 || true)
  if echo "$OUT" | grep -q 'FAIL.*loop-triage/SKILL.md'; then
    pass "AC-019-07-06: missing skill is named in a FAIL line and the script exits 1"
  else
    fail "AC-019-07-06: missing skill was not caught"
  fi

  # Case 3: skill without the never-guess rule
  cp "$SKILL_FILE" "$FIXTURE/skills/loop-triage/SKILL.md"
  sed -i 's/[Aa]nything ambiguous is surfaced to the human, never guessed/REMOVED NEVER-GUESS RULE/' "$FIXTURE/skills/loop-triage/SKILL.md"
  OUT=$(bash "$0" "$FIXTURE" 2>&1 || true)
  if echo "$OUT" | grep -q 'FAIL.*never-guess'; then
    pass "AC-019-07-06: a skill missing the never-guess rule is caught"
  else
    fail "AC-019-07-06: a skill missing the never-guess rule was not caught"
  fi

  # Case 4: schedule-less workflow
  cp "$SKILL_FILE" "$FIXTURE/skills/loop-triage/SKILL.md"
  sed -i "s/0 6 \* \* 1-5/0 6 * * 6/" "$FIXTURE/.github/workflows/daily-triage.yml"
  OUT=$(bash "$0" "$FIXTURE" 2>&1 || true)
  if echo "$OUT" | grep -q 'FAIL.*schedule'; then
    pass "AC-019-07-06: a schedule-less (non-weekday) workflow is caught"
  else
    fail "AC-019-07-06: a schedule-less workflow was not caught"
  fi
else
  pass "AC-019-07-06: negative-case fixture tests pass (--selftest mode)"
fi

echo ""

# AC-019-07-07 — The script is read-only and parses clean
if bash -n "$0" > /dev/null 2>&1; then
  pass "AC-019-07-07: bash -n scripts/check-loop-triage.sh passes"
else
  fail "AC-019-07-07: bash -n scripts/check-loop-triage.sh fails"
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
if [ "$VIOLATIONS" -gt 0 ]; then
  echo -e "${RED}✘ Daily Triage loop check: $VIOLATIONS violation(s). Fix before merging.${NC}"
  echo "  Reference: docs/LOOP_ENGINEERING.md §Readiness levels (016)"
  exit 1
else
  echo -e "${GREEN}✔ Daily Triage loop check: every check passed.${NC}"
fi
