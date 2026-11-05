# AC-039-01: Lite trigger detection

## AC-039-01-01 — Explicit lite token
Given argv `039-pipeline-lite-mode LITE`
When `scripts/lite-trigger.sh` runs
Then stdout is `lite` and exit code is 0

## AC-039-01-02 — Explicit full token
Given argv `039-pipeline-lite-mode full`
When `scripts/lite-trigger.sh` runs
Then stdout is `full` and exit code is 0

## AC-039-01-03 — No token
Given argv `039-pipeline-lite-mode autopilot`
When `scripts/lite-trigger.sh` runs
Then stdout is `auto` and exit code is 0

## AC-039-01-04 — Partial tokens do not match
Given argv `--lite lite-mode mylite`
When `scripts/lite-trigger.sh` runs
Then stdout is `auto`

## AC-039-01-05 — Conflicting tokens
Given argv `lite full`
When `scripts/lite-trigger.sh` runs
Then exit code is non-zero
And stdout is empty
And stderr names the conflict
