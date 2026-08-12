# AC-019-07: Shell check script carries AC-019-01…07 and is wired into self-ci (traceability precedent)

## AC-019-07-01 — The script exists in house style and is the traceability carrier
Given the 009/010/015/016 precedent makes a shell check script the test carrier
When `scripts/check-loop-triage.sh` is read
Then it follows the house style: `#!/bin/bash`, `set -euo pipefail`, header comment, `PASS`/`FAIL` lines, violation counter, summary, non-zero exit on violations
And it references every task-level ID `AC-019-01`, `AC-019-02`, `AC-019-03`, `AC-019-04`, `AC-019-05`, `AC-019-06`, `AC-019-07` so `check-scenario-traceability.sh` resolves them

## AC-019-07-02 — The script verifies the workflow shape (AC-001)
Given the daily-triage workflow is the loop's scheduler
When the script's workflow check runs
Then it verifies `.github/workflows/daily-triage.yml` exists
And it contains a `schedule:` with a weekday cron (matching `1-5`)
And it contains a step running `opencode run`
And it references `skills/loop-triage/SKILL.md`
And it grants `issues: write`

## AC-019-07-03 — The script verifies the skill shape (AC-002, AC-004)
Given the triage skill is the run's contract
When the script's skill check runs
Then it verifies `skills/loop-triage/SKILL.md` exists
And it contains the never-guess rule
And it contains the `ACTION_REQUIRED:` output section
And it contains the verbatim L1 statement: no code change, no PR, no merge
And it contains `allowed-tools` and that set includes no commit/push tool

## AC-019-07-04 — The script is wired into self-ci (AC-001, AC-003, AC-005, AC-006 aggregate gate)
Given the repo's PR gate is `self-ci.yml`
When the wiring check runs
Then it verifies `.github/workflows/self-ci.yml` references `check-loop-triage.sh`
And a violation exits 1 and fails the Validate job (no `continue-on-error`)

## AC-019-07-05 — The clean repo passes
Given tasks 1-6 are complete
When `scripts/check-loop-triage.sh` runs against the real repo
Then it exits 0
And it reports every referenced AC-019-0N check passing

## AC-019-07-06 — Negative cases are genuinely exercised
Given a temp fixture with a missing workflow, a missing skill, a skill without the never-guess rule, and a schedule-less workflow
When the script runs against that fixture
Then each missing or malformed artifact is named in a `FAIL` line and the script exits 1

## AC-019-07-07 — The script is read-only and parses clean
Given a compliant repo
When `scripts/check-loop-triage.sh` runs against it
Then no file is modified
And `bash -n scripts/check-loop-triage.sh` passes
And shellcheck reports no issues
