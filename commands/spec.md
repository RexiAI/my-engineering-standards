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
`10-tasks.md` and `20-acceptance/`, and any open questions it raised. When it
prints `normal`, stop — do not run `/build` automatically. The human reviews these
files before continuing.

# Autopilot detection

Before treating `$ARGUMENTS` as a slug, path, or informal-spec content, run
`scripts/autopilot-trigger.sh $ARGUMENTS`. When it prints `autopilot`, remove the
literal token from `$ARGUMENTS` and continue: do not stop after stage 1 for human
review — continue the whole pipeline exactly as `/build` does, with autopilot on
(`docs/SPEC_PIPELINE.md §Autopilot mode`). When it prints `normal`, behavior is
unchanged and the human review gate stays. Detection is delegated to the script;
do not re-implement the token match here.
