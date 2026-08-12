# AC-017-04: STATE.md CI Sweeper section is updated each run and pruned on resolve

## AC-017-04-01 — The STATE.md CI Sweeper section contract is defined (AC-005)
Given `skills/ci-triage/SKILL.md` is extended per task 4
When the file is read
Then it defines the **CI Sweeper** section of `STATE.md` with these fields: last run, failing commit SHA, failing job, attempt count, worktree/PR link, and outcome

## AC-017-04-02 — Resolved failures are pruned (AC-005)
Given `skills/ci-triage/SKILL.md` is extended per task 4
When the file is read
Then it states the CI Sweeper section is updated on each run
And it states resolved failures are removed from the section while in-flight failures are retained

## AC-017-04-03 — The dependency on spec 016's state files is explicit
Given `skills/ci-triage/SKILL.md` is extended per task 4
When the file is read
Then it states `STATE.md` and `loop-run-log.md` are spec 016's files, consumed by reference
And it states the CI Sweeper section is operative only after 016 lands
And it states that until then the loop records state at L1 (report) and never runs unattended

## AC-017-04-04 — Cost guidance is documented (AC-006)
Given `skills/ci-triage/SKILL.md` is extended per task 4
When the file is read
Then it states the loop exits early when CI is green
And it states there is no full sweep on a no-op run (no code change since the last sweep, or the failure is already resolved)
And it states the per-run token estimate is recorded per spec 016's `loop-run-log.md` schema
