---
description: Run the Specifier stage of the spec pipeline on an informal spec, then stop for human review.
agent: spec-pipeline
---

Run stage 1 of the spec pipeline (`docs/SPEC_PIPELINE.md`) for: $ARGUMENTS

If `$ARGUMENTS` looks like an existing `specs/NNN-slug/00-informal.md` path, use it
directly. Otherwise treat `$ARGUMENTS` as the informal spec content itself: pick the
next sequence number, choose a short slug from the content, create
`specs/NNN-slug/00-informal.md` with that content verbatim, then proceed.

Delegate to the `spec-specifier` subagent. When it finishes, print the paths to
`10-tasks.md` and `20-acceptance/`, and any open questions it raised. Then stop —
do not run `/build` automatically. The human reviews these files before continuing.
