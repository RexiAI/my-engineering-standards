# AC-035: Morning report

## AC-035-21 — PR opened → report under `docs/changes/`
Given an autopilot queue opened at least one PR
When the queue finishes or stops
Then a report is written to `docs/changes/autopilot-YYYY-MM-DD.md`
And `YYYY-MM-DD` is the UTC date the queue started

## AC-035-22 — No PR → report under `specs/`
Given an autopilot queue opened no PR
When the queue finishes or stops
Then a report is written to `specs/autopilot-YYYY-MM-DD.md`

## AC-035-23 — Report shape
Given a queue that stops or finishes
When the morning report is read
Then it has a per-spec status block (slug plus PR URL or stop reason) in queue order up to and including the stopping spec
And a `Decisions` section (or per-spec references to `45-decisions.md`)
And a `Stop reasons` section when any spec stopped
And a `Follow-up proposals` section when any out-of-scope finding was recorded
