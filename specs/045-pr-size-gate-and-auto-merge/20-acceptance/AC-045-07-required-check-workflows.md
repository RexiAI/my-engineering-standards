# AC-045-07: Required-check workflows

## AC-045-07-01 — Both workflows are callable reusables
Given `.github/workflows/ci-pr-size-gate.yml` and
`.github/workflows/ci-pr-review-verdict.yml`
When their `on:` blocks and inputs are read
Then both declare `workflow_call`
And the size workflow takes `pr-number`, `base-sha`, `head-sha`, `base-ref`
And the verdict workflow takes `pr-number` and `head-sha`

## AC-045-07-02 — The size job evaluates labels, timeline, and the diff
Given `.github/workflows/ci-pr-size-gate.yml`
When the `size` job is read
Then it reads label presence with `gh pr view --json labels`
And it reads the actor of the latest `size-override` labeled event from the
issue timeline
And it runs `scripts/pr-size-gate.sh` with `--label`, `--label-actor`,
`--repo-owner`, and `--codeowners`
And a script exit code of 1 fails the job

## AC-045-07-03 — The verdict job fails closed
Given `.github/workflows/ci-pr-review-verdict.yml`
When the `verdict` job is read
Then it fetches comments with `gh pr view --json comments`
And it runs `scripts/pr-review-verdict.sh` with the head SHA
And a non-zero parser exit fails the job

## AC-045-07-04 — Only the pinned standards revision is executed
Given both reusable workflows
When their checkout steps are read
Then each obtains scripts from the standards repository at the pinned
reusable-workflow revision
And neither checks out code from the PR head
And neither uses `pull_request_target`

## AC-045-07-05 — Permissions are read-only
Given both reusable workflows
When their `permissions:` blocks are read
Then they grant at most `contents: read`, `pull-requests: read`, and
`issues: read`
And no permission ends in `: write`
And no secret is required

## AC-045-07-06 — An authorized override turns a failure into a pass
Given a `labeled` event for a 900-line PR
And `size-override` was applied by `alice`
And `.github/CODEOWNERS` contains `* @alice`
When the size job runs
Then the job exits 0
And the job output contains `tier=override`
And the job output contains `automerge=false`

## AC-045-07-07 — The check workflows never write
Given both workflows
When their steps are read
Then neither runs `gh pr comment`, `gh pr merge`, `git push`, or a merge API
call
