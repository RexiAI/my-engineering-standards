# AC-035: Telemetry

## AC-035-28 — Record accepts the autopilot fields
Given a record JSON containing `"autopilot":true`, `"autoDecisions":3`, `"stopReason":"phase-1 budget exhausted"`
And the record has the required keys (`gatesFailed`, `warnings`, `durationSec`, `outcome`, one of `specSlug`/`jiraKey`)
When `record-gate-run.sh -record '<json>'` runs
Then it appends the record to the runs file with those three fields intact
And it exits 0

## AC-035-29 — Invalid autopilot field values are rejected
Given a record containing `"autopilot":"maybe"` or `"autoDecisions":"three"`
When `record-gate-run.sh -record '<json>'` runs
Then it prints a validation error naming the field
And it exits 1
And it appends nothing
