# AC-035: Autopilot trigger detection

## AC-035-01 — Literal token `autopilot` (any case) triggers
Given an invocation `scripts/autopilot-trigger.sh autopilot`
And `SPEC_AUTOPILOT` is unset
When the script runs
Then it prints exactly `autopilot` to stdout
And it exits 0

## AC-035-02 — `SPEC_AUTOPILOT=1` triggers without a token
Given an invocation `scripts/autopilot-trigger.sh 001-x`
And the environment has `SPEC_AUTOPILOT=1`
When the script runs
Then it prints exactly `autopilot`
And it exits 0

## AC-035-03 — No token and unset env is not autopilot
Given an invocation `scripts/autopilot-trigger.sh 001-x`
And `SPEC_AUTOPILOT` is unset
When the script runs
Then it prints exactly `normal`
And it exits 0

## AC-035-04 — Non-`1` env value is not autopilot
Given an invocation `scripts/autopilot-trigger.sh`
And `SPEC_AUTOPILOT=0` (also true for empty string, `true`, `yes`)
When the script runs
Then it prints exactly `normal`
And it exits 0

## AC-035-05 — Token inside a larger word is not a trigger
Given an invocation `scripts/autopilot-trigger.sh myautopilot`
And `SPEC_AUTOPILOT` is unset
When the script runs
Then it prints exactly `normal`
And it exits 0
