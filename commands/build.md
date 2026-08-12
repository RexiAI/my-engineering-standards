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
