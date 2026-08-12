# AC-019-05: Budget cap + kill switch documented and honored; early exit when nothing actionable (AC-005)

## AC-019-05-01 — loop-budget.md documents the daily cap for the loop
Given the loop foundation defines `loop-budget.md`
When the daily-triage budget file is inspected
Then it documents the `daily-triage` daily token cap, max sub-agent spawns/run, on-exceed actions, and the kill switch
And at L1 the max sub-agent spawns per run is 0

## AC-019-05-02 — The repo-label kill switch pauses the loop
Given a `loop-pause-all` label exists on the repo
When the run's pre-flight executes
Then the run detects the label
And it exits early appending a `loop-run-log.md` entry with `outcome: paused`
And it performs no triage

## AC-019-05-03 — The STATE.md kill-switch flag pauses the loop
Given `STATE.md` contains `KILL SWITCH: on`
When the run's pre-flight executes
Then the run exits early appending an entry with `outcome: paused`
And it performs no triage
And `KILL SWITCH: off` allows the run to proceed

## AC-019-05-04 — The budget cap is honored as an early exit
Given today's `tokens_estimate` sum from `loop-run-log.md` plus this run's estimate would exceed the cap
When the run's pre-flight executes
Then the run appends an entry with `outcome: budget_exceeded` and exits before triaging
And the run does not attempt to partially triage under the cap

## AC-019-05-05 — The loop exits early when nothing is actionable
Given zero PRs needing action, zero specs awaiting build or stuck, and green CI
When the run completes its pre-flight and triage scan
Then it appends an entry with `outcome: nothing_actionable`
And it prunes resolved items and skips issue creation
And it does not fabricate work to justify the run

## AC-019-05-06 — Pre-flight order is fixed
Given the run starts
When the skill's pre-flight sequence is read
Then the order is: kill switch check, budget check, then triage
