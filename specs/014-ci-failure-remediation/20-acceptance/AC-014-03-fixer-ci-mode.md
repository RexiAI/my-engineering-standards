# AC-014-03: Fixers get a bounded fix-from-CI-error mode

## AC-014-03-01 — Coder fixes only the diagnosed failing check
Given `agents/spec-coder.md` is edited per task 3
When the prompt is read
Then it states the Coder may be re-invoked to fix a CI failure
And it instructs the Coder to fix only the failing check's cause as diagnosed in `25-verification.md`

## AC-014-03-02 — Coder's re-fix is bounded by the orchestrator's counter (AC-003)
Given `agents/spec-coder.md` is edited per task 3
When the prompt is read
Then it states the round count is the orchestrator's, capped at **3**
And it instructs the Coder to stop rather than re-fix endlessly

## AC-014-03-03 — Refactorer gets the same bounded rule
Given `agents/spec-refactorer.md` is edited per task 3
When the prompt is read
Then it states the same bounded re-fix rule for structural/complexity failures surfaced by CI
And it states the round count is the orchestrator's, capped at **3**

## AC-014-03-04 — Fixers never push
Given `agents/spec-coder.md` and `agents/spec-refactorer.md` are edited per task 3
When the prompts' frontmatter is read
Then both still deny `git push*`
And both prompts state the re-push is the PR Opener's job

## AC-014-03-05 — Information barriers are unchanged
Given `agents/spec-coder.md` and `agents/spec-refactorer.md` are edited per task 3
When the prompts are read
Then the Coder still must not read `00-informal.md`
And the Refactorer still must not read `specs/**`

## AC-014-03-06 — No open-ended re-run phrasing is added
Given `agents/spec-coder.md` and `agents/spec-refactorer.md` are edited per task 3
When the prompts are read
Then neither contains `re-run until green`
And neither contains any equivalent instruction to re-fix without a stated cap
