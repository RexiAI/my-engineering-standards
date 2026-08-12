# AC-017-02: Fix attempts run in an isolated worktree and are verified before propose

## AC-017-02-01 — Fixes are minimal and isolated in a worktree (AC-003)
Given `skills/ci-triage/SKILL.md` is extended per task 2
When the file is read
Then it states the fix is the smallest change that addresses the specific failure
And it requires the fix to be made in an isolated worktree via `git worktree add`
And it forbids fixing on the swept branch or on `main`

## AC-017-02-02 — A separate checker verifies before any PR or comment (AC-003)
Given `skills/ci-triage/SKILL.md` is extended per task 2
When the file is read
Then it states a maker/checker split: the fixing pass and a separate checking pass are distinct
And it states the checker confirms before any PR or comment is proposed
And it states the checker verifies the fix addresses the failure
And it states the checker verifies there are no unrelated changes
And it states the checker verifies tests and lint pass (local suite plus `make validate-all` / `make lint`)

## AC-017-02-03 — Remediation is bounded at max 3 attempts (AC-004)
Given `skills/ci-triage/SKILL.md` is extended per task 2
When the file is read
Then it states remediation runs at most **3 attempts** per failure
And it states each attempt is recorded in `loop-run-log.md`
And it states the counter is the loop's own circuit breaker, independent of spec 008's pipeline budget and 014's round counter

## AC-017-02-04 — Exhaustion escalates to the human with pruned context (AC-004)
Given `skills/ci-triage/SKILL.md` is extended per task 2
When the file is read
Then it states that on attempt exhaustion the loop escalates to a human with pruned context: the failing job, the run link, and the last log excerpt
And it states the loop never loops forever

## AC-017-02-05 — Escalation conditions are enumerated (AC-004)
Given `skills/ci-triage/SKILL.md` is extended per task 2
When the file is read
Then it enumerates the escalation conditions: infrastructure failure, more than 5 files or core architecture, security-sensitive failures, max attempts exceeded, and intermittent flakes needing quarantine

## AC-017-02-06 — The sweeper defers to an in-flight remediation on the same failure
Given `skills/ci-triage/SKILL.md` is extended per task 2
When the file is read
Then it states the sweeper checks `STATE.md` before starting a fix
And it states the sweeper defers when `STATE.md` shows an in-flight remediation of the same failure on the same branch (the 014-owned `spec/NNN-slug` case)
