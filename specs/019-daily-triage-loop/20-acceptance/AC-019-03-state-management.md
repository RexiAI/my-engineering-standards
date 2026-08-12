# AC-019-03: Each run reads and writes STATE.md and appends one loop-run-log entry (AC-003)

## AC-019-03-01 — The run reads STATE.md before triaging
Given the run starts
When the run's pre-flight executes
Then it reads `STATE.md`
And it checks the `KILL SWITCH:` line first
And it loads the prior run's open questions, high-priority items, and watch-list items

## AC-019-03-02 — The run writes triage outcomes to STATE.md at the end
Given the run completed its triage
When it writes state
Then `## High Priority` and `## Watch List` reflect this run's findings
And resolved items move to `## Recent Noise` or are dropped, never carried forever
And unresolved open questions are carried forward or marked resolved

## AC-019-03-03 — Each run appends exactly one JSON entry with the required fields
Given a run finished
When `loop-run-log.md` is inspected
Then exactly one new JSON line was appended with keys `run_id`, `pattern`, `duration_s`, `items_found`, `actions_taken`, `escalations`, `tokens_estimate`, `outcome`
And `run_id` is a UTC timestamp of the form `YYYY-MM-DD-HHMMSS`
And `pattern` is `daily-triage`
And `outcome` is one of `nothing_actionable`, `report_only`, `action_required`, `budget_exceeded`, `paused`

## AC-019-03-04 — The log is append-only
Given prior run-log entries exist
When a later run appends
Then prior entries are not edited or deleted during the run
And entries older than 30 days are pruned

## AC-019-03-05 — Missing state files are bootstrapped, not fatal
Given a first run with no `STATE.md`, `loop-run-log.md`, or `loop-budget.md`
When the run starts
Then the files are created from the 016 templates when present, otherwise with the 016-documented shapes (`KILL SWITCH:` line, `## High Priority`/`## Watch List`/`## Recent Noise` sections, JSON-line log contract)
And the run does not fail for a missing file it can create

## AC-019-03-06 — Only the two state files are written by the run
Given the run writes outcomes
When the run's writes are inspected
Then only `STATE.md` and `loop-run-log.md` are modified by the run (budget file is read-only at L1)
And no other tracked file changes as a result of the run
