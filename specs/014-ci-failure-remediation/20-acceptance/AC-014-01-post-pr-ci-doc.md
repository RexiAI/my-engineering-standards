# AC-014-01: Post-PR CI check loop documented in docs/SPEC_PIPELINE.md

## AC-014-01-01 — The exact CI query is named (AC-001)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then it names `gh pr checks <PR_NUMBER> --json name,state,bucket,workflow,link` as the post-PR CI status query
And it states the `bucket` field (`pass`/`fail`/`pending`) is the PASS/FAIL parse rule

## AC-014-01-02 — The CI platform and workflow are grounded in this repo
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then it names GitHub Actions and the **Self CI** workflow (`.github/workflows/self-ci.yml`) as the CI that runs on a feature-branch PR
And it does not name any CI platform this repo does not use

## AC-014-01-03 — Pending checks are polled, not misread
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then it states pending checks are polled until terminal (e.g. `gh pr checks --watch` or a bounded re-query)
And it states `pending` is neither a pass nor a fail

## AC-014-01-04 — Failing check IDs and log read are named (AC-002)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then it names the failing-check-ID capture as `gh api repos/RexiAI/my-engineering-standards/commits/<head_sha>/check-runs`
And it names the failing-log read as `gh run list --branch spec/NNN-slug --workflow "Self CI"` followed by `gh run view <RUN-ID> --log-failed`
And it states the failure reason is recorded in `25-verification.md`

## AC-014-01-05 — Max 3 rounds, independent of Phase 1 (AC-003)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
And spec 008's remediation-budget section exists in the same file
When the file is read
Then the sub-section states the fix-and-repush loop runs at most **3** rounds
And the sub-section states the phase-2 counter is **independent of Phase 1**
And the sub-section states each re-push re-triggers CI

## AC-014-01-06 — Exhaustion escalates to the human (AC-004)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the sub-section states that on exhaustion the pipeline stops and escalates to the human with the failing check IDs and the last log evidence
And the sub-section states the outcome is never a silent green

## AC-014-01-07 — Per-check and per-round outcome recorded (AC-005)
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the sub-section states the CI outcome is recorded per check and per round in `25-verification.md`

## AC-014-01-08 — No open-ended re-run phrasing
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the sub-section does not contain `re-run until green`
And the sub-section does not contain any equivalent instruction to keep re-running until green

## AC-014-01-09 — Ordering dependency on 008 is stated
Given `docs/SPEC_PIPELINE.md` is edited per task 1
When the file is read
Then the sub-section states the phase-2 budget policy comes from spec 008 and the mechanism is valid only once 008's section exists
