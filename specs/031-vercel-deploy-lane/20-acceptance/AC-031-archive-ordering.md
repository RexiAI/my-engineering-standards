# AC-031: Archive ordering — archive-spec.sh and check-specs-archived.sh

## AC-031-22 — archive-spec.sh includes 40-deploy.md in one-pager
Given a finished spec folder with `40-deploy.md` present
When `scripts/archive-spec.sh <slug>` is run
Then the generated `docs/changes/<slug>.md` contains the `40-deploy.md` content embedded verbatim under a `## 40-deploy.md` heading

## AC-031-23 — archive-spec.sh still refuses without 30-report.md
Given a spec folder without `30-report.md`
When `scripts/archive-spec.sh <slug>` is run
Then it exits non-zero with an error message stating the spec is not finished

## AC-031-24 — check-specs-archived.sh backward compatible with existing archives
Given an existing archived spec in `docs/changes/NNN-slug.md` with no `specs/NNN-slug/` folder
When `scripts/check-specs-archived.sh` is run
Then it exits 0 and reports the spec as archived (no false failure from the missing `40-deploy.md`)

## AC-031-25 — Phase-3 budget exhausted: spec not archived, no false failure
Given a spec folder with `30-report.md` and `40-deploy.md` containing verdict `ESCALATED` and the marker `Phase-3 budget exhausted`
And no `docs/changes/<slug>.md` archive exists (5d never ran)
And both files are in the git index
When `scripts/check-specs-archived.sh` is run
Then it exits 0 and does not report a false failure for this spec

## AC-031-26 — Pre-031 in-flight spec without 40-deploy.md still requires archival
Given a spec folder with `30-report.md` but no `40-deploy.md` (a pre-031 in-flight spec)
And no `docs/changes/<slug>.md` archive exists
When `scripts/check-specs-archived.sh` is run
Then it exits 1 and reports the spec as needing archival (the budget-exhaustion exception does not apply)

## AC-031-27 — 30-report.md remains the finished signal
Given `scripts/archive-spec.sh` and `scripts/check-specs-archived.sh` have been updated
When both scripts are read
Then they still key their finished-spec detection off the presence of `30-report.md`, unchanged from the pre-031 behavior
