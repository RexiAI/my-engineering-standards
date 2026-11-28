# AC-045-09: Human notification

## AC-045-09-01 — Armed notification mentions owners and states the gates
Given `scripts/pr-automerge-notify.sh` with `--outcome armed`,
`--size-tier auto`, `--review-verdict pass`, `--exclusions none`,
a CODEOWNERS file containing `* @alice @bob`, `--repo-owner carol`,
and `--head-sha abc123`
When the script runs
Then stdout mentions `@alice` and `@bob`
And stdout states `tier=auto` and `verdict=pass`
And stdout states the merge waits for `pr-size`, `review-verdict`, CI, and
`mutation` when the tier requires it
And the exit code is 0

## AC-045-09-02 — Would-merge notification names report-only mode
Given `--outcome would-merge`, `--size-tier auto`, `--review-verdict pass`
When the script runs
Then stdout states the PR would have auto-merged
And stdout names report-only mode
And stdout states `tier=auto` and `verdict=pass`

## AC-045-09-03 — Blocked-by-exclusion notification asks for a human
Given `--outcome blocked-exclusion`, `--exclusions gate_surface:.github/workflows/ci.yml`
When the script runs
Then stdout names `gate_surface` and `.github/workflows/ci.yml`
And stdout states a human must review and merge the PR

## AC-045-09-04 — No CODEOWNERS file falls back to the repository owner
Given `--codeowners-file none` and `--repo-owner carol`
When the script runs
Then stdout mentions `@carol`
And stdout mentions no other invented handle

## AC-045-09-05 — Every body carries the idempotency marker
Given any of the three outcomes and `--head-sha abc123`
When the script runs
Then the last line of stdout is
`<!-- pr-automerge: <outcome>:abc123 -->`

## AC-045-09-06 — The workflow suppresses duplicate notifications
Given `.github/workflows/ci-pr-auto-merge.yml`
When the notification step is read
Then it reads existing PR comments and skips posting when the same
`<!-- pr-automerge: <outcome>:<head-sha> -->` marker already exists
