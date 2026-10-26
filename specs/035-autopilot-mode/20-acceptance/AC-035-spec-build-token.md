# AC-035: `/spec` and `/build` honor the token

## AC-035-09 — `/spec` with the token does not stop for human review
Given `commands/spec.md` runs stage 1 via `spec-pipeline`
And the invocation is `/spec autopilot 001-x`
When the token is detected by `scripts/autopilot-trigger.sh`
Then it does not stop after stage 1 for human review
And it continues the pipeline in autopilot

## AC-035-10 — `/build` with the token runs stages 2-5 in autopilot
Given `commands/build.md` runs stages 2-5 via `spec-pipeline`
And the invocation is `/build autopilot 001-x`
When the token is detected by `scripts/autopilot-trigger.sh`
Then every stage resolves asks per the autopilot disposition
And no stage emits `BLOCKED — <question>` or waits for input
