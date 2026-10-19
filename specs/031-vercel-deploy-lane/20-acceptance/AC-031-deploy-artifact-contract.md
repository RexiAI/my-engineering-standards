# AC-031: 40-deploy.md artifact contract and audit-trail extension

## AC-031-17 — 40-deploy.md evidence format defined
Given `docs/SPEC_PIPELINE.md` audit-contract section has been updated
When the Deploy Verifier row is read
Then it specifies: deploy URL, build status (pass/fail/skip), health check status, E2E verdict (pass/fail/skip), timestamp, phase-3 attempt count, and verdict (PASS/FAIL/ESCALATED/SKIPPED)

## AC-031-18 — check-audit-trail.sh checks 40-deploy.md for frontend repos
Given a spec folder for a frontend repo with `30-report.md` and `40-deploy.md` present
When `scripts/check-audit-trail.sh <slug>` is run
Then it exits 0 and reports `40-deploy.md` present and non-empty

## AC-031-19 — check-audit-trail.sh accepts skip reason for non-frontend repos
Given a spec folder for a non-frontend repo with `30-report.md` and `40-deploy.md` containing `Verdict: SKIPPED`
When `scripts/check-audit-trail.sh <slug>` is run
Then it exits 0 and reports the skip reason as acceptable

## AC-031-20 — 40-deploy.md is NOT a sixth Verifier check
Given `scripts/check-audit-trail.sh` has been updated
When the `FIVE_CHECKS` array is inspected
Then it still contains exactly five entries: scenario traceability, full test suite, complexity gate, design-principles gate, scenario-to-behavior spot check
And the new `40-deploy.md` check is implemented as a separate function, not appended to `FIVE_CHECKS`

## AC-031-21 — check-audit-trail.sh fails on missing 40-deploy.md for frontend repo
Given a spec folder for a frontend repo with `30-report.md` but no `40-deploy.md`
When `scripts/check-audit-trail.sh <slug>` is run
Then it exits non-zero and reports the missing `40-deploy.md`
