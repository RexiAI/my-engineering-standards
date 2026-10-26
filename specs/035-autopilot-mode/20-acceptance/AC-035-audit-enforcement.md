# AC-035: Enforcement in `check-audit-trail.sh`

## AC-035-33 — `Autopilot: true` without `45-decisions.md` FAILs
Given `specs/<slug>/30-report.md` contains `Autopilot: true`
And `specs/<slug>/45-decisions.md` is missing or empty
When `scripts/check-audit-trail.sh <slug>` runs
Then it FAILs the folder
And it exits non-zero

## AC-035-34 — `Autopilot: true` with `45-decisions.md` passes
Given `specs/<slug>/30-report.md` contains `Autopilot: true`
And `specs/<slug>/45-decisions.md` is present and non-empty
When `scripts/check-audit-trail.sh <slug>` runs on an otherwise complete folder
Then it exits 0

## AC-035-35 — No marker → `45-decisions.md` is optional
Given `specs/<slug>/30-report.md` has no `Autopilot: true` line
And `45-decisions.md` is present or absent
When `scripts/check-audit-trail.sh <slug>` runs
Then the presence or absence of `45-decisions.md` does not affect the verdict
