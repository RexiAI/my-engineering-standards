# AC-045-11: Self-hosting and self-CI

## AC-045-11-01 — The deliverable check passes on the compliant tree
Given the completed change
When `scripts/check-pr-size-gate.sh` runs in this repository
Then it exits 0
And it is executable
And it writes no file

## AC-045-11-02 — The deliverable check fails on a broken tree
Given a scratch copy of this repository with
`scripts/pr-review-verdict.sh` removed
When `scripts/check-pr-size-gate.sh` runs against that copy
Then it exits 1
And it prints a `FAIL` line citing the missing artifact

## AC-045-11-03 — Self-CI runs the deliverable check and the script tests
Given `.github/workflows/self-ci.yml`
When its Validate job steps are read
Then it runs `scripts/check-pr-size-gate.sh`
And it runs `scripts/tests/pr-size-gate.bats`
And it runs `scripts/tests/pr-review-verdict.bats`
And it runs `scripts/tests/pr-automerge-eligibility.bats`
And it runs `scripts/tests/pr-automerge-notify.bats`

## AC-045-11-04 — This repository self-hosts both PR gates
Given `.github/workflows/pr-automerge.yml`
When the file is read
Then it triggers on `pull_request`
And its three jobs call the reusable workflows at a commit SHA, not a branch

## AC-045-11-05 — This repository rolls out report-only first
Given `.github/workflows/ci-pr-auto-merge.yml` and the repository contents
When they are read
Then no committed file hardcodes `PR_AUTOMERGE_MODE=live`
And the workflow treats the unset variable as report-only

## AC-045-11-06 — Every scenario is traced
Given this spec's `20-acceptance/` files and the tests
When `scripts/check-scenario-traceability.sh --spec
045-pr-size-gate-and-auto-merge` runs
Then it exits 0
And every AC-045 heading has a matching test name
