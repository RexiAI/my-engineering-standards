# AC-014-04: Phase-2 loop is bounded in the orchestrator and the /build command

## AC-014-04-01 — commands/build.md describes a bounded post-PR CI loop
Given `commands/build.md` is edited per task 4
When the command is read
Then it describes a loop that starts **after** the PR Opener reports the PR URL
And the loop invokes the Verifier for the post-PR CI check, routes a diagnosed fix to the Coder or Refactorer, re-invokes the PR Opener to commit and push the fix round, then re-invokes the Verifier for a scoped re-check
And it states the loop runs at most **3** rounds

## AC-014-04-02 — agents/spec-pipeline.md describes the same bounded loop
Given `agents/spec-pipeline.md` is edited per task 4
When the prompt is read
Then it describes the same phase-2 loop: check CI → fix → re-push → re-check, up to **3** rounds
And it routes behavior failures to the Coder and structural/complexity failures to the Refactorer

## AC-014-04-03 — Counter independent of Phase 1, max 3 (AC-003)
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then both state the phase-2 counter is **independent of Phase 1**
And both state the phase-2 budget is **max 3**, referencing spec 008's budget section rather than re-declaring the budget

## AC-014-04-04 — Exhaustion stops the pipeline with the escalation payload (AC-004)
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then both state that on the 3rd FAIL the pipeline stops
And both state the pipeline relays the failing check IDs and the last log evidence from `25-verification.md` verbatim
And both state the pipeline escalates to the human
And neither allows a 4th round

## AC-014-04-05 — Never a silent green (AC-004)
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then both state a CI failure is never reported as green without a fixing round having passed
And both state the outcome is recorded in `25-verification.md`

## AC-014-04-06 — Each re-push re-triggers CI
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then both state each fix-round re-push re-triggers the Self CI workflow
And both state the re-check waits for the re-triggered run

## AC-014-04-07 — Orchestrator stays out of the mechanics
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then neither instructs the orchestrator to run the `gh` CI queries itself
And neither instructs the orchestrator to commit or push

## AC-014-04-08 — No open-ended re-run phrasing in the loop
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When both files are read
Then neither contains `re-run until green`
And neither contains any equivalent instruction to keep re-running until green

## AC-014-04-09 — No new infrastructure is introduced
Given `commands/build.md` and `agents/spec-pipeline.md` are edited per task 4
When the change is reviewed
Then it introduces no new files, agents, or infrastructure beyond edits to these two files
