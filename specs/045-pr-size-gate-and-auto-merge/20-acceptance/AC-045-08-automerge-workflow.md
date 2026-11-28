# AC-045-08: Auto-merge workflow, report-only default, live arming

## AC-045-08-01 — The auto-merge workflow is a callable reusable
Given `.github/workflows/ci-pr-auto-merge.yml`
When its `on:` block and jobs are read
Then it declares `workflow_call`
And it takes `pr-number`, `base-sha`, `head-sha`, `base-ref`
And it has an `automerge` job

## AC-045-08-02 — Size and verdict are re-verified before arming
Given `.github/workflows/ci-pr-auto-merge.yml`
When the `automerge` job is read
Then it runs `scripts/pr-size-gate.sh` and requires `tier=auto`
And it runs `scripts/pr-review-verdict.sh` and requires `verdict=pass`
And a non-auto tier or non-pass verdict stops the job before any merge command

## AC-045-08-03 — Mode is report unless the value is exactly live
Given `.github/workflows/ci-pr-auto-merge.yml`
When the mode source is read
Then the mode comes from `vars.PR_AUTOMERGE_MODE`
And the workflow treats unset, empty, `report`, and any value other than
`live` as report-only

## AC-045-08-04 — Live mode arms native auto-merge with squash
Given mode `live`, size tier `auto`, verdict `pass`, no excluded path
And `allow_auto_merge` is true
When the auto-merge job runs
Then it runs `gh pr merge --auto --squash`
And it does not run `gh pr merge --merge`, `--rebase`, or `--admin`
And it does not call a direct merge API endpoint

## AC-045-08-05 — Report mode never merges
Given `PR_AUTOMERGE_MODE` is unset
And size tier `auto`, verdict `pass`, no excluded path
When the auto-merge job runs
Then it posts the would-merge notification
And the merge step's `if:` condition is false
And no merge command executes

## AC-045-08-06 — Auto-merge must be enabled on the repository
Given the repository setting `allow_auto_merge` is false
When the auto-merge job runs
Then the job exits non-zero before any merge command
And no notification claims auto-merge is armed

## AC-045-08-07 — There is no per-repository allowlist
Given `.github/workflows/ci-pr-auto-merge.yml`
When the file is read
Then it contains no `github.repository ==`, no `github.repository_owner ==`,
and no literal repository slug used as a merge condition

## AC-045-08-08 — Permissions are split by job
Given `.github/workflows/ci-pr-auto-merge.yml`
When the `permissions:` blocks are read
Then the read-only jobs grant only read permissions
And only the arming job grants `contents: write` and `pull-requests: write`
And no job grants `actions: write` or `id-token: write`

## AC-045-08-09 — The caller wires three pinned jobs
Given `.github/workflows/pr-automerge.yml`
When the caller jobs are read
Then `pr-size` calls `ci-pr-size-gate.yml@<sha>`
And `review-verdict` calls `ci-pr-review-verdict.yml@<sha>`
And `pr-automerge` calls `ci-pr-auto-merge.yml@<sha>` and has
`needs: [pr-size, review-verdict]`
And all three use the same commit SHA, not a branch

## AC-045-08-10 — The decision comment is idempotent per head
Given an existing comment carrying
`<!-- pr-automerge: armed:abc123 -->`
When the auto-merge job evaluates head `abc123`
Then it does not post a second `armed` comment for that head

## AC-045-08-11 — PR head code is never executed
Given `.github/workflows/ci-pr-auto-merge.yml`
When its trigger and checkout steps are read
Then it does not use `pull_request_target`
And it does not check out or execute code from the PR head
