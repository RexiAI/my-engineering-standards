# AC-008-05: 30-report.md records phase and attempt count

## AC-008-05-01 — The Report section requires a remediation record (AC-004)
Given `agents/spec-mutation-runner.md` is edited per task 5
When the Report section of the prompt is read
Then it requires a remediation record in `30-report.md`
And the record states, for each BLOCK that occurred during the run, the phase (1 or 2) and the attempt count at which it was resolved
And the record states `none` when no BLOCK occurred

## AC-008-05-02 — The record is carried forward, not invented
Given `agents/spec-mutation-runner.md` is edited per task 5
When the Report section of the prompt is read
Then it instructs the Mutation Runner to carry the record from `25-verification.md` and the orchestrator's loop summary
And it instructs the Mutation Runner not to guess or invent the phase and attempt count

## AC-008-05-03 — Missing attempt information is reported, not fabricated
Given `agents/spec-mutation-runner.md` is edited per task 5
And no `25-verification.md` attempt information is present
When the Mutation Runner writes `30-report.md` per the prompt
Then the remediation record says the attempt information is absent rather than fabricating a phase and attempt count

## AC-008-05-04 — Other Report items are unchanged
Given `agents/spec-mutation-runner.md` is edited per task 5
When the Report section of the prompt is read
Then it still requires the Verifier's verdict carried forward
And it still requires the mutation score (or the tier skip reason), the complexity summary, the named equivalent mutants, and the final test status

## AC-008-05-05 — Stage-5a responsibilities are unchanged
Given `agents/spec-mutation-runner.md` is edited per task 5
When the prompt and its frontmatter are read
Then it still does not commit, push, or open a PR
And its permission rules are unchanged
