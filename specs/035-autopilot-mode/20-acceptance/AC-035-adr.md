# AC-035: ADR 0013

## AC-035-37 — ADR file exists and follows the template
Given `docs/adr/0013-autopilot-mode.md`
When it is read
Then it has `## Status: Accepted`
And `## Context`, `## Decision`, `### Alternatives Considered` (a table), `## Consequences`, `## Compliance`, `## Notes`
And `## Compliance` names `check-stop-and-ask-matrix.sh` and `check-audit-trail.sh` as enforcement
And the Decision states the trigger, the ask→decide conversion, that stops stay stops, the never-list, and the `45-decisions.md` and morning-report artifacts

## AC-035-38 — ADR is indexed
Given `docs/adr/README.md`
When the index table is read
Then it has a row for `0013` with a title and status `Accepted`
