# AC-019-06: The human is notified only when action is required (AC-006)

## AC-019-06-01 — An issue is created only when action is required
Given a run with `ACTION_REQUIRED: yes` or `AMBIGUOUS — NEVER GUESS` entries
When the run completes
Then the run creates a `Daily Triage` issue via `gh` with the skill's report as the body
And the issue is signed `Loop Engineering — Daily Triage`

## AC-019-06-02 — No issue and no notification on a clean run
Given a run with nothing actionable (`outcome: nothing_actionable`) or a paused/exceeded run
When the run completes
Then no issue is created and no notification is sent
And the `loop-run-log.md` entry is the only artifact of the run

## AC-019-06-03 — An open triage issue is updated, not duplicated
Given a `Daily Triage` issue is already open
When a later run requires action
Then the run updates the existing issue (`gh issue edit` / comment) with the current run's report
And no duplicate issue is created

## AC-019-06-04 — The run records the notification outcome in its log entry
Given a run that created or updated the triage issue
When the run-log entry is inspected
Then `actions_taken` lists the issue create/update
And `outcome` is `action_required`
