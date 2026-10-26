# AC-035: Preflight

## AC-035-24 — Clean tree (or dirty only inside the spec folder) passes
Given a repo where every dirty path is inside `specs/<current-slug>/`
When `scripts/autopilot-preflight.sh <slug>` runs
Then it exits 0

## AC-035-25 — `gh` auth and both tokens are required
Given a missing `gh` auth, or an empty `GITHUB_TOKEN` or `GH_TOKEN`
When `scripts/autopilot-preflight.sh <slug>` runs
Then it prints `preflight: <reason>` to stderr
And it exits non-zero
And it does not continue to later checks

## AC-035-26 — Spec folder must exist
Given a named slug whose spec folder does not exist
When `scripts/autopilot-preflight.sh <slug>` runs
Then it prints a reason and exits non-zero

## AC-035-27 — Judgment backend is optional
Given `JUDGMENT_*` is unconfigured (or the backend unreachable)
When `scripts/autopilot-preflight.sh <slug>` runs
Then it does not fail for the missing backend
And it exits 0 (or records a warning and still exits 0)
