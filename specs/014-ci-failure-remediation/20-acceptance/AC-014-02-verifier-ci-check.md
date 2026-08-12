# AC-014-02: Verifier runs the post-PR CI check and records the verdict

## AC-014-02-01 — The Verifier runs the real CI query (AC-001)
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it adds a post-PR CI check that runs `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link`
And it instructs the Verifier to record PASS/FAIL per check from the `bucket` field

## AC-014-02-02 — Pending checks are polled to terminal
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it instructs the Verifier to poll pending checks until terminal (`gh pr checks --watch` or bounded re-query)
And it instructs the Verifier not to treat `pending` as a pass or a fail

## AC-014-02-03 — On FAIL the Verifier reads the logs and records the reason (AC-002)
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it instructs the Verifier to capture the failing check IDs via `gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`, selecting `conclusion == "failure"` and recording `name` + `id`
And it instructs the Verifier to read the failing job logs via `gh run list --branch spec/NNN-slug --workflow "Self CI"` then `gh run view <RUN-ID> --log-failed`
And it instructs the Verifier to record the concrete failure reason

## AC-014-02-04 — Per-check and per-round record in 25-verification.md (AC-005)
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it requires a **Post-PR CI check** section in `25-verification.md`
And the section records, per round: the round index, each check's PASS/FAIL, the failing check IDs, and the last log excerpt

## AC-014-02-05 — Diagnosis handed back, scoped re-check on re-trigger
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it instructs the Verifier to hand the diagnosis to the orchestrator for routing, not to fix anything itself
And it instructs the Verifier, on a re-trigger, to read its prior `25-verification.md` and re-check only the previously-failing checks

## AC-014-02-06 — Frontmatter and permissions are unchanged
Given `agents/spec-verifier.md` is edited per task 2
When the prompt's frontmatter is read
Then it still allows edits only to `specs/*/25-verification.md`
And it still denies `git commit*` and `git push*`

## AC-014-02-07 — No open-ended re-run phrasing is added
Given `agents/spec-verifier.md` is edited per task 2
When the prompt is read
Then it does not contain `re-run until green`
And it does not contain any equivalent instruction to re-check without a stated cap
