---
description: Run the Coder, Refactorer, and Architect stages of the spec pipeline after a reviewed spec, ending in a draft PR.
agent: pipeline
---

Run stages 2-4 of the spec pipeline (`docs/SPEC_PIPELINE.md`) for: `specs/$ARGUMENTS/`

Confirm `specs/$ARGUMENTS/10-tasks.md` and `specs/$ARGUMENTS/20-acceptance/` exist.
If not, tell the user to run `/spec $ARGUMENTS` first and stop.

Otherwise delegate in order: `coder`, then `refactorer`, then `architect`. Each
stage must report green before the next starts. If any stage stops with a question
or a failing gate, relay it verbatim and stop the pipeline — do not attempt to
resolve it yourself or skip ahead.

On success the Architect opens a draft PR. Report its URL. On failure, report
`specs/$ARGUMENTS/30-report.md`'s explanation of what failed.
