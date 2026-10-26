# AC-035: `/autopilot` command

## AC-035-06 — Single slug runs the whole pipeline unattended
Given the command file `commands/autopilot.md` with `agent: spec-pipeline`
And a spec `specs/001-x/00-informal.md` exists
When `/autopilot 001-x` is invoked
Then it delegates to `spec-pipeline` with autopilot on
And it does not stop for the human review gate
And it asks the user nothing

## AC-035-07 — Multiple slugs form an ordered queue
Given `specs/001-x/` and `specs/002-y/` exist
When `/autopilot 001-x 002-y` is invoked
Then it processes slugs in the order given
And it treats each as its own autopilot run

## AC-035-08 — No slug is a usage error
Given no slug argument
When `/autopilot` is invoked with no `$ARGUMENTS`
Then it prints a usage/error line
And it stops without guessing a slug
