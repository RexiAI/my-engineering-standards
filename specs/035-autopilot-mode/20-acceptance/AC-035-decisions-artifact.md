# AC-035: `45-decisions.md` and `30-report.md` markers

## AC-035-18 — Each decision entry records six fields
Given autopilot resolves a decision
When `specs/NNN-slug/45-decisions.md` is written
Then the entry has a `Condition:` line
And an `Options:` line
And a `Chosen:` line
And a `Why:` line
And a `Reversibility:` line
And an `At:` line holding an ISO-8601 UTC timestamp `YYYY-MM-DDTHH:MM:SSZ`

## AC-035-19 — Empty run writes the single no-decision line
Given an autopilot run resolves nothing
When `45-decisions.md` is written
Then it contains exactly the line `No autopilot decisions were required`
And no decision entries

## AC-035-20 — `30-report.md` carries autopilot and the decision count
Given an autopilot run with N decisions
When `30-report.md` is written
Then it contains the line `Autopilot: true`
And the line `Autopilot decisions: N` where N equals the entry count in `45-decisions.md` (0 when empty)
