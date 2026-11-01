---
description: Run one or more specs end to end in autopilot mode — no human review gate, every ask resolved per the documented disposition and recorded.
agent: spec-pipeline
---

Run the spec pipeline in autopilot mode (`docs/SPEC_PIPELINE.md §Autopilot mode`)
for every slug in `$ARGUMENTS`, in the order given.
Treat each slug as its own autopilot run:
`/autopilot 001-x 002-y` runs `001-x` to completion (or to its first hard stop),
then `002-y`.

Autopilot is explicitly on for this command, regardless of any token or
`SPEC_AUTOPILOT` value: delegate to `spec-pipeline` with autopilot enabled.
Never ask the user anything, never wait for human input, and never stop for the
human review gate between Specifier and Coder. Resolve every ask per the
`## Autopilot mode` disposition table and record the decision in
`specs/NNN-slug/45-decisions.md` (`scripts/autopilot-decisions.sh`).

If `$ARGUMENTS` is empty, print exactly:

    usage: /autopilot <slug> [<slug> ...]

and stop. Do not guess or infer a slug from the working tree.

Before each queue item run `scripts/autopilot-preflight.sh <slug>`; on a non-zero
exit stop the queue. At the first hard stop write the morning report with
`scripts/autopilot-report.sh`, then stop the queue — do not skip to the next slug.
