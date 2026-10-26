# AC-035: `## Autopilot mode` doc section

## AC-035-11 — Section declares trigger and no-questions rule
Given `docs/SPEC_PIPELINE.md`
When the `## Autopilot mode` section is read
Then it names the trigger (token `autopilot`, `SPEC_AUTOPILOT=1`, `/autopilot`)
And it states no stage calls the question tool, emits `BLOCKED — <question>`, or waits for human input
And it states every ask becomes choose-default-record-continue

## AC-035-12 — A disposition exists for all 12 matrix rows
Given the 12 conditions in `## Stop-and-Ask decision matrix`
When the `## Autopilot mode` disposition table is read
Then every one of the 12 conditions has an autopilot disposition
And `Deploy verification fails` is among the 12

## AC-035-13 — All 6 hard stops are listed
Given the `## Autopilot mode` section
When it is read
Then all 6 hard stops are present: dirty tree outside the current spec folder; no repo / no `00-informal.md`; phase-1 or phase-2 budget exhausted; deploy failure after 3 attempts; `30-report.md` missing or not green at PR time; any never-list action
And the section states autopilot never converts a hard stop into a guess

## AC-035-14 — All 9 never-list refusals are listed
Given the `## Autopilot mode` section
When it is read
Then all 9 refusals are present: no merge, no git tag, no push to `main`/`master`, no force-push, no branch deletion, no gate-threshold change, no secret creation/rotation, no writes outside the target repo, no `git init`/submodule scaffolding
And it states these are refusals, not decisions
