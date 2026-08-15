---
description: Run the Coder, Refactorer, Verifier, and Architect stages of the spec pipeline after a reviewed spec, ending in a draft PR.
agent: spec-pipeline
---

Run stages 2-5 of the spec pipeline (`docs/SPEC_PIPELINE.md`) for: `specs/$ARGUMENTS/`

Confirm `specs/$ARGUMENTS/10-tasks.md` and `specs/$ARGUMENTS/20-acceptance/` exist.
If not, tell the user to run `/spec $ARGUMENTS` first and stop.

Otherwise delegate in order: `spec-coder`, then `spec-refactorer`, then `spec-verifier`,
then `spec-mutation-runner` (stage 5a), then `spec-pr-opener` (stage 5b). Each stage
must report green before the next starts. The Verifier's verdict must be PASS
before stage-5 runs at all — if it's FAIL, stop and relay its `25-verification.md`
report; do not run stage 5. If the Mutation Runner reports the suite is no
longer green, stop and relay its report; do not run the PR Opener anyway. If
any stage stops with a question or a failing gate, relay it verbatim and stop
the pipeline — do not attempt to resolve it yourself or skip ahead.

On success the PR Opener opens a draft PR. Report its URL. On failure, report
`specs/$ARGUMENTS/30-report.md`'s explanation of what failed.

After the PR Opener reports the PR URL, run the bounded phase-2 loop (see
`docs/SPEC_PIPELINE.md §Post-PR CI check-and-remediate loop (phase 2)`):

1. Invoke `spec-verifier` for the post-PR CI check.
2. On PASS, report the PR URL and stop.
3. On FAIL, route the diagnosed fix to `spec-coder` (behavior) or
   `spec-refactorer` (structure), re-invoke `spec-pr-opener` to commit and push
   the fix round, then re-invoke `spec-verifier` for a scoped re-check of the
   previously-failing checks. Each re-push re-triggers the Self CI workflow; the
   re-check waits for the re-triggered run.
4. The loop runs at most 3 rounds: the phase-2 counter is independent of Phase 1
   and capped at max 3, per spec 008's remediation-budget section (do not
   re-declare the budget).
5. On the 3rd FAIL the pipeline stops: relay the failing check IDs and the last
   log evidence from `25-verification.md` verbatim and escalate to the human —
   no 4th round. A CI failure is never reported as green without a fixing round
   having passed; the outcome is recorded per round in `25-verification.md`.
